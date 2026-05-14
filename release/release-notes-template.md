# Kipware {{TAG}}

Kipware is an optimized port of Entware for armv7l 3D printers built around the Allwinner R528/T113 family, including Elegoo Centauri Carbon-class systems.

## Release assets

- `kipware-cc1-{{TAG}}.tar.gz` — Elegoo Centauri Carbon 1 image (`/user-resource/.kipware` with `/kip` symlink)
- `kipware-cc2-{{TAG}}.tar.gz` — Elegoo Centauri Carbon 2 image (`/opt/usr/.kipware` with `/kip` symlink)
- `kipware-install-images-{{TAG}}.sha256` — SHA256 checksums

## Manual install

Manual install is also supported using the generic installer:

https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4/installer/generic.sh

For nonstandard layouts, create `/kip` as a symlink or bind mount to the desired install location before running `generic.sh`.

## Notes

- Do **not** add `/kip/lib` to global `LD_LIBRARY_PATH` on firmware environments with their own glibc loader.
- HTTPS package operations on embedded targets often require `wget-ssl` and `ca-certificates`.
- Release tarballs are already gzip-compressed; do not zip them again.
