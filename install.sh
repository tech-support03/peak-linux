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
    hyprpaper
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
)

# Bar, launcher, dock, notifications
PKGS_UI=(
    waybar
    wofi
    nwg-dock-hyprland
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
    ttf-inter
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
)

# Theming
PKGS_THEME=(
    nwg-look
    papirus-icon-theme
)

# AUR packages
AUR_PKGS=(
    whitesur-gtk-theme
    whitesur-icon-theme
    whitesur-cursor-theme
    sddm-sugar-candy-git
)

# Install official packages
sudo pacman -S --needed --noconfirm \
    "${PKGS_HYPRLAND[@]}" \
    "${PKGS_UI[@]}" \
    "${PKGS_APPS[@]}" \
    "${PKGS_SYSTEM[@]}" \
    "${PKGS_DEV[@]}" \
    "${PKGS_SHELL[@]}" \
    "${PKGS_FONTS[@]}" \
    "${PKGS_THEME[@]}"

ok "Official packages installed"

# Install AUR packages
paru -S --needed --noconfirm "${AUR_PKGS[@]}"
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

# Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    chsh -s "$(which zsh)"
    ok "Default shell changed to zsh"
fi

# Deploy zsh config
deploy "$CONFIG_DIR/zsh/.zshrc"        "$HOME/.zshrc"
deploy "$CONFIG_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

ok "Shell configured"

# ── 6. Enable services ────────────────────────────────────────
step "Enabling system services"

sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Enable SDDM
sudo systemctl enable sddm 2>/dev/null || true

ok "Services enabled"

# ── 7. SDDM theme ─────────────────────────────────────────────
step "Configuring SDDM"

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << 'EOF'
[Theme]
Current=sugar-candy
EOF

ok "SDDM configured"

# ── 8. GTK/cursor environment ─────────────────────────────────
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
echo "  1. Reboot your system"
echo "  2. Select Hyprland at the SDDM login screen"
echo "  3. Super+D to open app launcher"
echo "  4. Super+Enter to open terminal"
echo ""
echo "Key bindings are in ~/.config/hypr/hyprland.conf"
echo ""
