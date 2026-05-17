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

repair_kip_alternatives() {
  log "Repairing /kip alternatives from installed package metadata"

  python3 - <<'PY'
from pathlib import Path
import os

info_dir = Path('/kip/lib/opkg/info')
if not info_dir.exists():
    raise SystemExit('missing opkg info directory: /kip/lib/opkg/info')

# link -> (priority, target, source control file)
selected: dict[str, tuple[int, str, str]] = {}

for control in sorted(info_dir.glob('*.control')):
    text = control.read_text(errors='replace').splitlines()
    current_key = None
    fields: dict[str, str] = {}
    for line in text:
        if not line:
            current_key = None
            continue
        if line[0].isspace() and current_key:
            fields[current_key] += ' ' + line.strip()
            continue
        if ':' not in line:
            current_key = None
            continue
        key, value = line.split(':', 1)
        current_key = key
        fields[key] = value.strip()

    alternatives = fields.get('Alternatives')
    if not alternatives:
        continue

    for raw_entry in alternatives.split(','):
        entry = raw_entry.strip()
        if not entry:
            continue
        parts = entry.split(':', 2)
        if len(parts) != 3:
            raise SystemExit(f'{control}: malformed Alternatives entry: {entry!r}')
        priority_s, link, target = parts
        try:
            priority = int(priority_s)
        except ValueError as exc:
            raise SystemExit(f'{control}: non-integer Alternatives priority in {entry!r}') from exc

        # Release images are /kip-based. Ignore stale /opt metadata here; those
        # packages need feed patches before they are safe for kip images.
        if not link.startswith('/kip/'):
            continue
        prev = selected.get(link)
        if prev is None or priority > prev[0]:
            selected[link] = (priority, target, control.name)

created = []
for link, (priority, target, source) in sorted(selected.items()):
    if not target.startswith('/kip/'):
        raise SystemExit(f'{source}: /kip alternative {link} points outside /kip: {target}')
    target_path = Path(target)
    if not target_path.exists():
        raise SystemExit(f'{source}: alternative target missing: {target}')
    link_path = Path(link)
    link_path.parent.mkdir(parents=True, exist_ok=True)
    if link_path.is_symlink() and os.readlink(link_path) == target:
        continue
    if link_path.exists() or link_path.is_symlink():
        link_path.unlink()
    link_path.symlink_to(target)
    created.append(f'{link} -> {target} ({source}, priority {priority})')

if created:
    print('Created/repaired alternatives:')
    for line in created:
        print(f'  {line}')
else:
    print('All /kip alternatives already correct')
PY
}

verify_installed_image_contents() {
  log "Verifying installed image contents before tarball creation"

  [[ -x /kip/bin/opkg ]] || fail "missing /kip/bin/opkg"

  if [[ -f /kip/lib/opkg/info/findutils.control ]]; then
    [[ -x /kip/libexec/find-gnu ]] || fail "findutils installed but missing /kip/libexec/find-gnu"
    [[ -x /kip/libexec/xargs-gnu ]] || fail "findutils installed but missing /kip/libexec/xargs-gnu"
    [[ -L /kip/bin/find ]] || fail "findutils installed but missing /kip/bin/find symlink"
    [[ "$(readlink /kip/bin/find)" == "/kip/libexec/find-gnu" ]] || \
      fail "/kip/bin/find points to $(readlink /kip/bin/find), expected /kip/libexec/find-gnu"
    [[ -L /kip/bin/xargs ]] || fail "findutils installed but missing /kip/bin/xargs symlink"
    [[ "$(readlink /kip/bin/xargs)" == "/kip/libexec/xargs-gnu" ]] || \
      fail "/kip/bin/xargs points to $(readlink /kip/bin/xargs), expected /kip/libexec/xargs-gnu"
  fi
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

  if [[ -f "${verify_dir}/${relative_target}/lib/opkg/info/findutils.control" ]]; then
    [[ -x "${verify_dir}/${relative_target}/libexec/find-gnu" ]] || \
      fail "tarball missing findutils payload at ${kip_target}/libexec/find-gnu"
    [[ -L "${verify_dir}/${relative_target}/bin/find" ]] || \
      fail "tarball missing ${kip_target}/bin/find symlink"
    [[ "$(readlink "${verify_dir}/${relative_target}/bin/find")" == "/kip/libexec/find-gnu" ]] || \
      fail "tarball ${kip_target}/bin/find points to $(readlink "${verify_dir}/${relative_target}/bin/find"), expected /kip/libexec/find-gnu"
    [[ -x "${verify_dir}/${relative_target}/libexec/xargs-gnu" ]] || \
      fail "tarball missing findutils payload at ${kip_target}/libexec/xargs-gnu"
    [[ -L "${verify_dir}/${relative_target}/bin/xargs" ]] || \
      fail "tarball missing ${kip_target}/bin/xargs symlink"
    [[ "$(readlink "${verify_dir}/${relative_target}/bin/xargs")" == "/kip/libexec/xargs-gnu" ]] || \
      fail "tarball ${kip_target}/bin/xargs points to $(readlink "${verify_dir}/${relative_target}/bin/xargs"), expected /kip/libexec/xargs-gnu"
  fi

  rm -rf "${verify_dir}"
}
