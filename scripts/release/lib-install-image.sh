#!/usr/bin/env bash
# Shared helpers for building Kipware release install images.

set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

validate_tag() {
  local tag="$1"
  [[ "${tag}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || fail "tag must match YYYY-MM-DD: ${tag}"
  [[ "$(date -d "${tag}" +%F)" == "${tag}" ]] || fail "tag is not a valid calendar date: ${tag}"
}

load_package_manifest() {
  local package_list="$1"
  [[ -f "${package_list}" ]] || fail "package manifest not found: ${package_list}"
  grep -Ev '^\s*(#|$)' "${package_list}"
}

preflight_packages_in_index() {
  local repo_base_url="$1"
  local package_list="$2"
  local index_file="${TMPDIR:-/tmp}/kipware-Packages.$$"
  local missing=0

  log "Downloading package index from ${repo_base_url}/Packages"
  curl -fsSL "${repo_base_url}/Packages" -o "${index_file}"

  while IFS= read -r pkg; do
    [[ -n "${pkg}" ]] || continue
    if ! grep -qx "Package: ${pkg}" "${index_file}"; then
      printf 'Missing package in feed: %s\n' "${pkg}" >&2
      missing=1
    fi
  done < <(load_package_manifest "${package_list}")

  rm -f "${index_file}"
  [[ "${missing}" -eq 0 ]] || fail "one or more requested packages are missing from the feed"
}

prepare_kip_symlink() {
  local kip_target="$1"
  [[ "${kip_target}" = /* ]] || fail "KIP_TARGET must be absolute: ${kip_target}"
  case "${kip_target}" in
    /opt/usr/.kipware|/user-resource/.kipware|/tmp/kipware-release-test/*) ;;
    *) fail "refusing unexpected KIP_TARGET: ${kip_target}" ;;
  esac

  log "Preparing /kip -> ${kip_target}"
  rm -f /kip
  rm -rf "${kip_target}"
  mkdir -p "${kip_target}"
  ln -sfn "${kip_target}" /kip
}

download_and_run_generic_installer() {
  local repo_base_url="$1"
  local installer=/root/generic.sh

  log "Downloading generic installer"
  curl -fsSL "${repo_base_url%/}/installer/generic.sh" -o "${installer}"
  chmod 0755 "${installer}"

  log "Running generic installer"
  "${installer}"
}

write_profile() {
  local profile_path="$1"
  log "Writing ${profile_path}"
  cat > "${profile_path}" <<'EOF'
# /kip/profile-kipware.sh
export PATH=/kip/bin:/kip/sbin:$PATH
EOF
  chmod 0644 "${profile_path}"
}

install_package_manifest() {
  local package_list="$1"
  local -a packages=()

  mapfile -t packages < <(load_package_manifest "${package_list}")
  [[ "${#packages[@]}" -gt 0 ]] || fail "package manifest is empty: ${package_list}"

  log "Updating opkg package index"
  /kip/bin/opkg update

  log "Installing ${#packages[@]} packages in one opkg transaction"
  /kip/bin/opkg install "${packages[@]}"
}

fix_permissions() {
  local -a roots=("$@")
  log "Normalizing permissions on ${roots[*]}"
  chmod -Rf a+rX "${roots[@]}"
}

create_tarball() {
  local output="$1"
  shift
  local -a roots=("$@")
  [[ "${#roots[@]}" -gt 0 ]] || fail "create_tarball requires at least one root"

  mkdir -p "$(dirname "${output}")"
  log "Creating ${output} from ${roots[*]}"
  (
    cd /
    tar --numeric-owner -zcvf "${output}" "${roots[@]#/}"
  )
}

verify_tarball() {
  local tarball="$1"
  local kip_target="$2"
  local verify_dir
  verify_dir="$(mktemp -d)"

  log "Verifying ${tarball}"
  tar -xzf "${tarball}" -C "${verify_dir}"

  [[ -L "${verify_dir}/kip" ]] || fail "tarball missing /kip symlink: ${tarball}"
  [[ "$(readlink "${verify_dir}/kip")" == "${kip_target}" ]] || \
    fail "tarball /kip symlink points to $(readlink "${verify_dir}/kip"), expected ${kip_target}"

  local relative_target="${kip_target#/}"
  [[ -x "${verify_dir}/${relative_target}/bin/opkg" ]] || \
    fail "tarball missing executable opkg at ${kip_target}/bin/opkg"
  [[ -f "${verify_dir}/${relative_target}/profile-kipware.sh" ]] || \
    fail "tarball missing profile-kipware.sh"

  rm -rf "${verify_dir}"
}
