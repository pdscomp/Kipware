# Kipware {{TAG}}

Kipware is an optimized port of Entware for armv7l 3D printers built around the Allwinner R528/T113 family, including Elegoo Centauri Carbon-class systems.

## Release assets

- `kipware-cc1-{{TAG}}.tar.gz` — Elegoo Centauri Carbon 1 image (`/user-resource/.kipware` with `/kip` symlink)
- `kipware-cc2-{{TAG}}.tar.gz` — Elegoo Centauri Carbon 2 image (`/opt/usr/.kipware` with `/kip` symlink)
- `kipware-install-baremetal.sh` — base Kipware installer for compatible ARM targets that install directly to `/kip`
- `kipware-install-images-{{TAG}}.sha256` — SHA256 checksums for release install assets
- `release-notes-{{TAG}}.md` — full generated release notes, package deltas, and commit list when applicable

## Installing prebuilt CC1/CC2 tarballs

Copy the matching tarball to the target system's root directory, then extract it from `/`:

```sh
cd /
tar zxvf kipware-cc1-{{TAG}}.tar.gz
# or:
tar zxvf kipware-cc2-{{TAG}}.tar.gz
```

After extraction, add Kipware to login shells by sourcing its profile snippet from `/etc/profile`, `/root/.profile`, or another firmware-specific shell startup file:

```sh
. /kip/profile-kipware.sh
```

## Manual install

Manual install is supported using the release asset `kipware-install-baremetal.sh` or the live feed installer:

```sh
sh kipware-install-baremetal.sh
```

The same installer is available from the live feed:

https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/installer/generic.sh

For nonstandard layouts, create `/kip` as a symlink or bind mount to the desired install location before running the installer.

After installation, add Kipware to login shells by sourcing its profile snippet from `/etc/profile`, `/root/.profile`, or another firmware-specific shell startup file:

```sh
. /kip/profile-kipware.sh
```

## Notes

- Do **not** add `/kip/lib` to global `LD_LIBRARY_PATH` on firmware environments with their own glibc loader.
- HTTPS package operations on embedded targets often require `wget-ssl` and `ca-certificates`.
- Release tarballs are already gzip-compressed; do not zip them again.
