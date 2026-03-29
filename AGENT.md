# Kipware Agent Guide

Kipware is a custom [Entware](https://github.com/Entware/Entware) fork targeting
ARM Cortex-A7 hard-float (armv7hf) for 3-D printer mainboards (e.g. Mellow FLY).
It cross-compiles an opkg feed of `.ipk` packages (Python, Rust std, networking
tools, etc.) and publishes them via GitHub Pages.

---

## Repository layout

```
bake_armv7hf.sh          Main build entry point
configs/armv7hf-5.4.config  Kconfig for the target (edit to add/remove packages)
feeds.conf               Active feed sources (packages, rtndev, golang, rustlang)
local-patches/
  packages/              Feed-level patches applied via `patch -p1 -d feeds/packages`
  <feed>-<pkg>/          Per-package extra patches copied into feeds/<feed>/<pkg>/patches/
.github/workflows/
  build-armv7hf-5.4.yml  CI: full world build + IPK verification + GitHub Pages deploy
```

Output IPKs land in:
```
bin/targets/armv7-5.4/generic-glibc/packages/
```

---

## Bake script quick reference

```bash
./bake_armv7hf.sh              # feeds + config + toolchain + world (full build)
./bake_armv7hf.sh world        # same as above
./bake_armv7hf.sh toolchain    # toolchain only
./bake_armv7hf.sh feeds        # refresh feeds only
./bake_armv7hf.sh feeds-clean  # drop and re-clone all feeds, then refresh
./bake_armv7hf.sh <pkg>        # clean + rebuild one package (e.g. python3-setuptools)
./bake_armv7hf.sh clean        # wipe target build/staging dirs (keeps hostpkg)
```

Key environment variables:

| Variable | Effect |
|---|---|
| `BAKE_CLEAN_FEEDS=1` | Drop and re-clone all feeds before building |
| `BAKE_SKIP_FEEDS=1` | Skip all feed operations |
| `BAKE_FORCE_FEEDS_UPDATE=1` | Force `./scripts/feeds update -a` even if cached |
| `BAKE_KEEP_CONFIG=1` | Keep existing `.config` instead of re-copying from `configs/` |
| `CCACHE_DIR` | Path to ccache directory |

### Building a single package after a full world

Use the package's feed-relative name — the script resolves it:

```bash
./bake_armv7hf.sh python-setuptools   # feeds/packages/lang/python/python-setuptools
./bake_armv7hf.sh python3             # feeds/packages/lang/python/python3
./bake_armv7hf.sh rustc-dev           # feeds/rustlang/rustc-dev
```

Or pass the full `make` target directly:

```bash
make package/feeds/packages/python-setuptools/compile V=s
```

---

## Adding or removing packages

Edit `configs/armv7hf-5.4.config`. Use `=m` to build a package as a standalone IPK:

```
CONFIG_PACKAGE_python3-setuptools=m
```

After editing, re-run `make defconfig` (or let the bake script do it) to normalise
the config. To interactively explore available packages:

```bash
cp configs/armv7hf-5.4.config .config
make menuconfig
```

### Step-by-step: adding a new package to both branches

This is the verified workflow for adding a package (e.g. `python3-yaml`) to both
`main` and `kip`.

#### 1. Find the correct names

A feed Makefile has two separate names that are easy to confuse:

| Name | Where it appears | Example |
|---|---|---|
| `PKG_NAME` | Top of Makefile; used for the feed symlink path | `python-yaml` |
| `Package/<name>` | `define Package/...` block; used in Kconfig | `python3-yaml` |

Look up both with:

```bash
grep "PKG_NAME\|define Package/" feeds/packages/lang/python/python-yaml/Makefile
# PKG_NAME:=python-yaml
# define Package/python3-yaml
```

Or search the feed index:

```bash
./scripts/feeds search python3-yaml
# Package name shown there is the one used in CONFIG_PACKAGE_...
```

The **Kconfig name** (`python3-yaml`) goes in `configs/armv7hf-5.4.config`.
The **PKG_NAME** (`python-yaml`) is the argument to `./scripts/feeds install`
and to `./bake_armv7hf.sh <pkg>`.

#### 2. Add to `configs/armv7hf-5.4.config` on `main`

```bash
git checkout main
# Add the line (use Kconfig name):
echo 'CONFIG_PACKAGE_python3-yaml=m' >> configs/armv7hf-5.4.config
# Commit and push; CI will build and publish automatically
git add configs/armv7hf-5.4.config
git commit -m "feat: add python3-yaml to build config"
git push
```

Repeat for any additional packages in the same commit.

#### 3. Apply the same change to `kip`

The `kip` branch carries the `/kip` prefix changes on top of `main`. Apply the
identical config edit there:

```bash
git checkout kip
# Either cherry-pick the main commit, or apply the edit directly:
echo 'CONFIG_PACKAGE_python3-yaml=m' >> configs/armv7hf-5.4.config
git add configs/armv7hf-5.4.config
git commit -m "feat: add python3-yaml to build config"
git push
```

#### 4. Install the feed symlink locally (if building locally)

The bake script's `feeds` step calls `./scripts/feeds install -a -f`, but if you
already have feeds checked out and just added a new package you may need to
install the symlink manually:

```bash
# Use PKG_NAME here (not the Kconfig name)
./scripts/feeds install python-yaml python-charset-normalizer
```

If that produces no visible output but the symlink is still missing, confirm the
package was found in the index:

```bash
./scripts/feeds search python3-yaml   # shows PKG_NAME and Kconfig name
ls package/feeds/packages/python-yaml # symlink should exist after install
```

#### 5. Build and verify locally

Use the PKG_NAME with the bake script:

```bash
# Skip feed update (already done), keep config fresh:
BAKE_SKIP_FEEDS=1 BAKE_KEEP_CONFIG=1 ./bake_armv7hf.sh python-yaml
```

> **Note:** Even a single-package build runs `bootstrap_toolchain` first, which
> may rebuild host/target toolchain components. This can take 20–40 minutes on a
> cold cache. Subsequent runs are faster.

Verify the IPK was produced and installs to the correct prefix:

```bash
ls -lh bin/targets/armv7-5.4/generic-glibc/packages/python3-yaml_*.ipk
# Inspect install paths (should be ./kip/... on kip branch, ./opt/... on main):
tar -xOf bin/targets/armv7-5.4/generic-glibc/packages/python3-yaml_*.ipk ./data.tar.gz \
  | tar -tz | head -10
```

#### 6. CI build and publishing

Pushing to `main` or `kip` triggers the `Build armv7hf-5.4` workflow. On
success it:

1. Runs `Verify published package set` — checks a hardcoded list of required IPKs
   (see the *CI verification* section below to keep that list current)
2. Deploys IPKs to GitHub Pages under:
   `https://pdscomp.github.io/Kipware/<branch>/armv7hf-k5.4/`

Confirm the new package is live:

```bash
curl -s "https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/" \
  | grep python3-yaml
# <a href="python3-yaml_6.0.3-1_armv7-5.4.ipk">...
```

#### Summary checklist

- [ ] Locate `PKG_NAME` and `Package/<name>` in the feed Makefile
- [ ] Add `CONFIG_PACKAGE_<name>=m` to `configs/armv7hf-5.4.config`
- [ ] Commit and push to `main`
- [ ] Apply the identical config change to `kip` and push
- [ ] CI green on both branches (check with `gh run list --branch <branch>`)
- [ ] Package visible at the GH Pages URL

### Python packages and Python version

The feed currently ships **Python 3.13**. Several stdlib modules were removed
upstream and have no opkg equivalent:

| Old package | Status | Replacement |
|---|---|---|
| `python3-distutils` | Removed in Python 3.12 | `python3-setuptools` (declares `PROVIDES:=python3-distutils`) |
| `python3-cgi` | Removed in Python 3.13 | None in opkg; use `pip install cgi` on-device if needed |
| `python3-cgitb` | Removed in Python 3.13 | None in opkg |

---

## Local patches

### Feed-level patches for `packages` feed (`local-patches/packages/*.patch`)

Applied with `patch -p1 -d feeds/packages` during `apply_local_feed_fixes`.
Used for fixes that span multiple packages or touch feed-level build system files.

Patch numbers `0001`–`0009` are reserved for build-system fixes (LTO disablement,
compiler workarounds, etc.). Numbers `0010`+ are available for other customisations
(e.g. prefix changes on the `kip` branch).

Current patches:
- `0001-python3-arm-disable-lto-and-strict-extensions.patch` — disables LTO for python3 (GCC 8.4.0 segfaults on ARM with LTO)
- `0002-glib2-arm-disable-lto.patch` — same fix for glib2
- `0003-zstd-arm-disable-lto.patch` — same fix for zstd
- `0010-vim-kip-prefix.patch` — updates vim Makefile install paths from `/opt` → `/kip`
- `0011-python3-kip-prefix.patch` — updates python3 Makefile paths and configure flags from `/opt` → `/kip`

### Feed-level patches for other feeds (`local-patches/<feed>-feed/*.patch`)

Applied with `patch -p1 -d feeds/<feed>` during `apply_local_feed_fixes`.
Use this layout when you need to patch an entire feed tree (e.g. global prefix
changes, feed-wide build system adjustments) rather than a single package.

To add patches for a feed named `rtndev`, place them in
`local-patches/rtndev-feed/` — the `-feed` suffix distinguishes these directories
from per-package directories (`local-patches/<feed>-<pkg>/`).

Current patches:
- `local-patches/rtndev-feed/0001-kip-prefix.patch` — updates all `rtndev` feed package Makefiles from `/opt` → `/kip`

### Per-package extra patches (`local-patches/<feed>-<pkg>/*.patch`)

Copied into `feeds/<feed>/<pkg>/patches/` and applied by the standard OpenWrt
`Build/Prepare` patch mechanism. File names must sort **after** the last upstream
patch to avoid context-line failures.

Current patches:
- `local-patches/rustlang-rustc-dev/091-add-arm-openwrt-linux-gnueabihf.patch`
  — adds `arm-openwrt-linux-gnueabihf` (hard-float) target to rustc, all vendored
  cc crates, libc, openssl-src, and target-lexicon. Named `091-` to apply after
  upstream patches `020`–`090` that establish the `gnueabi` (soft-float) entries
  used as context lines.

> **Patch ordering is critical.** If new upstream patches are added to
> `feeds/rustlang/rustc-dev/patches/` with a number >= 091, rename the local
> patch to maintain correct ordering.

---

## Toolchain

- **Target:** `arm-openwrt-linux-gnueabihf` (hard-float, Cortex-A7 + NEON VFPv4)
- **GCC:** 8.4.0  |  **glibc:** 2.27
- **Known GCC 8.4.0 issue:** LTO (`-flto`) causes internal segfaults on ARM for
  at least python3, glib2, and zstd. All three have local patches disabling LTO.
  If a new package fails with `lto1: internal compiler error: Segmentation fault`,
  add a similar patch in `local-patches/packages/`.

---

## Rust / rustc-dev

Rustc-dev cross-compiles Rust's standard library for the ARM target. It is a
~2-hour build on first run.

**Host compile** (`rustc-dev/host-compile`): builds a full Rust toolchain in
`build_dir/hostpkg/rustc-dev-*/`. Cached in CI under
`${{ runner.os }}-armv7hf-5.4-rustc-dev-host-v1-*`.

**Target compile** (`rustc-dev/compile`): runs `x.py install library/std
--target arm-openwrt-linux-gnueabihf` (~28 min). Requires the
`091-add-arm-openwrt-linux-gnueabihf.patch` to be applied first.

The host stamp lives in a non-standard path:
```
staging_dir/target-arm_cortex-a7+neon-vfpv4_glibc-2.27_eabi/host/stamp/
```
`./bake_armv7hf.sh clean` removes `staging_dir/target-*` (including that stamp),
but keeps `build_dir/hostpkg/` so the incremental host rebuild takes ~88 min
instead of ~2 h.

---

## CI caches

| Cache key prefix | Contents | Invalidated by |
|---|---|---|
| `armv7hf-5.4-dl-` | `dl/` source tarballs | changes to `feeds.conf` |
| `armv7hf-5.4-ccache-` | `.ccache/` compiler cache | config, bake script, feeds changes |
| `armv7hf-5.4-feeds-` | `feeds/` checkouts | `feeds.conf` changes |
| `armv7hf-5.4-host-toolchain-v1-` | `build_dir/host`, `build_dir/toolchain-*`, `staging_dir/host`, `staging_dir/toolchain-*` | config, bake script, feeds changes |
| `armv7hf-5.4-rustc-dev-host-v1-` | `staging_dir/target-.../host/` | `feeds/rustlang/rustc-dev/Makefile` changes |

Bump the `v1` version suffix in the workflow when a cache must be force-purged
(e.g. after a toolchain version change).

---

## CI verification

The `Verify published package set` step asserts that these IPKs are present after
every build. Update this list when adding required packages to the config:

```
python3, libpython3, python3-cffi, python3-dbus-fast, python3-distro,
python3-greenlet, python3-jinja2, python3-markupsafe, python3-numpy,
python3-paho-mqtt, python3-pillow, python3-pip, python3-pkg-resources,
python3-pyserial, python3-setuptools, python3-tornado, python3-zeroconf,
entware-release, entware-upgrade
```

---

## Common troubleshooting

### Package not produced after adding it to config

1. Verify the package name exists in the feed:
   ```bash
   find feeds/ -name Makefile | xargs grep -l "define Package/<name>"
   ```
2. Check the package isn't obsolete/removed (especially for Python packages — see
   the table above).
