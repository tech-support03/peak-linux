#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  peak-linux Installer                                       ║
# ║  Guided Arch Linux install → Hyprland + macOS rice          ║
# ║  Run from the live ISO environment                          ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Colors / helpers ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
die()     { echo -e "${RED}[FATAL]${NC} $1"; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}▸ $1${NC}"; }
ask()     { echo -en "${BOLD}$1${NC}"; }
divider() { echo -e "${CYAN}────────────────────────────────────────────${NC}"; }

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PEAK_DIR="$INSTALLER_DIR/peak-linux"
MOUNT="/mnt"

# ── Pre-flight ─────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run this installer as root"
[[ -d /run/archiso ]] || warn "Not running from the live ISO — proceed with caution"

clear
echo -e "${BOLD}"
cat << 'BANNER'

    ┌─────────────────────────────────────────┐
    │                                         │
    │            peak-linux                   │
    │     macOS-themed Arch with Hyprland     │
    │                                         │
    │         Guided Installer                │
    │                                         │
    └─────────────────────────────────────────┘

BANNER
echo -e "${NC}"
echo "  This installer will:"
echo "    1. Partition and format your disk"
echo "    2. Install Arch Linux base system"
echo "    3. Configure Hyprland + macOS theme"
echo "    4. Set up developer tools + Secure Boot"
echo ""
divider
echo ""

# ══════════════════════════════════════════════════════════════
# STEP 1: Collect user information
# ══════════════════════════════════════════════════════════════
step "System Configuration"
echo ""

# Hostname
ask "Hostname [peak]: "
read -r HOSTNAME
HOSTNAME="${HOSTNAME:-peak}"

# Username
ask "Username: "
read -r USERNAME
[[ -n "$USERNAME" ]] || die "Username cannot be empty"

# Password
while true; do
    ask "Password for $USERNAME: "
    read -rs PASSWORD
    echo ""
    ask "Confirm password: "
    read -rs PASSWORD2
    echo ""
    [[ "$PASSWORD" == "$PASSWORD2" ]] && break
    warn "Passwords do not match, try again"
done

# Root password
ask "Use same password for root? [Y/n]: "
read -r SAME_ROOT
if [[ "$SAME_ROOT" =~ ^[Nn]$ ]]; then
    while true; do
        ask "Root password: "
        read -rs ROOT_PASSWORD
        echo ""
        ask "Confirm root password: "
        read -rs ROOT_PASSWORD2
        echo ""
        [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD2" ]] && break
        warn "Passwords do not match, try again"
    done
else
    ROOT_PASSWORD="$PASSWORD"
fi

# Timezone
ask "Timezone [America/New_York]: "
read -r TIMEZONE
TIMEZONE="${TIMEZONE:-America/New_York}"
[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Invalid timezone: $TIMEZONE"

# Locale
ask "Locale [en_US.UTF-8]: "
read -r LOCALE
LOCALE="${LOCALE:-en_US.UTF-8}"

# Kernel
echo ""
echo "  Available kernels:"
echo "    1) linux        (stable, recommended)"
echo "    2) linux-lts    (long-term support)"
echo "    3) linux-zen    (performance-tuned)"
ask "Kernel [1]: "
read -r KERNEL_CHOICE
case "${KERNEL_CHOICE:-1}" in
    1) KERNEL="linux" ;;
    2) KERNEL="linux-lts" ;;
    3) KERNEL="linux-zen" ;;
    *) KERNEL="linux" ;;
esac

echo ""
divider

# ══════════════════════════════════════════════════════════════
# STEP 2: Disk selection and partitioning
# ══════════════════════════════════════════════════════════════
step "Disk Partitioning"
echo ""

# List available disks
echo "  Available disks:"
echo ""
lsblk -dno NAME,SIZE,MODEL | grep -v "loop\|sr\|rom" | while read -r line; do
    echo "    /dev/$line"
done
echo ""

ask "Target disk (e.g., /dev/sda or /dev/nvme0n1): "
read -r TARGET_DISK
[[ -b "$TARGET_DISK" ]] || die "Disk not found: $TARGET_DISK"

