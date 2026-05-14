# Kipware release install images

This directory contains the source-controlled configuration for date-tagged Kipware install image releases.

## What the workflow builds

The release workflow builds preinstalled Kipware tarballs from the published `kip` feed:

- `kipware-cc1-YYYY-MM-DD.tar.gz`
  - Target: Elegoo Centauri Carbon 1
  - Install tree: `/user-resource/.kipware`
  - Symlink: `/kip -> /user-resource/.kipware`
- `kipware-cc2-YYYY-MM-DD.tar.gz`
  - Target: Elegoo Centauri Carbon 2
  - Install tree: `/opt/usr/.kipware`
  - Symlink: `/kip -> /opt/usr/.kipware`

Both tarballs are gzip-compressed directly and are uploaded as raw GitHub Release assets. The release also publishes `kipware-install-baremetal.sh`, a copy of the live `kip` feed installer for compatible ARM systems that should install directly to `/kip`. Do not zip release assets again. GitHub Actions may show internal workflow artifacts as `.zip` downloads during dry runs; those are CI handoff/debug artifacts only, not target-system deliverables.

## Directory layout

```text
release/
├── README.md
├── kipware-install-packages.txt      # shared package manifest
├── release-notes-template.md         # boilerplate notes/context
└── targets/
    ├── cc1.env                       # CC1 install target config
    └── cc2.env                       # CC2 install target config
```

Scripts live under:

```text
scripts/release/
├── lib-install-image.sh              # shared shell helpers
├── build-target-image.sh             # generic target builder
├── build-cc1-image.sh                # optional local wrapper
├── build-cc2-image.sh                # optional local wrapper
└── generate-release-notes.py
```

## Shared package set

`kipware-install-packages.txt` is one package per line. Blank lines and comments are ignored. All release image targets use the same package set unless a future target explicitly needs an override mechanism.

Before installing, the build script checks every package name against the published `Packages` index so failures happen early and clearly.

## Target configs

Each target has a small `.env` file with only target-specific values:

```bash
TARGET_ID=cc1
TARGET_DISPLAY_NAME="Elegoo Centauri Carbon 1"
KIP_TARGET=/user-resource/.kipware
TAR_ROOTS="/user-resource /kip"
FREE_SPACE_NOTE="CC1 installs Kipware under /user-resource/.kipware."
```

To add another target later:

1. Add `release/targets/<target>.env`.
2. Add `<target>` to the workflow matrix in `.github/workflows/release-install-images.yml`.
3. Confirm the target's install location has adequate free space.
4. Run a dry-run workflow and inspect the tarball structure.

## Installing prebuilt CC1/CC2 tarballs

Copy the matching tarball to the target system's root directory, then extract it from `/`:

```sh
cd /
tar zxvf kipware-cc1-YYYY-MM-DD.tar.gz
# or:
tar zxvf kipware-cc2-YYYY-MM-DD.tar.gz
```

Then add Kipware to login shells by sourcing its profile snippet from `/etc/profile`, `/root/.profile`, or another firmware-specific shell startup file:

```sh
. /kip/profile-kipware.sh
```

You can also source it immediately in the current shell:

```sh
. /kip/profile-kipware.sh
```

## Release process

1. Ensure the `kip` branch build is green and the published feed is current:
   ```bash
   gh run list --branch kip --event push --limit 1 --json status,conclusion,headSha,databaseId
   curl -fsSL https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/Packages | grep '^Package: opkg$'
   ```
2. Pick a date tag:
   ```bash
   tag=$(date +%F)
   ```
3. Preview notes locally:
   ```bash
   python3 scripts/release/generate-release-notes.py \
     --tag "$tag" \
     --package-list release/kipware-install-packages.txt \
     --target-dir release/targets \
     --output /tmp/kipware-release-notes.md
   ```
4. Create and push an annotated tag on the exact `kip` commit being released:
   ```bash
   git checkout kip
   git pull --ff-only
   git tag -a "$tag" -m "Kipware $tag"
   git push origin "$tag"
   ```
5. The workflow creates a **draft** GitHub Release with both tarballs, the bare-metal installer script, a checksum file, and full generated notes named `release-notes-${tag}.md`. The release body itself is a compact summary; the attached notes carry the complete package deltas and commit list when applicable.
6. Verify assets:
   ```bash
   gh release download "$tag" --dir /tmp/kipware-release-${tag}
   cd /tmp/kipware-release-${tag}
   sha256sum -c kipware-install-images-${tag}.sha256
   ```
7. Publish only after human approval:
   ```bash
   gh release edit "$tag" --draft=false
   ```

## Dry-run workflow

Use `workflow_dispatch` with `dry_run=true` to build and validate the images without creating a GitHub Release. The downloadable workflow artifacts shown by GitHub Actions are always `.zip` wrappers; this is unavoidable for Actions artifacts and should be treated as CI/debug output only.

To verify the actual user-facing release download shape, run `workflow_dispatch` with `dry_run=false` or push a date tag. The draft GitHub Release will contain direct raw assets:

- `kipware-cc1-YYYY-MM-DD.tar.gz`
- `kipware-cc2-YYYY-MM-DD.tar.gz`
- `kipware-install-baremetal.sh`
- `kipware-install-images-YYYY-MM-DD.sha256`
- `release-notes-YYYY-MM-DD.md`

## If changes are needed after a draft release

- If only release notes need edits: edit the draft release body.
- If assets are wrong: delete the draft release, fix the branch/feed, move or recreate the date tag as needed, and rerun the workflow.

## Manual install note

Manual install is supported using the release asset `kipware-install-baremetal.sh` or the live feed installer:

https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/installer/generic.sh

For nonstandard layouts, create `/kip` as a symlink or bind mount to a partition with adequate space before running the installer. Embedded targets often need `wget-ssl` and `ca-certificates` for HTTPS package updates.

After installation, add Kipware to login shells by sourcing its profile snippet from `/etc/profile`, `/root/.profile`, or another firmware-specific shell startup file:

```sh
. /kip/profile-kipware.sh
```