3. Re-run `make defconfig` to normalise `.config` after editing.
4. Build it in isolation to see the full error:
   ```bash
   ./bake_armv7hf.sh <pkg>
   ```

### Patch hunk failures

If `apply_local_feed_fixes` reports rejected hunks, the upstream feed has changed.
Check what changed with:
```bash
git -C feeds/rustlang log --oneline -10
```
Then update the offending patch. For `091-add-arm-openwrt-linux-gnueabihf.patch`,
the context lines come from the soft-float `gnueabi` entries added by patches
`020`–`090`.

### make exit code hidden by tee

If using `make ... | tee log` in a shell script, `$?` captures tee's exit code
(always 0), not make's. Use `make ... > log 2>&1` or `set -o pipefail` instead.
The bake script uses `set -euo pipefail` and redirects separately.

### Feed symlinks empty after a clean

If `package/feeds/` contains empty symlinks, feeds were not installed:
```bash
./bake_armv7hf.sh feeds
```
or force a full re-clone:
```bash
./bake_armv7hf.sh feeds-clean
```

### Adding a new feed

1. Add the `src-git` line to `feeds.conf`.
2. Run `./bake_armv7hf.sh feeds` to clone and install it.
3. Add desired packages to `configs/armv7hf-5.4.config`.
4. Update the CI feed cache key if the feed introduces long-running host compiles.