# Detect partition naming scheme (nvme uses p1, p2; sata uses 1, 2)
if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

echo ""
echo -e "  ${RED}${BOLD}WARNING: This will ERASE ALL DATA on ${TARGET_DISK}${NC}"
echo ""
lsblk "$TARGET_DISK"
echo ""
ask "Type 'yes' to continue: "
read -r CONFIRM
[[ "$CONFIRM" == "yes" ]] || die "Aborted by user"

# Filesystem choice
echo ""
echo "  Filesystem options:"
echo "    1) ext4    (stable, traditional)"
echo "    2) btrfs   (snapshots, compression)"
ask "Filesystem [1]: "
read -r FS_CHOICE
case "${FS_CHOICE:-1}" in
    1) FILESYSTEM="ext4" ;;
    2) FILESYSTEM="btrfs" ;;
    *) FILESYSTEM="ext4" ;;
esac

# Swap
ask "Swap size in GB (0 for none) [4]: "
read -r SWAP_SIZE
SWAP_SIZE="${SWAP_SIZE:-4}"

echo ""
info "Partitioning $TARGET_DISK..."

# Wipe and create GPT partition table
sgdisk --zap-all "$TARGET_DISK"
sgdisk --clear "$TARGET_DISK"

# Partition layout:
#   1: EFI System Partition (512M)
#   2: Swap (optional)
#   3: Root (remaining space)
PART_NUM=0

# EFI partition
PART_NUM=$((PART_NUM + 1))
EFI_PART_NUM=$PART_NUM
sgdisk -n "${PART_NUM}:0:+512M" -t "${PART_NUM}:ef00" -c "${PART_NUM}:EFI" "$TARGET_DISK"
EFI_PART="${PART_PREFIX}${EFI_PART_NUM}"

# Swap partition
if [[ "$SWAP_SIZE" -gt 0 ]]; then
    PART_NUM=$((PART_NUM + 1))
    SWAP_PART_NUM=$PART_NUM
    sgdisk -n "${PART_NUM}:0:+${SWAP_SIZE}G" -t "${PART_NUM}:8200" -c "${PART_NUM}:swap" "$TARGET_DISK"
    SWAP_PART="${PART_PREFIX}${SWAP_PART_NUM}"
else
    SWAP_PART=""
fi

# Root partition
PART_NUM=$((PART_NUM + 1))
ROOT_PART_NUM=$PART_NUM
sgdisk -n "${PART_NUM}:0:0" -t "${PART_NUM}:8300" -c "${PART_NUM}:root" "$TARGET_DISK"
ROOT_PART="${PART_PREFIX}${ROOT_PART_NUM}"

# Reload partition table
partprobe "$TARGET_DISK"
sleep 2

ok "Partitioned: EFI=${EFI_PART} Swap=${SWAP_PART:-none} Root=${ROOT_PART}"

# ── Format partitions ─────────────────────────────────────────
info "Formatting partitions..."

mkfs.fat -F32 "$EFI_PART"

if [[ -n "$SWAP_PART" ]]; then
    mkswap "$SWAP_PART"
    swapon "$SWAP_PART"
fi

case "$FILESYSTEM" in
    ext4)
        mkfs.ext4 -F "$ROOT_PART"
        ;;
    btrfs)
        mkfs.btrfs -f "$ROOT_PART"
        ;;
esac

ok "Partitions formatted"

# ── Mount filesystems ─────────────────────────────────────────
info "Mounting filesystems..."

case "$FILESYSTEM" in
    ext4)
        mount "$ROOT_PART" "$MOUNT"
        ;;
    btrfs)
        mount "$ROOT_PART" "$MOUNT"
        btrfs subvolume create "$MOUNT/@"
        btrfs subvolume create "$MOUNT/@home"
        btrfs subvolume create "$MOUNT/@snapshots"
        umount "$MOUNT"
        mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "$ROOT_PART" "$MOUNT"
        mkdir -p "$MOUNT/home" "$MOUNT/.snapshots"
        mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "$ROOT_PART" "$MOUNT/home"
        mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots "$ROOT_PART" "$MOUNT/.snapshots"
        ;;
