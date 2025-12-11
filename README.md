# Arduino UNO Q - USB Host Mode Fix (VIN Power)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Arduino UNO Q](https://img.shields.io/badge/Arduino-UNO%20Q-00979D)](https://www.arduino.cc/pro/hardware-arduino-uno-q)

🔧 **Fix to enable USB Host mode when Arduino UNO Q is powered via VIN pins**

## 🐛 The Problem

When the Arduino UNO Q is powered through the **VIN** pins (7-24V) instead of USB-C, the USB-C port **does not work in host mode**. USB devices (Zigbee dongles, keyboards, webcams, etc.) are not recognized.

### Symptoms

```bash
$ lsusb
# No devices shown (only internal hubs)

$ cat /sys/class/typec/port0/data_role
host [device]  # [device] = wrong mode!
```

### Cause

The Qualcomm QRB2210 SoC has a bug in the `dwc3-qcom` driver: without a USB-C cable at boot, the controller starts in **device mode** instead of **host**.

Arduino has declared this scenario "not supported", but a workaround via `debugfs` exists.

## ✅ The Solution

A systemd service that forces host mode at boot by writing to:
```
/sys/kernel/debug/usb/4e00000.usb/mode
```

## 🚀 Quick Installation

### Method 1: Automatic script

```bash
curl -sSL https://raw.githubusercontent.com/Psalmustrack/arduino-uno-q-usb-fix/main/install.sh | sudo bash
```

### Method 2: Manual

```bash
# Clone repository
git clone https://github.com/Psalmustrack/arduino-uno-q-usb-fix.git
cd arduino-uno-q-usb-fix

# Install service
sudo cp systemd/usb-host-mode.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable usb-host-mode.service

# Reboot
sudo reboot
```

## 📋 Verification

After reboot:

```bash
# Check mode
sudo cat /sys/kernel/debug/usb/4e00000.usb/mode
# Expected output: host

# Check USB devices
lsusb
# You should see your devices

# Check service status
sudo systemctl status usb-host-mode.service
```

## 🏠 Use Case: Home Assistant + Zigbee

This fix is ideal for using Arduino UNO Q as a home automation hub.

### Docker Setup

```bash
# Create directory
mkdir -p ~/homeassistant/config
cd ~/homeassistant

# Copy docker-compose
curl -O https://raw.githubusercontent.com/Psalmustrack/arduino-uno-q-usb-fix/main/docker/docker-compose.yml

# Modify your dongle path (optional)
nano docker-compose.yml

# Start
sudo docker compose up -d
```

Access at: `http://<ARDUINO_IP>:8123`

### ZHA Configuration

1. **Settings** → **Devices & services** → **Add integration**
2. Search for **ZHA** (Zigbee Home Automation)
3. Serial port: `/dev/ttyUSB0`
4. Radio type: **ezsp** (for Sonoff Zigbee 3.0 USB Dongle Plus)

### ⚠️ Important: Boot Order

The `usb-host-mode.service` must start **BEFORE** Docker, otherwise the container won't see the device.

The service file is already correctly configured with `Before=docker.service`.

If you have issues, restart the container after boot:
```bash
cd ~/homeassistant && sudo docker compose restart
```

## 📁 Repository Structure

```
arduino-uno-q-usb-fix/
├── README.md                 # This guide
├── LICENSE                   # MIT License
├── install.sh               # Automatic installation script
├── uninstall.sh             # Removal script
├── systemd/
│   └── usb-host-mode.service # Systemd service
├── docker/
│   └── docker-compose.yml    # Home Assistant example
└── docs/
    ├── TROUBLESHOOTING.md   # Problem solving
    ├── TECHNICAL.md         # Technical details
    └── SECURITY.md          # Security considerations
```

## 🔒 Security

| Aspect | Risk | Notes |
|--------|------|-------|
| Root service | Low | Standard for hardware system services |
| debugfs write | Low | Only 1 specific file, already accessible to root |
| USB Host enabled | Medium | Same risk as any PC/Raspberry Pi |

See [docs/SECURITY.md](docs/SECURITY.md) for details.

## 🧪 Tested on

| Component | Version |
|-----------|---------|
| Arduino UNO Q | 2GB RAM / 16GB eMMC |
| OS | Debian Linux 6.16.x (stock) |
| Kernel | 6.16.0-geffa8626771a |
| Home Assistant | 2024.12.x |
| Tested dongle | Sonoff Zigbee 3.0 USB Dongle Plus |

## 🤝 Contributing

1. Fork the repository
2. Create branch (`git checkout -b feature/improvement`)
3. Commit (`git commit -am 'Add improvement'`)
4. Push (`git push origin feature/improvement`)
5. Open Pull Request

## 📜 License

MIT License - see [LICENSE](LICENSE)

## 🙏 Credits

- Fix discovered through dwc3 driver analysis and real hardware testing
- Useful discussions: [Arduino Forum - UNO Q USBC dongle issue](https://forum.arduino.cc/t/uno-q-usbc-dongle-issue/1410296)
- Kernel documentation: [dwc3 debugfs](https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-driver-dwc3)

## 📞 Support

- 🐛 **Bug?** Open an [Issue](https://github.com/Psalmustrack/arduino-uno-q-usb-fix/issues)
- 💬 **Questions?** Use [Discussions](https://github.com/Psalmustrack/arduino-uno-q-usb-fix/discussions)
- 📧 **Contact:** [Arduino Forum](https://forum.arduino.cc/)

---

⭐ **If this fix helped you, leave a star!** ⭐
