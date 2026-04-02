# Auto-start the installer prompt on tty1
if [[ "$(tty)" == "/dev/tty1" ]]; then
    echo ""
    echo "  Type 'peak-installer.sh' to begin installation"
    echo "  Type 'nmtui' first if you need WiFi"
    echo ""
fi