esac

mkdir -p "$MOUNT/boot/efi"
mount "$EFI_PART" "$MOUNT/boot/efi"

ok "Filesystems mounted"

echo ""
divider

# ══════════════════════════════════════════════════════════════
# STEP 3: Install base system
# ══════════════════════════════════════════════════════════════
step "Installing Base System"

# Optimize mirrors
info "Selecting fastest mirrors..."
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || true

# Enable parallel downloads
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

info "Running pacstrap (this will take a few minutes)..."

pacstrap -K "$MOUNT" \
    base $KERNEL ${KERNEL}-headers linux-firmware \
    base-devel grub efibootmgr os-prober \
    networkmanager network-manager-applet \
    bluez bluez-utils \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    sudo nano neovim git \
    zsh \
    reflector

ok "Base system installed"

# ── Generate fstab ────────────────────────────────────────────
info "Generating fstab..."
genfstab -U "$MOUNT" >> "$MOUNT/etc/fstab"
ok "fstab generated"

echo ""
divider

# ══════════════════════════════════════════════════════════════
# STEP 4: Configure system in chroot
# ══════════════════════════════════════════════════════════════
step "Configuring System"

# Copy peak-linux files into the new system
cp -r "$PEAK_DIR" "$MOUNT/root/peak-linux"

# Create the chroot setup script
cat > "$MOUNT/root/peak-setup.sh" << CHROOTEOF
#!/usr/bin/env bash
set -euo pipefail

info()  { echo -e "\033[0;34m[INFO]\033[0m \$1"; }
ok()    { echo -e "\033[0;32m[OK]\033[0m \$1"; }

# ── Timezone & locale ──────────────────────────────────────────
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
ok "Timezone and locale configured"

# ── Hostname ───────────────────────────────────────────────────
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
ok "Hostname set to $HOSTNAME"

# ── Users ──────────────────────────────────────────────────────
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel,audio,video,input,storage,network -s /bin/zsh "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
ok "User $USERNAME created"

# ── Pacman config ──────────────────────────────────────────────
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm

# ── Bootloader (GRUB) ─────────────────────────────────────────
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=peak-linux --recheck
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
ok "GRUB installed"

# ── Enable base services ──────────────────────────────────────
systemctl enable NetworkManager
systemctl enable bluetooth
ok "Base services enabled"

# ── Install all peak-linux packages ───────────────────────────
info "Installing desktop packages..."

pacman -S --needed --noconfirm \
    hyprland hyprlock hypridle \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    qt5-wayland qt6-wayland \
    waybar wofi dunst libnotify \
    kitty thunar gvfs imv mpv firefox \
    brightnessctl playerctl polkit-gnome gnome-keyring \
    grim slurp wl-clipboard cliphist swww sbctl \
    sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg \
    lazygit ripgrep fd fzf tree unzip wget curl openssh npm nodejs python \
    starship eza bat zoxide \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
    nwg-look papirus-icon-theme

ok "Desktop packages installed"

# ── SDDM ──────────────────────────────────────────────────────
systemctl enable sddm
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/default.conf << SDDMEOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
SDDMEOF
ok "SDDM enabled"

# ── Install paru (AUR helper) as the user ─────────────────────
info "Installing paru (AUR helper)..."
sudo -u "$USERNAME" bash -c '
    cd /tmp
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf paru-bin
'
ok "paru installed"

# ── Install AUR packages ──────────────────────────────────────
info "Installing AUR packages (themes, fonts, dock)..."
sudo -u "$USERNAME" paru -S --needed --noconfirm \
    inter-font \
    nwg-dock-hyprland \
    whitesur-gtk-theme \
    whitesur-icon-theme \
    whitesur-cursor-theme \
    sddm-sugar-candy-git || {
    echo "[WARN] Some AUR packages may have failed — you can install them later"
}

# Apply sugar-candy theme if installed
if [[ -d /usr/share/sddm/themes/sugar-candy ]]; then
    sed -i '/\[Theme\]/a Current=sugar-candy' /etc/sddm.conf.d/default.conf
    ok "SDDM sugar-candy theme applied"
