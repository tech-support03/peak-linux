# Ensure /root is in PATH so peak-installer.sh works as a bare command
export PATH="/root:$PATH"

# Auto-start the installer prompt on tty1
if [[ "$(tty)" == "/dev/tty1" ]]; then
    echo ""

    # Wait briefly for NetworkManager to establish a connection
    echo "  Checking network connectivity..."
    for i in 1 2 3 4 5; do
        if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
            echo "  ✓ Network is connected"
            break
        fi
        if [[ $i -eq 5 ]]; then
            echo "  ✗ Network not available — trying to restart networking..."
            systemctl restart NetworkManager 2>/dev/null
            # Also try dhcpcd as fallback on any wired interface
            for iface in /sys/class/net/e*; do
                iface="$(basename "$iface")"
                dhcpcd "$iface" 2>/dev/null &
            done
            sleep 3
            if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
                echo "  ✓ Network recovered"
            else
                echo "  ✗ Still no network. Try manually:"
                echo "      nmtui          — connect to WiFi"
                echo "      dhcpcd enp0s3  — wired DHCP (replace interface name)"
                echo "      ip link        — list interfaces"
            fi
        fi
        sleep 2
    done

    echo ""
    echo "  Type 'peak-installer.sh' to begin installation"
    echo ""
fi
