# Bake Pipeline Audit — armv7hf-5.4

## Purpose

This document records a detailed audit of the Kipware/Entware fork's build
pipeline (`bake_armv7hf.sh`, `.github/workflows/build-armv7hf-5.4.yml`, and
`scripts/stage-armv7hf-pages.sh`), cross-checked against the standard
OpenWRT/Entware build conventions.  Each finding is classified by severity and
includes a concrete recommendation.

---

## Background: Standard OpenWRT/Entware Build Flow

The canonical build sequence for an Entware target is:

```
./scripts/feeds update -a        # check out / refresh all enabled feed repos
./scripts/feeds install -a       # create package/feeds/<name>/* symlinks
cp configs/<target>.config .config
make defconfig                   # expand sparse config to full .config
make -j$(nproc)                  # world build → all =y / =m packages compiled
```

All built package artifacts land in a **single flat directory**:

```
bin/targets/<BOARD>/<SUBTARGET>/packages/*.ipk
```

This is confirmed by `rules.mk`:

```make
PACKAGE_DIR?=$(BIN_DIR)/packages   # BIN_DIR = bin/targets/<board>/<subtarget>
```

Feed packages (from `package/feeds/`) are compiled into this same directory;
there is **no separate `bin/packages/` tree in Entware** (that separation
exists in mainline OpenWRT firmware builds but is not applicable here).

---

## Findings

### F-01 — Rustlang feed causes world build to fail  [CRITICAL]

**File:** `feeds.conf`

`feeds.conf` includes:

```
src-git rustlang https://github.com/Entware/entware-rust.git
```

The `rustlang` feed installs `package/feeds/rustlang/rustc-dev`, which is
included in the world build dependency graph.  The `rustc-dev/compile` step
fails in CI, blowing up the entire world build.

None of the Python packages we explicitly select (`python3-pip`,
`python3-cffi`, `python3-dbus-fast`, etc.) depend on Rust.  The feed is an
optional heavy-weight dependency that we are not using.

**Impact:** Every world build fails silently.  All packages compiled after the
rust failure are missing from the output.

**Recommendation:**
Comment out `rustlang` in `feeds.conf` until a rust-based package is
explicitly needed:

```diff
-src-git rustlang https://github.com/Entware/entware-rust.git
+#src-git rustlang https://github.com/Entware/entware-rust.git
```

This is the single change that most likely restores a clean world build and
makes all the fallback machinery unnecessary.

---

### F-02 — Non-standard fallback explicit-build machinery  [HIGH]

**File:** `bake_armv7hf.sh`

`bake_armv7hf.sh` contains a large amount of fallback logic that runs when the
world build fails:

- `have_package_artifact()` — checks whether an `.ipk` already exists
- `selected_python_package_symbols()` — reads Python selections from `.config`
- `resolve_package_dir_for_symbol()` — maps a config symbol to a package dir
- `build_explicit_package_symbol()` / `build_explicit_feed_package()` — builds
  one package at a time, re-running `feeds install -f` each time
- `ensure_requested_extras()` — orchestrates the above per selected symbol
- `build_world()` makes a failed world build non-fatal and delegates to
  `ensure_requested_extras()`

This machinery was added as a workaround for the rust failure (F-01) but is
itself a deviation from standard OpenWRT/Entware practice.  It:

- Only covers Python packages; other package families are silently absent if
  the world build fails.
- Makes CI appear successful even though the build is partial.
- Adds ~150 lines of complexity that would be unnecessary with a healthy world
  build.

**Recommendation:**
Fix F-01 first.  Once the world build succeeds end-to-end, remove or greatly
simplify `ensure_requested_extras` and restore `build_world` to fail-fast on a
non-zero `make` exit.

---

### F-03 — Triple-redundant feed operations per bake run  [MEDIUM]

**File:** `bake_armv7hf.sh`, `main()`

A full bake run invokes `./scripts/feeds install -a -f` **three times**:

1. Inside `feeds_init` → `reinstall_feed_packages`
2. In `main()` immediately after `feeds_init`: `refresh_feed_indexes` +
   `reinstall_feed_packages`
3. Inside `ensure_config` → `reinstall_feed_packages`

Each invocation walks all feed packages and recreates `package/feeds/`
symlinks.  This is a slow, no-op operation when feeds haven't changed and adds
significant wall-clock time to every build.

