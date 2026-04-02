#!/usr/bin/env bash
# peak-linux archiso profile definition

iso_name="peak-linux"
iso_label="PEAK_LINUX_$(date +%Y%m)"
iso_publisher="peak-linux"
iso_application="peak-linux Live/Install Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.grub.esp'
    'uefi-x64.grub.esp'
    'uefi-ia32.grub.eltorito'
    'uefi-x64.grub.eltorito'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
    ["/root"]="0:0:750"
    ["/root/peak-installer.sh"]="0:0:755"
    ["/root/peak-linux"]="0:0:755"
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
)
