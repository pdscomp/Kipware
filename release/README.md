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

Both tarballs are gzip-compressed directly and are uploaded as GitHub Release assets. Do not zip them again.

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
5. The workflow creates a **draft** GitHub Release with both tarballs and a checksum file.
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

Use `workflow_dispatch` with `dry_run=true` to build and upload workflow artifacts without creating a GitHub Release.

## If changes are needed after a draft release

- If only release notes need edits: edit the draft release body.
- If assets are wrong: delete the draft release, fix the branch/feed, move or recreate the date tag as needed, and rerun the workflow.

## Manual install note

Manual install is supported using:

https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/installer/generic.sh

For nonstandard layouts, create `/kip` as a symlink or bind mount to a partition with adequate space before running `generic.sh`. Embedded targets often need `wget-ssl` and `ca-certificates` for HTTPS package updates.