**Recommendation:**
- Remove the redundant `refresh_feed_indexes` + `reinstall_feed_packages` call
  in `main()` after `feeds_init`.
- Remove `reinstall_feed_packages` from inside `ensure_config`; it is already
  done by `feeds_init`.
- Keep only a single `feeds install` call per logical stage (update vs. reuse).

---

### F-04 — In-place Python Makefile patching is fragile  [MEDIUM]

**File:** `bake_armv7hf.sh`, `apply_local_feed_fixes()`

`patch_python3_feed()` and `patch_glib2_feed()` modify vendor Makefiles
**in-place** using inline Python string replacement:

```python
source = path.read_text()
updated = source.replace(old, new, 1)
path.write_text(updated)
```

Problems:
- Not idempotent: if the feed text already contains the new string, replacement
  is skipped silently, but if the upstream feed updates its text differently,
  the replacement silently no-ops and the unpatched variant is compiled.
- Bypasses the standard OpenWRT patch mechanism (`patches/` directories).
- Patches are lost if `feeds update -a` is re-run (overwrites the feed
  checkout).

**Standard OpenWRT/Entware approach:**
Place patch files under `package/feeds/<feed>/<pkg>/patches/` (or equivalent
local overlay).  The build system applies `quilt`-style patches automatically
before compilation and they survive feed updates.

Alternatively, maintain a fork of the affected feed repository.

**Recommendation:**
Convert `patch_python3_feed` and `patch_glib2_feed` to proper `.patch` files
stored under version control, applied via the standard patch mechanism.

---

### F-05 — `feeds install -f` inside per-package builds  [MEDIUM]

**File:** `bake_armv7hf.sh`, `build_explicit_feed_package()`

`build_explicit_feed_package` calls `refresh_feed_indexes` and
`./scripts/feeds install -f <pkg>` **for every individual package** in the
explicit build loop.  This means a run that needs to rebuild 15 Python
packages will call `feeds install -f` 15 times, each rebuilding the full feed
index.

This is non-standard.  `feeds install` is designed to be called once (globally
`-a`), not once per package at build time.

**Recommendation:**
If explicit per-package builds are kept (see F-02), move the
`refresh_feed_indexes` + `feeds install -f` call to once before the loop, not
inside each iteration.

---

### F-06 — Two redundant package-resolution functions  [LOW]

**File:** `bake_armv7hf.sh`

The script contains two separate functions for mapping a package name/symbol to
its directory under `package/`:

- `resolve_package_dir_for_symbol(symbol)` — searches for a Makefile
  containing `define Package/<symbol>`
- `resolve_pkg_dir(pkg)` — searches for `*/<pkg>/Makefile` by path segment

These overlap in purpose and are maintained separately.

**Recommendation:**
Consolidate into a single function that accepts either a config symbol or a
package name.

---

### F-07 — `bin/packages/` check is dead code in Entware  [LOW]

**Files:** `bake_armv7hf.sh`, `scripts/stage-armv7hf-pages.sh`,
`.github/workflows/build-armv7hf-5.4.yml`

Multiple places check for or search in `bin/packages/armv7-5.4`:

```bash
search_roots=(bin/targets/armv7-5.4)
if [ -d bin/packages/armv7-5.4 ]; then
  search_roots+=(bin/packages/armv7-5.4)
fi
```

In Entware, `PACKAGE_DIR = $(BIN_DIR)/packages` (from `rules.mk`), so **all**
packages—including feed packages—land under
`bin/targets/<board>/<subtarget>/packages/`.  There is no `bin/packages/` tree
produced by an Entware world build.

The `bin/packages/` path is a mainline OpenWRT convention (used when building
full firmware images with a distinct "target packages" vs. "feed packages"
split) and does not apply here.

**Recommendation:**
Remove the `bin/packages/` branch from all three locations.  Use only
`bin/targets/armv7-5.4/generic-glibc/packages` as the single authoritative
package root.

---

### F-08 — `make` wrapped with `env -i` (environment stripping)  [LOW]

**File:** `bake_armv7hf.sh`, `m()` function

The `m()` wrapper runs `make` under `env -i`, stripping **all** environment
variables except `PATH`, `HOME`, `SHELL`, and `LANG`.  This can conflict with:

