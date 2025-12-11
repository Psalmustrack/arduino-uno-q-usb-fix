# Troubleshooting

## Common Problems and Solutions

### 1. Service doesn't start

**Symptom:**
```bash
$ sudo systemctl status usb-host-mode.service
● usb-host-mode.service - Force USB-C Host Mode
   Active: failed
```

**Solutions:**

```bash
# Check detailed log
sudo journalctl -u usb-host-mode.service -b

# Verify debugfs is mounted
ls /sys/kernel/debug/usb/

# If empty, mount manually
sudo mount -t debugfs none /sys/kernel/debug

# Verify file exists
ls -la /sys/kernel/debug/usb/4e00000.usb/mode
```

---

### 2. lsusb doesn't show devices after the fix

**Symptom:**
```bash
$ lsusb
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
# No other devices
```

**Checks:**

```bash
# Check current mode
sudo cat /sys/kernel/debug/usb/4e00000.usb/mode
# Should say "host"

# If it says "device", force manually
sudo sh -c 'echo host > /sys/kernel/debug/usb/4e00000.usb/mode'

# Check dmesg for USB errors
dmesg | grep -i usb | tail -20

# Try another USB device to rule out hardware
```

---

### 3. Docker doesn't see /dev/ttyUSB0

**Symptom:**
```
[Errno 2] No such file or directory: '/dev/ttyUSB0'
```

**Possible causes:**

1. **Wrong boot order** - Docker starts before USB service

```bash
# Restart container
cd ~/homeassistant
sudo docker compose restart

# Verify device exists on host
ls -la /dev/ttyUSB0
```

2. **devices not configured in docker-compose.yml**

```yaml
# Should be like this (NOT commented):
devices:
  - /dev/ttyUSB0:/dev/ttyUSB0
```

3. **Permissions**

```bash
# Add user to dialout group
sudo usermod -aG dialout $USER
# Then logout/login
```

---

### 4. Fix works but doesn't survive reboot

**Checks:**

```bash
# Is the service enabled?
systemctl is-enabled usb-host-mode.service
# Should say "enabled"

# If it says "disabled":
sudo systemctl enable usb-host-mode.service
```

---

### 5. Permission denied on debugfs

**Symptom:**
```bash
$ echo host > /sys/kernel/debug/usb/4e00000.usb/mode
bash: /sys/kernel/debug/usb/4e00000.usb/mode: Permission denied
```

**Solution:**
```bash
# Use sudo with sh -c
sudo sh -c 'echo host > /sys/kernel/debug/usb/4e00000.usb/mode'
```

---

### 6. Home Assistant ZHA can't find the coordinator

**Checks in order:**

```bash
# 1. Device exists?
ls -la /dev/ttyUSB0

# 2. Persistent path (more reliable)
ls -la /dev/serial/by-id/

# 3. Docker sees the device?
sudo docker exec -it home-assistant ls -la /dev/ttyUSB0

# 4. Permissions in container
sudo docker exec -it home-assistant stat /dev/ttyUSB0
```

**Recommended ZHA configuration:**
- Port: `/dev/ttyUSB0`
- Radio type: `ezsp` (for Sonoff) or `znp` (for CC2652)
- Baudrate: leave default

---

### 7. Dongle blinks but isn't recognized

```bash
# Check kernel log in real time
dmesg -w

# Unplug and replug the dongle, observe messages

# If you see cp210x errors, driver might be missing
lsmod | grep cp210x

# If not loaded:
sudo modprobe cp210x
```

---

## Useful Diagnostic Commands

```bash
# Full USB status
lsusb -v 2>/dev/null | head -50

# Serial devices
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# Type-C status
cat /sys/class/typec/port0/data_role
cat /sys/class/typec/port0/power_role

# USB kernel log
dmesg | grep -iE "usb|dwc3|typec" | tail -30

# Full service status
systemctl status usb-host-mode.service
journalctl -u usb-host-mode.service --no-pager

# Docker status
sudo docker ps
sudo docker logs home-assistant --tail 50
```

---

## Still Having Problems?

1. Open a [GitHub Issue](https://github.com/Psalmustrack/arduino-uno-q-usb-fix/issues) with:
   - Output of `uname -a`
   - Output of `dmesg | grep -i usb`
   - Output of `sudo systemctl status usb-host-mode.service`

2. Ask on the [Arduino Forum](https://forum.arduino.cc/c/hardware/uno-q/)
