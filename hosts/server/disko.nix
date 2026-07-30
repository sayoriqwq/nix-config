let
  targetDisk = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
in
{
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
    useOSProber = false;
  };

  disko.devices.disk.main = {
    type = "disk";
    device = targetDisk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
          attributes = [ 0 ];
        };

        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
