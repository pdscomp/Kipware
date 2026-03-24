# Python dependency findings for `timiv/oc-build-tools`

This note summarizes the comparison between the Python-related runtime pieces in
`https://github.com/timiv/oc-build-tools` and the Entware `armv7hf-5.4` package
set configured in this repository.

## What I compared

I used the following `oc-build-tools` inputs as the source of truth:

- `runtime/environment/requirements-kalico.txt`
- `runtime/environment/requirements-moonraker.txt`
- `runtime/environment/pkg/packages/kalico.mk`
- `runtime/environment/pkg/packages/moonraker.mk`
- `helper/wheeler/build.sh`
- the prebuilt wheel names under `runtime/python-wheels/`

Those files describe the Python packages `oc-build-tools` expects for Kalico /
Moonraker and related runtime support.

## Packages added to `armv7hf-5.4.config`

These package symbols are present in the current Entware tree and survive
`make defconfig`, so I enabled them as modules:

- `CONFIG_PACKAGE_python3-cffi=m`
- `CONFIG_PACKAGE_python3-dbus-fast=m`
- `CONFIG_PACKAGE_python3-distro=m`
- `CONFIG_PACKAGE_python3-greenlet=m`
- `CONFIG_PACKAGE_python3-jinja2=m`
- `CONFIG_PACKAGE_python3-markupsafe=m`
- `CONFIG_PACKAGE_python3-numpy=m`
- `CONFIG_PACKAGE_python3-paho-mqtt=m`
- `CONFIG_PACKAGE_python3-pillow=m`
- `CONFIG_PACKAGE_python3-pip=m`
- `CONFIG_PACKAGE_python3-pyserial=m`
- `CONFIG_PACKAGE_python3-tornado=m`
- `CONFIG_PACKAGE_python3-zeroconf=m`

`python3-pip` was added as a follow-up because the package exists in the current
Entware tree for this target and can be enabled cleanly.

## Dependency symbols also enabled

When I validated the above set with `make defconfig`, the following additional
dependency symbols were auto-enabled. I pinned them in the target config so the
selection is explicit and reproducible:

- `CONFIG_PACKAGE_libfreetype=m`
- `CONFIG_PACKAGE_libjpeg-turbo=m`
- `CONFIG_PACKAGE_libtiff=m`
- `CONFIG_PACKAGE_libwebp=m`
- `CONFIG_PACKAGE_python3-async-timeout=m`
- `CONFIG_PACKAGE_python3-ifaddr=m`
- `CONFIG_PACKAGE_python3-ply=m`
- `CONFIG_PACKAGE_python3-pycparser=m`

The base Python runtime dependencies were already enabled before this pass,
including:

- `libffi`
- `libgdbm`
- `liblzma`
- `libsqlite3`
- `libreadline`
- `libncursesw`
- `terminfo`
- `zlib`

## Packages requested by `oc-build-tools` but not installable via current config

I checked these against the current Entware tree and current target config
resolution. They are not available as installable `CONFIG_PACKAGE_*` targets in
this repository right now:

- `python3-can`
- `python3-streaming-form-data`
- `python3-inotify-simple`
- `python3-libnacl`
- `python3-preprocess-cancellation`
- `python3-apprise`
- `python3-ldap3`
- `python3-periphery`
- `python3-importlib-metadata`

Some of these may exist upstream only as pip/wheel dependencies rather than
Entware packages, which matches the `oc-build-tools` approach of building and
shipping wheels for them.

## Validation performed

- Compared `oc-build-tools` Python requirements/wheels to Entware package names.
- Probed candidate package symbols against `make defconfig`.
- Confirmed the added package symbols survive config resolution.
- Confirmed the dependency symbols above are required and now explicitly enabled.
