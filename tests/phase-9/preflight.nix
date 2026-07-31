{ pkgs }:

pkgs.writeShellApplication {
  name = "phase9-vm-preflight";
  runtimeInputs = [
    pkgs.coreutils
  ];
  text = ''
    expected_boot_mode="''${PHASE9_EXPECTED_BOOT_MODE:-bios}"
    expected_nic_driver="''${PHASE9_EXPECTED_NIC_DRIVER:-virtio_net}"
    expected_nic_count="''${PHASE9_EXPECTED_NIC_COUNT:-1}"
    expected_disk="''${PHASE9_EXPECTED_DISK:-}"

    case "$expected_boot_mode" in
      bios)
        if test -d /sys/firmware/efi; then
          echo "preflight: expected BIOS but EFI firmware is present" >&2
          exit 1
        fi
        ;;
      uefi)
        if ! test -d /sys/firmware/efi; then
          echo "preflight: expected UEFI but EFI firmware is absent" >&2
          exit 1
        fi
        ;;
      *)
        echo "preflight: unsupported boot mode: $expected_boot_mode" >&2
        exit 1
        ;;
    esac

    nic_count=0
    for nic_path in /sys/class/net/*; do
      driver_path="$(readlink -f "$nic_path/device/driver" 2>/dev/null || true)"
      if test "$(basename "$driver_path")" = "$expected_nic_driver"; then
        nic_count=$((nic_count + 1))
      fi
    done

    if test "$nic_count" -ne "$expected_nic_count"; then
      echo "preflight: expected $expected_nic_count $expected_nic_driver NIC, found $nic_count" >&2
      exit 1
    fi

    if test -n "$expected_disk"; then
      resolved_disk="$(readlink -f "$expected_disk" 2>/dev/null || true)"
      if test -z "$resolved_disk" || ! test -b "$resolved_disk"; then
        echo "preflight: expected test disk is not a block device: $expected_disk" >&2
        exit 1
      fi
    fi

    echo "preflight: boot=$expected_boot_mode nic-driver=$expected_nic_driver nic-count=$nic_count"
    if test -n "$expected_disk"; then
      echo "preflight: disk=$resolved_disk"
    fi
  '';
}
