#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONFIG="configs/armv7hf-5.4.config"
TARGET_BOARD="armv7-5.4"
TARGET_CPU="arm_cortex-a7+neon-vfpv4"
# CONFIG_TARGET_SUBTARGET="generic"; rules.mk appends -$(LIBC) for non-musl builds.
TARGET_PACKAGES_DIR="bin/targets/${TARGET_BOARD}/generic-glibc/packages"

cd "$REPO_ROOT"

usage() {
  cat <<EOF
Usage:
  ./${SCRIPT_NAME}                  Build armv7hf-5.4 end to end
  ./${SCRIPT_NAME} feeds            Update/install feeds only
  ./${SCRIPT_NAME} feeds-clean      Re-clone all feeds, then update/install
  ./${SCRIPT_NAME} toolchain        Build toolchain only
  ./${SCRIPT_NAME} world            Build the full package set
  ./${SCRIPT_NAME} <pkg>            Clean+build one package (after toolchain)
  ./${SCRIPT_NAME} clean            Remove armv7hf-5.4 build artifacts

Environment:
  BAKE_CLEAN_FEEDS=1        Drop and re-clone all feeds (same as feeds-clean)
  BAKE_SKIP_FEEDS=1         Skip all feed operations
  BAKE_FORCE_FEEDS_UPDATE=1 Force ./scripts/feeds update -a even when cached
  BAKE_KEEP_CONFIG=1        Keep existing .config instead of copying ${TARGET_CONFIG}
  CCACHE_DIR                Path to ccache directory
EOF
}

m() {
  env -i \
    PATH="$PATH" \
    HOME="${HOME:-$REPO_ROOT}" \
    SHELL=/bin/bash \
    LANG=C \
    ${CCACHE_DIR:+CCACHE_DIR="${CCACHE_DIR}"} \
    make "$@"
}

log_step() { printf '\n==> %s\n' "$1"; }

nproc_count() { getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1; }

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

feeds_init() {
  if [[ "${BAKE_CLEAN_FEEDS:-}" == "1" ]]; then
    log_step "feeds clean"
    rm -rf feeds package/feeds
  fi

  [[ "${BAKE_SKIP_FEEDS:-}" == "1" ]] && return 0

  # Use index-only refresh when all enabled feeds are already checked out;
  # fall back to a full network update if any feed directory is missing.
  local -a update_args=("-a")
  if [[ "${BAKE_FORCE_FEEDS_UPDATE:-}" != "1" ]]; then
    local all_present=1
    while IFS= read -r name; do
      [[ -n "$name" && ! -d "feeds/$name" ]] && { all_present=0; break; }
    done < <(./scripts/feeds list -n 2>/dev/null || true)
    [[ "$all_present" == "1" ]] && update_args=("-i" "-a")
  fi

  log_step "feeds update ${update_args[*]}"
  ./scripts/feeds update "${update_args[@]}"

  log_step "feeds install"
  ./scripts/feeds install -a -f
}

apply_local_feed_fixes() {
  # Apply direct feed-level patches (local-patches/packages/*.patch → patch feeds/packages/)
  local feed_patches_dir="${REPO_ROOT}/local-patches/packages"
  if [[ -d "${feed_patches_dir}" ]]; then
    local patch_file
    while IFS= read -r patch_file; do
      log_step "apply patch $(basename "${patch_file}")"
      patch -N -p1 -d "${REPO_ROOT}/feeds/packages" < "${patch_file}" || true
    done < <(find "${feed_patches_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
  fi

  # Inject extra patches into pkg patch directories (local-patches/<feed>-<pkg>/*.patch → feeds/<feed>/<pkg>/patches/)
  local extra_dir
  for extra_dir in "${REPO_ROOT}/local-patches"/*/; do
    local dir_name
    dir_name="${extra_dir%/}"
    dir_name="${dir_name##*/}"
    [[ "$dir_name" == "packages" ]] && continue
    [[ "$dir_name" == *-* ]] || continue

    local feed="${dir_name%%-*}"
    local pkg="${dir_name#*-}"
    local dest="${REPO_ROOT}/feeds/${feed}/${pkg}/patches"
    [[ -d "$dest" ]] || { echo "WARNING: ${dest} not found, skipping ${dir_name}"; continue; }

    local patch_file
    while IFS= read -r patch_file; do
      local bname
      bname="$(basename "${patch_file}")"
      log_step "inject patch ${dir_name}/${bname} → ${feed}/${pkg}/patches/"
      cp "${patch_file}" "${dest}/${bname}"
    done < <(find "${extra_dir}" -maxdepth 1 -type f -name '*.patch' | sort)
  done
}

ensure_config() {
  [[ "${BAKE_KEEP_CONFIG:-}" != "1" ]] && cp "${TARGET_CONFIG}" .config
  log_step "make defconfig"
  m defconfig
}

resolve_pkg_dir() {
  local pkg="$1"

  if [[ "$pkg" == */* ]]; then
    [[ -d "$pkg"          && -f "$pkg/Makefile"          ]] && { printf '%s\n' "$pkg";          return; }
    [[ -d "package/$pkg" && -f "package/$pkg/Makefile"  ]] && { printf '%s\n' "package/$pkg"; return; }
  fi

  local matches=()
  while IFS= read -r mpath; do
    matches+=("${mpath%/Makefile}")
  done < <(find -L package -maxdepth 4 -path "*/${pkg}/Makefile" -print 2>/dev/null || true)

  case "${#matches[@]}" in
    0) echo "ERROR: package '${pkg}' not found under ./package" >&2; return 1 ;;
    1) printf '%s\n' "${matches[0]}" ;;
    *) echo "ERROR: '${pkg}' is ambiguous; matches:" >&2
       printf '  %s\n' "${matches[@]}" >&2
       echo "Use the full path, e.g. ./${SCRIPT_NAME} package/feeds/packages/lang/python/python3" >&2
       return 1 ;;
  esac
}

bootstrap_toolchain() {
  local nproc="$1"
  log_step "toolchain/install"
  m toolchain/install -j"$nproc" V=s
  log_step "package/libs/toolchain/compile"
  m package/libs/toolchain/compile V=s
}

build_world() {
  local nproc="$1"
  bootstrap_toolchain "$nproc"
  log_step "world"
  m -j"$nproc" world V=s
}

build_package() {
  local nproc="$1" pkg="$2" pkgdir
  pkgdir="$(resolve_pkg_dir "$pkg")"
  bootstrap_toolchain "$nproc"
  log_step "${pkgdir}/clean"
  m "${pkgdir}/clean" V=s
  log_step "${pkgdir}/compile"
  m "${pkgdir}/compile" -j"$nproc" V=s
}

main() {
  local cmd="${1:-all}"
  local nproc
  nproc="$(nproc_count)"

  case "$cmd" in
    -h|--help) usage; return 0 ;;
    clean)     clean_outputs; return 0 ;;
    feeds-clean) BAKE_CLEAN_FEEDS=1; cmd="feeds" ;;
  esac

  feeds_init
  apply_local_feed_fixes
  ensure_config

  case "$cmd" in
    all|world) build_world "$nproc" ;;
    feeds)     ;;
    toolchain) bootstrap_toolchain "$nproc" ;;
    *)         build_package "$nproc" "$cmd" ;;
  esac

  echo
  echo "Artifacts: ${TARGET_PACKAGES_DIR}/"
}

main "$@"
