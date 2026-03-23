#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONFIG="configs/armv7hf-5.4.config"
TARGET_BOARD="armv7-5.4"
TARGET_SUBTARGET="generic-glibc"
TARGET_CPU="arm_cortex-a7+neon-vfpv4"
TARGET_PACKAGES_DIR="bin/targets/${TARGET_BOARD}/${TARGET_SUBTARGET}/packages"

cd "$REPO_ROOT"

usage() {
  cat <<EOF
Usage:
  ./${SCRIPT_NAME}                  Build armv7hf-5.4 end to end
  ./${SCRIPT_NAME} all              Same as default
  ./${SCRIPT_NAME} feeds            Update/install enabled feeds only
  ./${SCRIPT_NAME} feeds-clean      Drop feed cache, then update/install enabled feeds
  ./${SCRIPT_NAME} toolchain        Build toolchain/install and package/libs/toolchain
  ./${SCRIPT_NAME} core             Build validated core steps through opkg and zlib
  ./${SCRIPT_NAME} world            Build the full package set selected by feeds.conf
  ./${SCRIPT_NAME} <pkg>            Clean+build one package after toolchain bootstrap
  ./${SCRIPT_NAME} clean            Remove armv7hf-5.4 output/build artifacts

Notes:
  - Forces ${TARGET_CONFIG} unless BAKE_KEEP_CONFIG=1 is set.
  - Reuses feed checkouts by default.
  - Set BAKE_CLEAN_FEEDS=1 or use feeds-clean to drop cached feed checkouts first.
  - Set BAKE_SKIP_FEEDS=1 to reuse cached feeds without update.
  - Set BAKE_FORCE_FEEDS_UPDATE=1 to force ./scripts/feeds update -a.
  - Uses the validated build order: toolchain -> package/libs/toolchain -> opkg/zlib -> world.
EOF
}

m() {
  env -i \
    PATH="$PATH" \
    HOME="${HOME:-$REPO_ROOT}" \
    SHELL=/bin/bash \
    LANG=C \
    make "$@"
}

jobs() {
  local nproc
  nproc="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  printf '%s\n' "${nproc:-1}"
}

log_step() {
  printf '\n==> %s\n' "$1"
}

clean_outputs() {
  shopt -s nullglob
  local paths=(
    "bin/targets/${TARGET_BOARD}"
    build_dir/target-"${TARGET_CPU}"_*
    build_dir/toolchain-"${TARGET_CPU}"_*
    staging_dir/target-"${TARGET_CPU}"_*
    staging_dir/toolchain-"${TARGET_CPU}"_*
  )
  rm -rf "${paths[@]}"
  shopt -u nullglob
  echo "Clean complete."
}

clean_feed_cache() {
  log_step "feeds clean cache"
  rm -rf feeds package/feeds
}

ensure_config() {
  if [[ "${BAKE_KEEP_CONFIG:-}" != "1" ]]; then
    cp "${TARGET_CONFIG}" .config
  fi
  log_step "make defconfig"
  m defconfig
}

feeds_prune_disabled() {
  local enabled
  enabled="$(./scripts/feeds list -n 2>/dev/null || true)"
  [[ -n "$enabled" ]] || return 0

  local keep
  keep=" $(printf '%s\n' "$enabled" | tr '\n' ' ') "

  local d name
  for d in feeds/* package/feeds/*; do
    [[ -d "$d" ]] || continue
    name="${d##*/}"
    if [[ "$keep" != *" $name "* ]]; then
      rm -rf "feeds/$name" "package/feeds/$name"
    fi
  done
}

refresh_feed_indexes() {
  log_step "feeds refresh indexes"
  ./scripts/feeds update -i -a
}

feeds_init() {
  if [[ "${BAKE_CLEAN_FEEDS:-}" == "1" ]]; then
    clean_feed_cache
  fi

  local have_cache=0
  if [[ -d feeds ]] && find feeds -mindepth 1 -maxdepth 1 -type d -print -quit >/dev/null 2>&1; then
    have_cache=1
  fi

  if [[ "${BAKE_SKIP_FEEDS:-}" == "1" ]]; then
    if [[ "$have_cache" == "0" ]]; then
      echo "ERROR: feeds cache not present; rerun without BAKE_SKIP_FEEDS=1 or set BAKE_FORCE_FEEDS_UPDATE=1" >&2
      return 1
    fi
    log_step "feeds install from cache"
    feeds_prune_disabled
    refresh_feed_indexes
    ./scripts/feeds install -a
    return 0
  fi

  if [[ "${BAKE_FORCE_FEEDS_UPDATE:-}" == "1" || "$have_cache" == "0" ]]; then
    log_step "feeds update"
    ./scripts/feeds update -a
  else
    log_step "feeds reuse cached checkout"
    refresh_feed_indexes
  fi

  feeds_prune_disabled
  log_step "feeds install"
  ./scripts/feeds install -a
}

