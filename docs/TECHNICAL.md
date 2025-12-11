# Technical Documentation

## Arduino UNO Q USB Architecture

### Hardware

The Arduino UNO Q uses the **Qualcomm QRB2210** SoC (Dragonwing), based on the QCM2290 platform. The USB subsystem consists of:

```
┌─────────────────────────────────────────────────────────────┐
│                    Arduino UNO Q                            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │   PM4125     │    │   DWC3       │    │   USB PHY    │  │
│  │   PMIC       │◄──►│   Controller │◄──►│   (HS+SS)    │  │
│  │   Type-C     │    │   dwc3-qcom  │    │              │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         │                   │                    │          │
│         │                   │                    │          │
│         ▼                   ▼                    ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    USB-C Port                        │   │
│  │              (DRP - Dual Role Port)                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role | Linux Driver |
|-----------|------|--------------|
| DWC3 | USB 3.0 SuperSpeed Controller | `dwc3`, `dwc3-qcom` |
| PM4125 | PMIC with Type-C controller | `ucsi`, `qcom-pmic-glink` |
| USB PHY | High Speed + SuperSpeed PHY | `phy-qcom-qmp-usbc` |
| ANX7625 | HDMI/DP Bridge | `anx7625` |

---

## The Problem: DRP Initialization

### Normal Flow (USB-C connected at boot)

```
Boot → PM4125 detects CC lines → UCSI notifies role → DWC3 configures → Host/Device mode
```

### Problematic Flow (VIN power, no USB-C)

```
Boot → PM4125 detects nothing on CC → UCSI sends no notification → DWC3 stays in device mode
```

### Why It Happens

1. **The UNO Q USB-C port is DRP** (Dual Role Port)
2. The role (host/device) is determined by Type-C negotiation on **CC1/CC2** pins
3. Without a USB-C cable connected, there's no negotiation
4. The `dwc3-qcom` driver defaults to **device mode**
5. The sysfs file `/sys/class/typec/port0/data_role` is **read-only** on this platform

---

## The Solution: debugfs

### Why It Works

The DWC3 driver exposes a debug interface at `/sys/kernel/debug/usb/<device>/mode` that allows forcing the mode:

```c
// drivers/usb/dwc3/debugfs.c
static ssize_t dwc3_mode_write(struct file *file, const char __user *ubuf,
                               size_t count, loff_t *ppos)
{
    // Accepts: "host", "device", "otg"
    if (!strncmp(buf, "host", 4))
        dwc3_set_mode(dwc, DWC3_GCTL_PRTCAP_HOST);
    // ...
}
```

### Difference Between sysfs and debugfs

| Interface | Path | Writable | Reason |
|-----------|------|----------|--------|
| sysfs (typec) | `/sys/class/typec/port0/data_role` | ❌ No | UCSI driver doesn't support role swap |
| sysfs (usb_role) | `/sys/class/usb_role/*/role` | ❌ No | File doesn't exist on this board |
| **debugfs** | `/sys/kernel/debug/usb/4e00000.usb/mode` | ✅ Yes | DWC3 debug interface |

---

## Device Tree

### Current Configuration (from `/sys/firmware/devicetree/`)

```
/sys/firmware/devicetree/base/soc@0/usb@4ef8800/usb@4e00000/
├── dr_mode = "otg"
├── usb-role-switch
└── ...
```

### Ideal Configuration (if modifiable)

```dts
&usb {
    dr_mode = "otg";
    usb-role-switch;
    role-switch-default-mode = "host";  // <-- This would fix the problem
};
```

Or alternatively, to force host mode always:

```dts
&usb_dwc3 {
    dr_mode = "host";  // Disables device mode completely
};
```

**Note:** Modifying the device tree requires recompiling the kernel or using an overlay, which are not simple operations on the UNO Q.

---

## Explored Alternatives (non-working)

### 1. Writing to sysfs typec

```bash
echo host > /sys/class/typec/port0/data_role
# Error: Read-only file system
```

**Reason:** The UCSI driver doesn't implement `dr_set` for this platform.

### 2. extcon module

```bash
echo 1 > /sys/class/extcon/*/state
# Not applicable: extcon not used on this board
```

### 3. Kernel parameter dwc3.dr_mode

```bash
# In cmdline: dwc3.dr_mode=host
```

**Reason:** This parameter doesn't exist; `dr_mode` comes from the device tree.

---

## Relevant Kernel Paths

```bash
# Debugfs (our solution)
/sys/kernel/debug/usb/4e00000.usb/mode

# Type-C class (read-only)
/sys/class/typec/port0/data_role
/sys/class/typec/port0/power_role
/sys/class/typec/port0/preferred_role

# USB Role Switch (empty/non-functional)
/sys/class/usb_role/4e00000.usb-role-switch/

# Device Tree (informational)
/sys/firmware/devicetree/base/soc@0/usb@4ef8800/usb@4e00000/dr_mode
```

---

## References

- [Kernel DWC3 Driver](https://github.com/torvalds/linux/tree/master/drivers/usb/dwc3)
- [Qualcomm USB Documentation](https://docs.qualcomm.com/bundle/publicresource/topics/80-70014-8/usb.html)
- [USB Type-C Connector Class](https://www.kernel.org/doc/html/latest/driver-api/usb/typec.html)
- [Arduino linux-qcom fork](https://github.com/arduino/linux-qcom)
- [QRB2210-RB1 Device Tree](https://github.com/torvalds/linux/blob/master/arch/arm64/boot/dts/qcom/qrb2210-rb1.dts)