- `CCACHE_DIR` (explicitly set in the CI step but not passed through `m()`)
- `GITHUB_WORKSPACE`, `GITHUB_ACTIONS` and similar CI variables that some tools
  inspect
- Any host tooling that respects environment variables

Standard OpenWRT practice is to let the Makefile system manage its own
environment isolation (`include/toplevel.mk` already does this via
`export OPENWRT_BUILD`, etc.).

**Recommendation:**
At minimum, ensure `CCACHE_DIR` is passed through the `m()` wrapper.  Consider
removing `env -i` entirely and relying on the upstream Makefile environment
isolation.

---

### F-09 — Hardcoded toolchain paths in workflow cache keys  [LOW]

**File:** `.github/workflows/build-armv7hf-5.4.yml`

The cache paths for host/toolchain are hardcoded:

```yaml
build_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-8.4.0_glibc-2.27_eabi
staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-8.4.0_glibc-2.27_eabi
```

If the gcc or glibc version in the toolchain is ever updated, the cache restore
will find nothing (cache miss) but the path definitions will still silently
point to the old names.

**Recommendation:**
Derive the toolchain directory names dynamically from the config (e.g., via
`make -s val.TOOLCHAIN_DIR` or a sed pass on `.config`), or use a glob pattern
for the cache path.  Alternatively, add a comment referencing the config
version numbers so they are easy to bump together.

---

### F-10 — `Verify hard-float toolchain` step lacks `set -e`  [LOW]

**File:** `.github/workflows/build-armv7hf-5.4.yml`

The recently corrected bake and verify steps now use `bash -euo pipefail -lc`.
The `Verify hard-float toolchain` step still uses `bash -lc`:

```yaml
- name: Verify hard-float toolchain
  run: |
    sudo -H -u appuser env ... bash -lc '...'
```

A failure inside this step (e.g., `readelf` not finding the VFP tag) would
print an error but not fail the workflow step.

**Recommendation:**
Change to `bash -euo pipefail -lc` for consistency.

---

### F-11 — `golang` feed included but no Go packages selected  [INFORMATIONAL]

**File:** `feeds.conf`

`feeds.conf` includes:

```
src-git golang https://github.com/Entware/entware-go.git
```

Like the `rustlang` feed, this is a heavyweight feed that pulls in Go toolchain
host-build steps.  The current `configs/armv7hf-5.4.config` does not appear to
select any Go packages.

**Recommendation:**
Audit whether any required package depends on Go.  If not, comment out the
`golang` feed to reduce world build time and potential failure surface.

---

## Recommended Fix Order

| Priority | Finding | Action |
|----------|---------|--------|
| 1 | F-01 | Disable `rustlang` (and optionally `golang`) feed |
| 2 | F-02 | After F-01, verify world build succeeds; simplify/remove fallback machinery |
| 3 | F-03 | Remove redundant `feeds install` calls in `main()` and `ensure_config` |
| 4 | F-04 | Replace inline Makefile patches with proper `.patch` files |
| 5 | F-05 | Move `feeds install` out of per-package build loop |
| 6 | F-07 | Remove dead `bin/packages/` search roots |
| 7 | F-08 | Pass `CCACHE_DIR` through `m()`; consider removing `env -i` |
| 8 | F-09 | Derive toolchain cache paths dynamically |
| 9 | F-10 | Add `set -euo pipefail` to toolchain verify step |
| 10 | F-06 | Consolidate package resolution functions |
| 11 | F-11 | Audit Go feed dependency |

---

## Notes on Current State

- The local `bin/` tree has **231 IPKs** built from the most recent partial
  world build (which failed on `rustc-dev/compile` before completing).
- `python3-pip` and the more recently added Python packages
  (`python3-cffi`, `python3-dbus-fast`, `python3-greenlet`, etc.) are **not**
  in the local tree because they were scheduled after the rust failure.
- The fallback explicit-build machinery in `ensure_requested_extras()` is
  intended to cover these gaps but re-adds the feed cost per package (F-05)
  and would be unnecessary with a clean world build (F-01).
- Live run `23511936430` (`Enforce Python feed artifacts`) is currently
  in-progress and will confirm whether the fallback machinery produces the
  missing packages in CI.  Regardless of that outcome, F-01 remains the root
  cause to address.