fi

ok "AUR packages installed"

# ── Deploy configs for the user ────────────────────────────────
info "Deploying peak-linux configs..."
USER_HOME="/home/$USERNAME"
CONFIG_SRC="/root/peak-linux/configs"

mkdir -p "\$USER_HOME/.config"

# Deploy each config directory
for dir in hypr waybar wofi kitty dunst gtk-3.0; do
    if [[ -d "\$CONFIG_SRC/\$dir" ]]; then
        cp -r "\$CONFIG_SRC/\$dir" "\$USER_HOME/.config/\$dir"
    fi
done

# Starship
mkdir -p "\$USER_HOME/.config"
cp "\$CONFIG_SRC/starship/starship.toml" "\$USER_HOME/.config/starship.toml"

# Zsh
cp "\$CONFIG_SRC/zsh/.zshrc" "\$USER_HOME/.zshrc"

# Environment
mkdir -p "\$USER_HOME/.config/environment.d"
cp "\$CONFIG_SRC/environment" "\$USER_HOME/.config/environment.d/peak-linux.conf"

# Cursor theme
mkdir -p "\$USER_HOME/.icons/default"
cat > "\$USER_HOME/.icons/default/index.theme" << CURSOREOF
[Icon Theme]
Inherits=WhiteSur-cursors
CURSOREOF

# Wallpaper directory
mkdir -p "\$USER_HOME/.local/share/wallpapers"
mkdir -p "\$USER_HOME/Pictures"

# Fix ownership
chown -R "$USERNAME:$USERNAME" "\$USER_HOME"

ok "Configs deployed to \$USER_HOME"

# ── Secure Boot prep ──────────────────────────────────────────
info "Preparing Secure Boot keys (will be enrolled on first boot if Setup Mode is active)..."
sbctl create-keys 2>/dev/null || true
sbctl sign -s /boot/efi/EFI/peak-linux/grubx64.efi 2>/dev/null || true
for kernel in /boot/vmlinuz-*; do
    sbctl sign -s "\$kernel" 2>/dev/null || true
done
ok "Secure Boot files signed (enable Setup Mode in BIOS to enroll keys)"

# ── Cleanup ────────────────────────────────────────────────────
rm -rf /root/peak-linux /root/peak-setup.sh
pacman -Scc --noconfirm 2>/dev/null || true

ok "System configuration complete"
CHROOTEOF

chmod +x "$MOUNT/root/peak-setup.sh"

# Run the chroot setup
info "Entering chroot to configure the system..."
arch-chroot "$MOUNT" /root/peak-setup.sh

ok "Chroot configuration complete"

echo ""
divider

# ══════════════════════════════════════════════════════════════
# STEP 5: Finalize
# ══════════════════════════════════════════════════════════════
step "Finalizing Installation"

# Unmount
info "Unmounting filesystems..."
umount -R "$MOUNT"
[[ -n "$SWAP_PART" ]] && swapoff "$SWAP_PART" 2>/dev/null || true

ok "Filesystems unmounted"

echo ""
echo -e "${GREEN}${BOLD}"
cat << 'DONE'
  ╔══════════════════════════════════════════╗
  ║                                          ║
  ║    peak-linux installed successfully!    ║
  ║                                          ║
  ╚══════════════════════════════════════════╝
DONE
echo -e "${NC}"
echo "  Next steps:"
echo "    1. Remove the USB drive"
echo "    2. Reboot: type 'reboot'"
echo "    3. Log in at SDDM → Hyprland session"
echo ""
echo "  For Secure Boot:"
echo "    - Enter BIOS → enable Setup Mode"
echo "    - Boot into Arch → run: sudo sbctl enroll-keys --microsoft"
echo "    - Reboot → enable Secure Boot in BIOS"
echo ""
echo "  Quick start:"
echo "    Super+Enter  → Terminal"
echo "    Super+D      → App Launcher"
echo "    Super+Q      → Close Window"
echo "    Super+B      → Firefox"
echo ""
echo "  Drop a wallpaper at: ~/.local/share/wallpapers/default.jpg"
echo ""
