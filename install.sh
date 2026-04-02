#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  peak-linux — macOS-themed Arch Linux with Hyprland         ║
# ║  Minimal, bloat-free, daily-driver setup                    ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${RED}[WARN]${NC} $1"; }
step()  { echo -e "\n${CYAN}${BOLD}▸ $1${NC}"; }

# ── Pre-flight checks ──────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    warn "Do not run this script as root. It will use sudo when needed."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    warn "This script is intended for Arch Linux only."
    exit 1
fi

echo -e "${BOLD}"
echo "  ┌─────────────────────────────────────┐"
echo "  │         peak-linux installer         │"
echo "  │   macOS-themed Hyprland for Arch     │"
echo "  └─────────────────────────────────────┘"
echo -e "${NC}"
echo "This will install and configure:"
echo "  • Hyprland compositor + Waybar + wofi"
echo "  • macOS theme (WhiteSur GTK + icons)"
echo "  • Developer tools (neovim, git, zsh)"
echo "  • PipeWire audio + essential system utils"
echo "  • Secure Boot with custom keys (sbctl)"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

# ── 1. System update ───────────────────────────────────────────
step "Updating system"
sudo pacman -Syu --noconfirm

# ── 2. Install paru (AUR helper) if not present ───────────────
step "Setting up AUR helper (paru)"
if ! command -v paru &>/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    TMPDIR_PARU=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$TMPDIR_PARU/paru-bin"
    (cd "$TMPDIR_PARU/paru-bin" && makepkg -si --noconfirm)
    rm -rf "$TMPDIR_PARU"
    ok "paru installed"
else
    ok "paru already installed"
fi

# ── 3. Install packages ───────────────────────────────────────
step "Installing packages"

# Core Wayland / Hyprland
PKGS_HYPRLAND=(
    hyprland
    hyprlock
    hypridle
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
)

# Bar, launcher, notifications
PKGS_UI=(
    waybar
    wofi
    dunst
    libnotify
)

# Terminal & file manager
PKGS_APPS=(
    kitty
    thunar
    gvfs
    imv
    mpv
    firefox
)

# System essentials
PKGS_SYSTEM=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    networkmanager
    network-manager-applet
    bluez
    bluez-utils
    brightnessctl
    playerctl
    polkit-gnome
    gnome-keyring
    grim
    slurp
    wl-clipboard
    cliphist
    swww
    sbctl
)

# Developer tools
PKGS_DEV=(
    neovim
    git
    lazygit
    ripgrep
    fd
    fzf
    tree
    unzip
    wget
    curl
    openssh
    base-devel
    python
    nodejs
    npm
)

# Shell
PKGS_SHELL=(
    zsh
    starship
    eza
    bat
    zoxide
)

# Fonts
PKGS_FONTS=(
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
)

# Theming
PKGS_THEME=(
    nwg-look
    papirus-icon-theme
)

# SDDM and its theme dependencies
PKGS_SDDM=(
    sddm
    qt5-graphicaleffects
    qt5-quickcontrols2
    qt5-svg
)

# AUR packages (not in official repos — installed via paru)
AUR_PKGS=(
    inter-font
    nwg-dock-hyprland
    whitesur-gtk-theme
    whitesur-icon-theme
    whitesur-cursor-theme
    sddm-sugar-candy-git
)

# Combine all official packages
ALL_OFFICIAL=(
    "${PKGS_HYPRLAND[@]}"
    "${PKGS_UI[@]}"
    "${PKGS_APPS[@]}"
    "${PKGS_SYSTEM[@]}"
    "${PKGS_DEV[@]}"
    "${PKGS_SHELL[@]}"
    "${PKGS_FONTS[@]}"
    "${PKGS_THEME[@]}"
    "${PKGS_SDDM[@]}"
)

# Validate official packages exist in repos before installing
info "Validating official packages..."
MISSING_OFFICIAL=()
for pkg in "${ALL_OFFICIAL[@]}"; do
    if ! pacman -Si "$pkg" &>/dev/null; then
        MISSING_OFFICIAL+=("$pkg")
    fi
done

