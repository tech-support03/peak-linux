#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  peak-linux ISO Builder                                     ║
# ║  Builds a custom Arch Linux ISO with archiso                ║
# ║  Must be run on an existing Arch Linux system as root       ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
die()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROFILE_DIR="$SCRIPT_DIR/profile"
WORK_DIR="/tmp/peak-linux-build"
OUT_DIR="$SCRIPT_DIR/out"

# ── Pre-flight ─────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo ./build.sh)"
command -v mkarchiso &>/dev/null || {
    info "Installing archiso..."
    pacman -S --needed --noconfirm archiso
}

echo -e "${BOLD}"
echo "  ┌──────────────────────────────────────┐"
echo "  │      peak-linux ISO Builder           │"
echo "  │  Custom Arch ISO with Hyprland + macOS│"
echo "  └──────────────────────────────────────┘"
echo -e "${NC}"

# ── Prepare profile ───────────────────────────────────────────
info "Preparing archiso profile..."

# Copy our configs and installer into the live filesystem
AIROOTFS="$PROFILE_DIR/airootfs"

# Copy peak-linux project files into the ISO
mkdir -p "$AIROOTFS/root/peak-linux"
cp -r "$PROJECT_ROOT/configs" "$AIROOTFS/root/peak-linux/"
cp "$PROJECT_ROOT/install.sh" "$AIROOTFS/root/peak-linux/"

# Copy the guided installer
cp "$SCRIPT_DIR/peak-installer.sh" "$AIROOTFS/root/peak-installer.sh"
chmod +x "$AIROOTFS/root/peak-installer.sh"
chmod 400 "$AIROOTFS/etc/shadow"

# Enable services in the live environment via symlinks
mkdir -p "$AIROOTFS/etc/systemd/system/multi-user.target.wants"
mkdir -p "$AIROOTFS/etc/systemd/system/network-online.target.wants"

ln -sf /usr/lib/systemd/system/NetworkManager.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-wait-online.service \
    "$AIROOTFS/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
ln -sf /usr/lib/systemd/system/iwd.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/iwd.service"
ln -sf /usr/lib/systemd/system/sshd.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/sshd.service"
ln -sf /usr/lib/systemd/system/dhcpcd.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/dhcpcd.service"
ln -sf /usr/lib/systemd/system/systemd-resolved.service \
    "$AIROOTFS/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"

ok "Profile prepared"

# ── Clean old build ───────────────────────────────────────────
if [[ -d "$WORK_DIR" ]]; then
    info "Cleaning previous build..."
    rm -rf "$WORK_DIR"
fi
mkdir -p "$OUT_DIR"

# ── Build ISO ─────────────────────────────────────────────────
info "Building ISO (this will take 10-30 minutes)..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

ok "ISO built successfully!"
echo ""
echo -e "  ${GREEN}${BOLD}ISO location:${NC} $OUT_DIR/"
ls -lh "$OUT_DIR"/*.iso 2>/dev/null
echo ""
echo "  Flash to USB with:"
echo "    sudo dd bs=4M if=$OUT_DIR/peak-linux-*.iso of=/dev/sdX status=progress oflag=sync"
echo "  Or use ventoy/balenaEtcher."
echo ""
