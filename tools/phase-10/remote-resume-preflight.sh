#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'phase10-resume-preflight: %s\n' "$*" >&2
  exit 1
}

if (( $# != 11 )); then
  fail "internal argument contract mismatch"
fi

expected_disk="$1"
expected_disk_size="$2"
expected_boot_partition="$3"
expected_root_partition="$4"
expected_ipv4_address="$5"
expected_ipv4_gateway="$6"
expected_ipv6_address="$7"
expected_ipv6_gateway="$8"
expected_dns_csv="$9"
expected_arch="${10}"
expected_nic_driver="${11}"

if (( EUID != 0 )); then
  fail "the installer resume preflight must run as root"
fi

if [[ ! -r /etc/os-release ]]; then
  fail "installer identity is unavailable"
fi
# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "nixos" || "${VARIANT_ID:-}" != "installer" ]]; then
  fail "expected the NixOS installer, found ID=${ID:-unknown} VARIANT_ID=${VARIANT_ID:-unknown}"
fi

actual_arch="$(uname -m)"
[[ "$actual_arch" == "$expected_arch" ]] ||
  fail "architecture drift: expected $expected_arch, found $actual_arch"

virtualization="$(systemd-detect-virt 2>/dev/null || true)"
[[ "$virtualization" == "kvm" ]] ||
  fail "virtualization drift: expected kvm, found ${virtualization:-unknown}"

[[ ! -d /sys/firmware/efi ]] || fail "firmware drift: expected BIOS, found EFI"

resolved_disk="$(readlink -f "$expected_disk" 2>/dev/null || true)"
[[ -n "$resolved_disk" && -b "$resolved_disk" ]] ||
  fail "stable disk alias is missing or not a block device: $expected_disk"

mapfile -t writable_disks < <(
  lsblk -dnpo NAME,TYPE,RO |
    awk '$2 == "disk" && $3 == "0" { print $1 }'
)
(( ${#writable_disks[@]} == 1 )) ||
  fail "expected exactly one writable disk, found ${#writable_disks[@]}"

only_writable_disk="$(readlink -f "${writable_disks[0]}")"
[[ "$resolved_disk" == "$only_writable_disk" ]] ||
  fail "stable disk alias does not resolve to the only writable disk"

disk_size_bytes="$(blockdev --getsize64 "$resolved_disk")"
[[ "$disk_size_bytes" == "$expected_disk_size" ]] ||
  fail "target disk capacity drift: expected $expected_disk_size, found $disk_size_bytes"

disk_partition_table="$(lsblk -dnro PTTYPE "$resolved_disk" | xargs)"
[[ "$disk_partition_table" == "gpt" ]] ||
  fail "target disk partition table drift: expected GPT"

resolved_boot_partition="$(readlink -f "$expected_boot_partition" 2>/dev/null || true)"
[[ -n "$resolved_boot_partition" && -b "$resolved_boot_partition" ]] ||
  fail "declared BIOS boot partition alias is missing or not a block device"

resolved_root_partition="$(readlink -f "$expected_root_partition" 2>/dev/null || true)"
[[ -n "$resolved_root_partition" && -b "$resolved_root_partition" ]] ||
  fail "declared root partition alias is missing or not a block device"

root_parent_name="$(lsblk -ndo PKNAME "$resolved_root_partition" | xargs)"
[[ -n "$root_parent_name" ]] || fail "cannot resolve the root partition parent disk"
root_parent_disk="$(readlink -f "/dev/$root_parent_name")"
[[ "$root_parent_disk" == "$resolved_disk" ]] ||
  fail "declared root partition is not on the stable target disk"

boot_parent_name="$(lsblk -ndo PKNAME "$resolved_boot_partition" | xargs)"
[[ -n "$boot_parent_name" ]] || fail "cannot resolve the BIOS boot partition parent disk"
boot_parent_disk="$(readlink -f "/dev/$boot_parent_name")"
[[ "$boot_parent_disk" == "$resolved_disk" ]] ||
  fail "declared BIOS boot partition is not on the stable target disk"

partition_count="$(lsblk -nrpo TYPE "$resolved_disk" | awk '$1 == "part" { count++ } END { print count + 0 }')"
[[ "$partition_count" == "2" ]] ||
  fail "expected exactly the BIOS boot and root partitions, found $partition_count partitions"

bios_parttype="$(lsblk -dnro PARTTYPE "$resolved_boot_partition" | tr '[:upper:]' '[:lower:]' | xargs)"
[[ "$bios_parttype" == "21686148-6449-6e6f-744e-656564454649" ]] ||
  fail "BIOS boot partition type drift"
bios_partition_size="$(blockdev --getsize64 "$resolved_boot_partition")"
[[ "$bios_partition_size" == "1048576" ]] ||
  fail "BIOS boot partition size drift"

root_parttype="$(lsblk -dnro PARTTYPE "$resolved_root_partition" | tr '[:upper:]' '[:lower:]' | xargs)"
[[ "$root_parttype" == "0fc63daf-8483-4772-8e79-3d69d8477de4" ]] ||
  fail "root partition type drift"

mounted_source="$(findmnt -n -M /mnt -o SOURCE 2>/dev/null || true)"
mounted_fstype="$(findmnt -n -M /mnt -o FSTYPE 2>/dev/null || true)"
mounted_options="$(findmnt -n -M /mnt -o OPTIONS 2>/dev/null || true)"
[[ "$(readlink -f "$mounted_source" 2>/dev/null || true)" == "$resolved_root_partition" ]] ||
  fail "/mnt is not mounted from the declared root partition"
[[ "$mounted_fstype" == "ext4" ]] || fail "/mnt must be ext4"
[[ ",$mounted_options," == *,rw,* ]] || fail "/mnt must be mounted read-write"
[[ -w /mnt ]] || fail "/mnt is not writable"

if findmnt -rn -M /mnt/boot >/dev/null 2>&1; then
  fail "unexpected independent /mnt/boot mount"
fi

[[ -d /mnt/nix/store ]] || fail "partial /mnt/nix/store is missing"

[[ ! -e /mnt/nix/var/nix/profiles/system && ! -L /mnt/nix/var/nix/profiles/system ]] ||
  fail "target system profile already exists; installation state is no longer the approved partial copy"
[[ ! -e /mnt/boot/grub/grub.cfg ]] ||
  fail "target GRUB configuration already exists; installation state is no longer pre-install"
[[ ! -e /mnt/etc/NIXOS ]] ||
  fail "target NixOS installation marker already exists; installation state is no longer pre-install"

target_host_key_count=0
if [[ -d /mnt/etc/ssh ]]; then
  target_host_key_count="$(
    find /mnt/etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key' -size +0c |
      wc -l
  )"
fi
(( target_host_key_count == 0 )) ||
  fail "target already contains non-empty SSH host private keys"

source_host_key_count=0
if [[ -d /etc/ssh ]]; then
  source_host_key_count="$(
    find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key' -size +0c |
      wc -l
  )"
fi
(( source_host_key_count > 0 )) ||
  fail "installer has no non-empty SSH host private keys available to copy"

nic_names=()
for nic_path in /sys/class/net/*; do
  driver_path="$(readlink -f "$nic_path/device/driver" 2>/dev/null || true)"
  if [[ "$(basename "$driver_path")" == "$expected_nic_driver" ]]; then
    nic_names+=("$(basename "$nic_path")")
  fi
done
(( ${#nic_names[@]} == 1 )) ||
  fail "expected exactly one $expected_nic_driver NIC, found ${#nic_names[@]}"
nic_name="${nic_names[0]}"

mapfile -t ipv4_addresses < <(
  ip -4 -o address show dev "$nic_name" scope global | awk '{ print $4 }'
)
(( ${#ipv4_addresses[@]} == 1 )) && [[ "${ipv4_addresses[0]}" == "$expected_ipv4_address" ]] ||
  fail "IPv4 address drift on the provider NIC"

mapfile -t ipv6_addresses < <(
  ip -6 -o address show dev "$nic_name" scope global | awk '{ print $4 }'
)
(( ${#ipv6_addresses[@]} == 1 )) && [[ "${ipv6_addresses[0]}" == "$expected_ipv6_address" ]] ||
  fail "IPv6 address drift on the provider NIC"

mapfile -t ipv4_default_routes < <(ip -4 route show default dev "$nic_name")
(( ${#ipv4_default_routes[@]} == 1 )) || fail "expected exactly one IPv4 default route"
actual_ipv4_gateway="$(
  awk '{ for (i = 1; i <= NF; i += 1) if ($i == "via") { print $(i + 1); exit } }' \
    <<<"${ipv4_default_routes[0]}"
)"
[[ "$actual_ipv4_gateway" == "$expected_ipv4_gateway" ]] || fail "IPv4 gateway drift"

mapfile -t ipv6_default_routes < <(ip -6 route show default dev "$nic_name")
(( ${#ipv6_default_routes[@]} == 1 )) || fail "expected exactly one IPv6 default route"
actual_ipv6_gateway="$(
  awk '{ for (i = 1; i <= NF; i += 1) if ($i == "via") { print $(i + 1); exit } }' \
    <<<"${ipv6_default_routes[0]}"
)"
[[ "$actual_ipv6_gateway" == "$expected_ipv6_gateway" ]] || fail "IPv6 gateway drift"
[[ " ${ipv6_default_routes[0]} " =~ [[:space:]]onlink[[:space:]] ]] ||
  fail "IPv6 default route lost its on-link requirement"

actual_dns_csv="$(
  resolvectl dns "$nic_name" |
    awk -F': ' 'NR == 1 { print $2 }' |
    xargs |
    tr ' ' ','
)"
[[ "$actual_dns_csv" == "$expected_dns_csv" ]] || fail "DNS drift on the provider NIC"

printf 'phase10-resume-preflight: installer=nixos variant=installer arch=%s virt=%s boot=bios\n' \
  "$actual_arch" "$virtualization"
printf 'phase10-resume-preflight: disk alias=%s device=%s size-bytes=%s writable-count=1\n' \
  "$expected_disk" "$resolved_disk" "$disk_size_bytes"
printf 'phase10-resume-preflight: layout=gpt bios-boot=%s root=%s partitions=2 mount=/mnt fs=ext4 rw=yes boot-mount=absent partial-store=present install-artifacts=absent target-host-private-keys=0 source-host-private-keys=%s\n' \
  "$expected_boot_partition" "$expected_root_partition" "$source_host_key_count"
printf 'phase10-resume-preflight: network nic=%s driver=%s count=1 ipv4=%s ipv4-gateway=%s ipv6=%s ipv6-gateway=%s dns=%s\n' \
  "$nic_name" "$expected_nic_driver" "$expected_ipv4_address" "$expected_ipv4_gateway" \
  "$expected_ipv6_address" "$expected_ipv6_gateway" "$expected_dns_csv"