patch_python3_feed() {
  python3 <<'PY'
from pathlib import Path

targets = {
    Path("feeds/packages/lang/python/python3/Makefile"): [
        (
            "--enable-optimizations \\",
            "$(if $(findstring arm,$(CONFIG_ARCH)),,--enable-optimizations) \\",
        ),
        (
            "MAKE_VARS += \\\n\tPYTHONSTRICTEXTENSIONBUILD=1",
            "MAKE_VARS += \\\n\t$(if $(findstring arm,$(CONFIG_ARCH)),,PYTHONSTRICTEXTENSIONBUILD=1)",
        ),
        (
            "$(if $(findstring mips,$(CONFIG_ARCH)),,--with-lto)",
            "$(if $(or $(findstring mips,$(CONFIG_ARCH)),$(findstring arm,$(CONFIG_ARCH))),,--with-lto)",
        ),
        (
            "$(if $(filter mips arm,$(CONFIG_ARCH)),,--with-lto)",
            "$(if $(or $(findstring mips,$(CONFIG_ARCH)),$(findstring arm,$(CONFIG_ARCH))),,--with-lto)",
        ),
    ],
}

for path, replacements in targets.items():
    if not path.exists():
        continue

    source = path.read_text()
    updated = source
    for old, new in replacements:
        if old in updated and new not in updated:
            updated = updated.replace(old, new, 1)

    if updated != source:
        path.write_text(updated)
PY
}

patch_glib2_feed() {
  python3 <<'PY'
from pathlib import Path

path = Path("feeds/packages/libs/glib2/Makefile")
if not path.exists():
    raise SystemExit(0)

source = path.read_text()
updated = source.replace(
    "MESON_ARGS += $(COMP_ARGS) -Dxattr=true -Db_lto=true -Dnls=$(if $(CONFIG_BUILD_NLS),en,dis)abled",
    "MESON_ARGS += $(COMP_ARGS) -Dxattr=true -Db_lto=$(if $(findstring arm,$(CONFIG_ARCH)),false,true) -Dnls=$(if $(CONFIG_BUILD_NLS),en,dis)abled",
    1,
)
if updated != source:
    path.write_text(updated)
PY
}

apply_local_feed_fixes() {
  patch_python3_feed
  patch_glib2_feed
}

target_requests_python3() {
  grep -Eq '^CONFIG_PACKAGE_python3=(y|m)$' "${TARGET_CONFIG}"
}

have_python3_artifacts() {
  compgen -G "${TARGET_PACKAGES_DIR}/python3_*.ipk" >/dev/null && \
    compgen -G "${TARGET_PACKAGES_DIR}/libpython3_*.ipk" >/dev/null
}

have_entware_bootstrap_artifacts() {
  compgen -G "${TARGET_PACKAGES_DIR}/entware-release*.ipk" >/dev/null && \
    compgen -G "${TARGET_PACKAGES_DIR}/entware-upgrade*.ipk" >/dev/null
}

build_explicit_feed_package() {
  local nproc="$1"
  local pkg="$2"
  shift 2
  local -a make_args=("$@")
  local pkgdir="package/feeds/packages/${pkg}"

  log_step "feeds install ${pkg}"
  ./scripts/feeds install -f "${pkg}"
  if [[ ! -f "${pkgdir}/Makefile" ]]; then
    echo "ERROR: feed package '${pkg}' was not installed to ${pkgdir}" >&2
    return 1
  fi

  m "${pkgdir}/clean" V=s "${make_args[@]}"
  m "${pkgdir}/compile" -j"${nproc}" V=s "${make_args[@]}"
}

