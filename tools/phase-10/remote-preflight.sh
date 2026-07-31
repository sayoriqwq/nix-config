#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'phase10-preflight: %s\n' "$*" >&2
  exit 1
}

if (( $# != 8 )); then
  fail "internal argument contract mismatch"
fi

expected_disk="$1"
expected_ipv4_address="$2"
expected_ipv4_gateway="$3"
expected_ipv6_address="$4"
expected_ipv6_gateway="$5"
expected_dns_csv="$6"
expected_arch="$7"
expected_nic_driver="$8"

if (( EUID != 0 )); then
  fail "the trusted Ubuntu preflight must run as root"
fi

actual_arch="$(uname -m)"
if [[ "$actual_arch" != "$expected_arch" ]]; then
  fail "architecture drift: expected $expected_arch, found $actual_arch"
fi

virtualization="$(systemd-detect-virt 2>/dev/null || true)"
if [[ "$virtualization" != "kvm" ]]; then
  fail "virtualization drift: expected kvm, found ${virtualization:-unknown}"
fi

if [[ -d /sys/firmware/efi ]]; then
  fail "firmware drift: expected BIOS, found EFI"
fi

ram_kib="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)"
if [[ ! "$ram_kib" =~ ^[0-9]+$ ]] || (( ram_kib < 1572864 )); then
  fail "RAM preflight failed: expected at least 1572864 KiB"
fi

swap_count="$(awk 'NR > 1 { count += 1 } END { print count + 0 }' /proc/swaps)"
if (( swap_count != 0 )); then
  fail "swap drift: expected no active swap, found $swap_count entries"
fi

if [[ "$(cat /proc/sys/kernel/kexec_load_disabled)" != "0" ]]; then
  fail "kexec is disabled at runtime"
fi

kernel_config="/boot/config-$(uname -r)"
if [[ ! -r "$kernel_config" ]]; then
  fail "running kernel config is unavailable: $kernel_config"
fi
grep -qx 'CONFIG_KEXEC=y' "$kernel_config" || fail "running kernel lacks CONFIG_KEXEC=y"
grep -qx 'CONFIG_KEXEC_FILE=y' "$kernel_config" || fail "running kernel lacks CONFIG_KEXEC_FILE=y"

resolved_disk="$(readlink -f "$expected_disk" 2>/dev/null || true)"
if [[ -z "$resolved_disk" || ! -b "$resolved_disk" ]]; then
  fail "stable disk alias is missing or not a block device: $expected_disk"
fi

mapfile -t writable_disks < <(
  lsblk -dnpo NAME,TYPE,RO |
    awk '$2 == "disk" && $3 == "0" { print $1 }'
)
if (( ${#writable_disks[@]} != 1 )); then
  fail "expected exactly one writable disk, found ${#writable_disks[@]}"
fi

only_writable_disk="$(readlink -f "${writable_disks[0]}")"
if [[ "$resolved_disk" != "$only_writable_disk" ]]; then
  fail "stable disk alias does not resolve to the only writable disk"
fi

disk_size_bytes="$(blockdev --getsize64 "$resolved_disk")"
if [[ ! "$disk_size_bytes" =~ ^[0-9]+$ ]] || (( disk_size_bytes < 4294967296 )); then
  fail "target disk capacity is implausibly small"
fi

nic_names=()
for nic_path in /sys/class/net/*; do
  driver_path="$(readlink -f "$nic_path/device/driver" 2>/dev/null || true)"
  if [[ "$(basename "$driver_path")" == "$expected_nic_driver" ]]; then
    nic_names+=("$(basename "$nic_path")")
  fi
done

if (( ${#nic_names[@]} != 1 )); then
  fail "expected exactly one $expected_nic_driver NIC, found ${#nic_names[@]}"
fi
nic_name="${nic_names[0]}"

mapfile -t ipv4_addresses < <(
  ip -4 -o address show dev "$nic_name" scope global |
    awk '{ print $4 }'
)
if (( ${#ipv4_addresses[@]} != 1 )) || [[ "${ipv4_addresses[0]}" != "$expected_ipv4_address" ]]; then
  fail "IPv4 address drift on the provider NIC"
fi

mapfile -t ipv6_addresses < <(
  ip -6 -o address show dev "$nic_name" scope global |
    awk '{ print $4 }'
)
if (( ${#ipv6_addresses[@]} != 1 )) || [[ "${ipv6_addresses[0]}" != "$expected_ipv6_address" ]]; then
  fail "IPv6 address drift on the provider NIC"
fi

mapfile -t ipv4_default_routes < <(ip -4 route show default dev "$nic_name")
if (( ${#ipv4_default_routes[@]} != 1 )); then
  fail "expected exactly one IPv4 default route"
fi
actual_ipv4_gateway="$(
  awk '{
    for (i = 1; i <= NF; i += 1) {
      if ($i == "via") {
        print $(i + 1)
        exit
      }
    }
  }' <<<"${ipv4_default_routes[0]}"
)"
if [[ "$actual_ipv4_gateway" != "$expected_ipv4_gateway" ]]; then
  fail "IPv4 gateway drift"
fi

mapfile -t ipv6_default_routes < <(ip -6 route show default dev "$nic_name")
if (( ${#ipv6_default_routes[@]} != 1 )); then
  fail "expected exactly one IPv6 default route"
fi
actual_ipv6_gateway="$(
  awk '{
    for (i = 1; i <= NF; i += 1) {
      if ($i == "via") {
        print $(i + 1)
        exit
      }
    }
  }' <<<"${ipv6_default_routes[0]}"
)"
if [[ "$actual_ipv6_gateway" != "$expected_ipv6_gateway" ]]; then
  fail "IPv6 gateway drift"
fi
if [[ ! " ${ipv6_default_routes[0]} " =~ [[:space:]]onlink[[:space:]] ]]; then
  fail "IPv6 default route lost its on-link requirement"
fi

actual_dns_csv="$(
  resolvectl dns "$nic_name" |
    awk -F': ' 'NR == 1 { print $2 }' |
    xargs |
    tr ' ' ','
)"
if [[ "$actual_dns_csv" != "$expected_dns_csv" ]]; then
  fail "DNS drift on the provider NIC"
fi

command -v tar >/dev/null || fail "required bootstrap tool is missing: tar"
command -v setsid >/dev/null || fail "required bootstrap tool is missing: setsid"

authorized_keys_state="$(stat -c '%a:%U:%G' /root/.ssh/authorized_keys 2>/dev/null || true)"
if [[ "$authorized_keys_state" != "600:root:root" ]]; then
  fail "root authorized_keys mode or ownership drifted"
fi

host_key_count="$(
  find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key' -size +0c |
    wc -l
)"
if (( host_key_count == 0 )); then
  fail "no existing SSH host private keys are available to copy"
fi

system_state="$(systemctl is-system-running 2>/dev/null || true)"
case "$system_state" in
  running | degraded) ;;
  *) fail "unexpected system state: ${system_state:-unknown}" ;;
esac

unexpected_failed_units=()
while IFS= read -r failed_unit; do
  case "$failed_unit" in
    "" | cloud-init.service | nginx.service | systemd-networkd-wait-online.service) ;;
    *) unexpected_failed_units+=("$failed_unit") ;;
  esac
done < <(
  systemctl list-units --state=failed --no-legend --no-pager --plain |
    awk '{ print $1 }'
)
if (( ${#unexpected_failed_units[@]} != 0 )); then
  fail "new failed units detected: ${unexpected_failed_units[*]}"
fi

recent_kernel_warnings="$(
  journalctl -k -b --since '-6 hours' --no-pager -o cat |
    grep -Ei 'soft lockup|rcu.*stall|rcu_preempt|starved|NMI backtrace' ||
    true
)"
if [[ -n "$recent_kernel_warnings" ]]; then
  fail "recent soft-lockup or RCU-stall kernel warnings detected"
fi

printf 'phase10-preflight: system arch=%s virt=%s boot=bios ram-kib=%s swap=%s kexec=enabled state=%s\n' \
  "$actual_arch" "$virtualization" "$ram_kib" "$swap_count" "$system_state"
printf 'phase10-preflight: disk alias=%s device=%s size-bytes=%s writable-count=1\n' \
  "$expected_disk" "$resolved_disk" "$disk_size_bytes"
printf 'phase10-preflight: network nic=%s driver=%s count=1 ipv4=%s ipv4-gateway=%s ipv6=%s ipv6-gateway=%s dns=%s\n' \
  "$nic_name" "$expected_nic_driver" "$expected_ipv4_address" "$expected_ipv4_gateway" \
  "$expected_ipv6_address" "$expected_ipv6_gateway" "$expected_dns_csv"
printf 'phase10-preflight: ssh bootstrap-tools=ok authorized-keys=ok copyable-host-keys=%s recent-kernel-warnings=0\n' \
  "$host_key_count"