if [[ ${#MISSING_OFFICIAL[@]} -gt 0 ]]; then
    warn "The following packages were not found in official repos:"
    for pkg in "${MISSING_OFFICIAL[@]}"; do
        echo "    • $pkg"
    done
    echo ""
    info "Checking if they exist in the AUR instead..."
    for pkg in "${MISSING_OFFICIAL[@]}"; do
        if paru -Si "$pkg" &>/dev/null; then
            info "  $pkg → found in AUR, moving it there"
            AUR_PKGS+=("$pkg")
        else
            warn "  $pkg → not found anywhere, skipping"
        fi
    done
    # Remove missing packages from official list
    VALIDATED_OFFICIAL=()
    for pkg in "${ALL_OFFICIAL[@]}"; do
        skip=false
        for missing in "${MISSING_OFFICIAL[@]}"; do
            if [[ "$pkg" == "$missing" ]]; then
                skip=true
                break
            fi
        done
        if [[ "$skip" == false ]]; then
            VALIDATED_OFFICIAL+=("$pkg")
        fi
    done
    ALL_OFFICIAL=("${VALIDATED_OFFICIAL[@]}")
fi
ok "Package validation complete"

# Install official packages
sudo pacman -S --needed --noconfirm "${ALL_OFFICIAL[@]}"
ok "Official packages installed"

# Validate AUR packages exist before installing
info "Validating AUR packages..."
VALIDATED_AUR=()
for pkg in "${AUR_PKGS[@]}"; do
    if paru -Si "$pkg" &>/dev/null; then
        VALIDATED_AUR+=("$pkg")
    else
        warn "AUR package not found: $pkg — skipping"
    fi
done

if [[ ${#VALIDATED_AUR[@]} -gt 0 ]]; then
    paru -S --needed --noconfirm "${VALIDATED_AUR[@]}"
fi
ok "AUR packages installed"

# ── 4. Deploy config files ────────────────────────────────────
step "Deploying configuration files"

deploy() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -e "$dest" ]]; then
        cp "$dest" "${dest}.bak.$(date +%s)"
        info "Backed up existing $(basename "$dest")"
    fi
    cp -r "$src" "$dest"
}

# Hyprland
deploy "$CONFIG_DIR/hypr"         "$HOME/.config/hypr"

# Waybar
deploy "$CONFIG_DIR/waybar"       "$HOME/.config/waybar"

# wofi
deploy "$CONFIG_DIR/wofi"         "$HOME/.config/wofi"

# kitty
deploy "$CONFIG_DIR/kitty"        "$HOME/.config/kitty"

# dunst
deploy "$CONFIG_DIR/dunst"        "$HOME/.config/dunst"

# GTK
deploy "$CONFIG_DIR/gtk-3.0"      "$HOME/.config/gtk-3.0"

# Wallpaper
mkdir -p "$HOME/.local/share/wallpapers"
if [[ -d "$SCRIPT_DIR/wallpapers" ]]; then
    cp "$SCRIPT_DIR/wallpapers/"* "$HOME/.local/share/wallpapers/" 2>/dev/null || true
fi

ok "Configs deployed"

# ── 5. Shell setup ─────────────────────────────────────────────
step "Configuring shell"

# Deploy zsh and starship configs BEFORE changing shell
deploy "$CONFIG_DIR/zsh/.zshrc"        "$HOME/.zshrc"
deploy "$CONFIG_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

# Verify zsh exists, then set as default
if command -v zsh &>/dev/null; then
    if [[ "$SHELL" != *"zsh"* ]]; then
        chsh -s "$(which zsh)"
        ok "Default shell changed to zsh"
    fi
else
    warn "zsh not found — kitty will fall back to /bin/bash"
    # Patch kitty config to use bash if zsh is missing
    sed -i 's|shell /bin/zsh --login|shell /bin/bash --login|' "$HOME/.config/kitty/kitty.conf"
fi

ok "Shell configured"

# ── 6. Enable services ────────────────────────────────────────
step "Enabling system services"

sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Enable SDDM
sudo systemctl enable sddm 2>/dev/null || true

ok "Services enabled"

# ── 7. SDDM setup ─────────────────────────────────────────────
step "Configuring SDDM"

# Disable any other display manager that might conflict
for dm in gdm lightdm lxdm ly; do
    sudo systemctl disable "$dm" 2>/dev/null || true
done

# Main SDDM config
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/default.conf > /dev/null << 'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Theme]
Current=sugar-candy

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
EOF

# Fallback: if sugar-candy is missing, use breeze
if [[ ! -d /usr/share/sddm/themes/sugar-candy ]]; then
    warn "sugar-candy theme not found, falling back to default"
    sudo tee /etc/sddm.conf.d/default.conf > /dev/null << 'EOF'
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
EOF
fi

ok "SDDM configured"

# ── 8. Secure Boot ─────────────────────────────────────────────
step "Configuring Secure Boot"

# Check if system is UEFI
if [[ -d /sys/firmware/efi ]]; then
    # Check if Secure Boot is already in Setup Mode or can be configured
    if sbctl status 2>/dev/null | grep -q "Setup Mode:.*Enabled"; then
        info "Secure Boot is in Setup Mode — creating and enrolling keys"

        # Create custom Secure Boot keys
        sudo sbctl create-keys
        ok "Secure Boot keys created"

        # Enroll keys (include Microsoft keys for firmware compatibility)
        sudo sbctl enroll-keys --microsoft
        ok "Keys enrolled (with Microsoft vendor keys for compatibility)"

        # Sign all boot files that need signing
        # Detect and sign the kernel + bootloader
        info "Signing boot files..."

        # Sign the bootloader
        if [[ -f /boot/EFI/BOOT/BOOTX64.EFI ]]; then
            sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
        fi
        if [[ -f /boot/EFI/systemd/systemd-bootx64.efi ]]; then
            sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
        fi
        if [[ -f /boot/EFI/GRUB/grubx64.efi ]]; then
            sudo sbctl sign -s /boot/EFI/GRUB/grubx64.efi
        fi

        # Sign all installed kernels
        for kernel in /boot/vmlinuz-*; do
            if [[ -f "$kernel" ]]; then
                sudo sbctl sign -s "$kernel"
                info "Signed $kernel"
            fi
        done

        # Sign any unified kernel images
        for uki in /boot/EFI/Linux/*.efi; do
            if [[ -f "$uki" ]]; then
                sudo sbctl sign -s "$uki"
                info "Signed $uki"
            fi
        done

        # Verify all files are signed
        echo ""
        sudo sbctl verify
        ok "Secure Boot configured — enable Secure Boot in BIOS on next reboot"

    elif sbctl status 2>/dev/null | grep -q "Secure Boot:.*Enabled"; then
        ok "Secure Boot is already enabled and active"

        # Still sign any unsigned files
        if sudo sbctl verify 2>&1 | grep -q "not signed"; then
            info "Found unsigned boot files — signing them now"
            for unsigned in $(sudo sbctl verify 2>&1 | grep "not signed" | awk '{print $2}'); do
                sudo sbctl sign -s "$unsigned"
                info "Signed $unsigned"
            done
            ok "All boot files signed"
        else
            ok "All boot files are properly signed"
        fi
    else
        warn "Secure Boot is not in Setup Mode."
        echo ""
        echo "  To enable Secure Boot with custom keys:"
        echo "    1. Reboot into BIOS/UEFI firmware settings"
        echo "    2. Find Secure Boot settings and switch to 'Setup Mode'"
        echo "       (this clears existing keys — often under Security tab)"
        echo "    3. Save and reboot back into Arch"
        echo "    4. Re-run this script or manually run:"
        echo "         sudo sbctl create-keys"
        echo "         sudo sbctl enroll-keys --microsoft"
        echo "         sudo sbctl sign -s /boot/vmlinuz-linux"
        echo "         sudo sbctl sign -s <your-bootloader.efi>"
        echo ""
        info "Skipping Secure Boot setup for now"
    fi
else
    warn "System is not booted in UEFI mode — Secure Boot requires UEFI"
    info "Skipping Secure Boot setup"
fi

# ── 9. GTK/cursor environment ─────────────────────────────────
step "Setting GTK and cursor theme"

# Set cursor theme system-wide
mkdir -p "$HOME/.icons/default"
cat > "$HOME/.icons/default/index.theme" << 'EOF'
[Icon Theme]
Inherits=WhiteSur-cursors
EOF

# Environment variables for Hyprland session
deploy "$CONFIG_DIR/environment" "$HOME/.config/environment.d/peak-linux.conf"

ok "Theme environment configured"

# ── Done ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  peak-linux installation complete!       ${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot into BIOS and enable Secure Boot (if not already)"
echo "     - If keys weren't enrolled: put Secure Boot in Setup Mode first,"
echo "       reboot into Arch, and run: sudo sbctl create-keys && sudo sbctl enroll-keys --microsoft"
echo "  2. Reboot and select Hyprland at the SDDM login screen"
echo "  3. Super+D to open app launcher"
echo "  4. Super+Enter to open terminal"
echo ""
echo "Verify Secure Boot: sbctl status"
echo "Key bindings: ~/.config/hypr/hyprland.conf"
echo ""