build_explicit_python3() {
  local nproc="$1"
  (
    local config_backup
    config_backup="$(mktemp)"
    cp .config "${config_backup}"
    cp "${TARGET_CONFIG}" .config
    trap 'cp "${config_backup}" .config; rm -f "${config_backup}"; m defconfig >/dev/null' EXIT
    m defconfig >/dev/null
    build_explicit_feed_package "${nproc}" python3
  )
}

build_explicit_entware_bootstrap() {
  local nproc="$1"
  local -a make_args=(
    CONFIG_PACKAGE_entware-release=y
    CONFIG_PACKAGE_entware-upgrade=y
  )

  build_explicit_feed_package "${nproc}" entware-release "${make_args[@]}"
  build_explicit_feed_package "${nproc}" entware-upgrade "${make_args[@]}"
}

ensure_requested_extras() {
  local nproc="$1"

  if target_requests_python3 && ! have_python3_artifacts; then
    log_step "explicit python3 build"
    build_explicit_python3 "${nproc}"
  fi

  if ! have_entware_bootstrap_artifacts; then
    log_step "explicit entware bootstrap build"
    build_explicit_entware_bootstrap "${nproc}"
  fi
}

resolve_pkg_dir() {
  local pkg="$1"

  if [[ "$pkg" == */* ]]; then
    if [[ -d "$pkg" && -f "$pkg/Makefile" ]]; then
      printf '%s\n' "$pkg"
      return 0
    fi
    if [[ -d "package/$pkg" && -f "package/$pkg/Makefile" ]]; then
      printf '%s\n' "package/$pkg"
      return 0
    fi
  fi

  local matches=()
  while IFS= read -r mpath; do
    matches+=("${mpath%/Makefile}")
  done < <(find -L package -maxdepth 4 -path "*/${pkg}/Makefile" -print 2>/dev/null || true)

  if (( ${#matches[@]} == 0 )); then
    echo "ERROR: Could not find package '${pkg}' under ./package or package/feeds" >&2
    return 1
  fi

  if (( ${#matches[@]} > 1 )); then
    echo "ERROR: Package name '${pkg}' is ambiguous; matches:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    echo "Pass the full package dir, e.g. ./${SCRIPT_NAME} package/libs/${pkg}" >&2
    return 1
  fi

  printf '%s\n' "${matches[0]}"
}

run_make_step() {
  local label="$1"
  shift
  log_step "$label"
  m "$@"
}

bootstrap_toolchain() {
  local nproc="$1"
  run_make_step "toolchain/install" toolchain/install -j"$nproc" V=s
  run_make_step "package/libs/toolchain/compile" package/libs/toolchain/compile V=s
}

build_core() {
  local nproc="$1"
  bootstrap_toolchain "$nproc"
  run_make_step "package/system/opkg/compile" package/system/opkg/compile -j"$nproc" V=s
  run_make_step "package/libs/zlib/compile" package/libs/zlib/compile -j"$nproc" V=s
}

build_world() {
  local nproc="$1"
  build_core "$nproc"
  run_make_step "full world build" -j"$nproc" V=s
  ensure_requested_extras "$nproc"
}

build_package() {
  local nproc="$1"
  local pkg="$2"
  local pkgdir
  pkgdir="$(resolve_pkg_dir "$pkg")"

  bootstrap_toolchain "$nproc"
  run_make_step "${pkgdir}/clean" "${pkgdir}/clean" V=s
  run_make_step "${pkgdir}/compile" "${pkgdir}/compile" -j"$nproc" V=s
}

main() {
  local cmd="${1:-all}"
  local nproc
  nproc="$(jobs)"

  case "$cmd" in
    -h|--help)
      usage
      return 0
      ;;
    clean)
      clean_outputs
      return 0
      ;;
  esac

  if [[ "$cmd" == "feeds-clean" ]]; then
    BAKE_CLEAN_FEEDS=1
    cmd="feeds"
  fi

  feeds_init
  apply_local_feed_fixes
  ensure_config

  case "$cmd" in
    all)
      build_world "$nproc"
      ;;
    feeds)
      ;;
    toolchain)
      bootstrap_toolchain "$nproc"
      ;;
    core)
      build_core "$nproc"
      ;;
    world)
      build_world "$nproc"
      ;;
    *)
      build_package "$nproc" "$cmd"
      ;;
  esac

  echo
  echo "Artifacts: ${TARGET_PACKAGES_DIR}/"
}

main "$@"
