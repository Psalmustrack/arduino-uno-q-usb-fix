#!/bin/bash
#
# Arduino UNO Q - USB Host Mode Fix
# Automatic installation script
#
# Usage: curl -sSL https://raw.githubusercontent.com/Psalmustrack/arduino-uno-q-usb-fix/main/install.sh | sudo bash
#

set -e

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  Arduino UNO Q - USB Host Mode Fix                    ║"
echo "║  Automatic installation                               ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: run with sudo${NC}"
    echo "Usage: sudo bash install.sh"
    exit 1
fi

# Check Arduino UNO Q
echo -e "${YELLOW}[1/5] Checking hardware...${NC}"
if [ ! -f "/sys/kernel/debug/usb/4e00000.usb/mode" ]; then
    # Try to mount debugfs
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
    
    if [ ! -f "/sys/kernel/debug/usb/4e00000.usb/mode" ]; then
        echo -e "${RED}Error: this doesn't seem to be an Arduino UNO Q${NC}"
        echo "File not found: /sys/kernel/debug/usb/4e00000.usb/mode"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Arduino UNO Q detected${NC}"

# Create service
echo -e "${YELLOW}[2/5] Creating systemd service...${NC}"
cat > /etc/systemd/system/usb-host-mode.service << 'EOF'
[Unit]
Description=Force USB-C Host Mode on Arduino UNO Q
Documentation=https://github.com/Psalmustrack/arduino-uno-q-usb-fix
After=multi-user.target
Before=docker.service containerd.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 3
ExecStart=/bin/sh -c 'echo host > /sys/kernel/debug/usb/4e00000.usb/mode'
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal
SyslogIdentifier=usb-host-mode

[Install]
WantedBy=multi-user.target
EOF
echo -e "${GREEN}✓ Service created${NC}"

# Reload systemd
echo -e "${YELLOW}[3/5] Configuring systemd...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

# Enable service
echo -e "${YELLOW}[4/5] Enabling service...${NC}"
systemctl enable usb-host-mode.service
echo -e "${GREEN}✓ Service enabled${NC}"

# Immediate test
echo -e "${YELLOW}[5/5] Testing host mode...${NC}"
echo host > /sys/kernel/debug/usb/4e00000.usb/mode
sleep 1

MODE=$(cat /sys/kernel/debug/usb/4e00000.usb/mode)
if [ "$MODE" == "host" ]; then
    echo -e "${GREEN}✓ Host mode activated${NC}"
else
    echo -e "${RED}⚠ Warning: current mode is '$MODE'${NC}"
fi

# Result
echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║  ✅ Installation complete!                            ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot: sudo reboot"
echo "  2. Verify: lsusb"
echo ""
echo "Currently connected USB devices:"
lsusb 2>/dev/null || echo "(none detected)"
echo ""
echo -e "${YELLOW}Tip: reboot to verify it works at boot${NC}"
