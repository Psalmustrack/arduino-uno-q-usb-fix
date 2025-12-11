#!/bin/bash
#
# Arduino UNO Q - USB Host Mode Fix
# Uninstallation script
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Arduino UNO Q - USB Host Mode Fix${NC}"
echo "Uninstalling..."
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: run with sudo${NC}"
    exit 1
fi

# Stop service
echo "[1/3] Stopping service..."
systemctl stop usb-host-mode.service 2>/dev/null || true

# Disable service
echo "[2/3] Disabling service..."
systemctl disable usb-host-mode.service 2>/dev/null || true

# Remove file
echo "[3/3] Removing files..."
rm -f /etc/systemd/system/usb-host-mode.service
systemctl daemon-reload

echo ""
echo -e "${GREEN}✅ Uninstallation complete${NC}"
echo ""
echo -e "${YELLOW}Note: USB mode will return to 'device' after next reboot${NC}"
