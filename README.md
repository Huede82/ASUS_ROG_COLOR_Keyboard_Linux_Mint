# ⚡ ROG RGB — Keyboard Backlight Control for Linux

> Full RGB control for ASUS ROG N-KEY laptop keyboards under Linux Mint / Ubuntu

🌐 **Language / Sprache:** [🇬🇧 English](README.md) · [🇩🇪 Deutsch](README.de.md)

---

| | |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-06-05 |
| **Author** | Martin "Der Lemming" Hütter |
| **Co-Author** | GitHub Copilot (Claude Sonnet 4.6) |
| **Lizenz** | MIT |
| **Platform** | Linux Mint 22.x / Ubuntu 24.04 · Kernel ≥ 5.11 |

---

## Contents

- [Background](#background)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Project Files](#project-files)
- [Usage](#usage)
  - [Graphical GUI](#graphical-gui)
  - [Terminal Control](#terminal-control)
  - [Diagnostic Tool](#diagnostic-tool)
- [Autostart & Suspend/Resume](#autostart--suspendresume)
- [Uninstallation](#uninstallation)
- [Technical Background](#technical-background)
- [Known Quirks](#known-quirks)

---

## Background

ASUS ROG laptops use a proprietary **N-KEY USB HID device** (USB `0b05:1866`) für die RGB-Tastaturbeleuchtung.  
Linux includes a kernel driver (`hid_asus`) that exposes a basic brightness interface at `/sys/class/leds/asus::kbd_backlight/` — but actual **color control** requires direct USB HID control transfers.

Das Tool [rogauracore](https://github.com/wroberts/rogauracore) übernimmt diese Kommunikation.  
Dieses Projekt stellt eine komfortable Steuerungsebene darüber bereit:
eine **grafische GUI**, ein **Terminal-Wrapper** und ein **Diagnose-Tool**.

---

## System Requirements

| Anforderung | Version / Paket |
|---|---|
| Linux Kernel | ≥ 5.11 (full N-KEY support) |
| Distribution | Ubuntu 24.04 / Linux Mint 22.x (apt-basiert) |
| Python | 3.10+ |
| GTK | `python3-gi`, `gir1.2-gtk-3.0`, `python3-gi-cairo` |
| Build Tools | `gcc`, `make`, `autoconf`, `automake`, `libtool` |
| USB | `libusb-1.0-0-dev`, `libhidapi-dev` |

---

## Installation

### Option A: Graphical Installer (recommended)

```bash
cd "ROG Scripts"
python3 install-rog-rgb-gui.py
```

The graphical installer guides you through a 5-page wizard:

| Page | Content |
|---|---|
| Welcome | Overview of the three phases |
| Diagnostics | Animated check of hardware, modules, and tools |
| Plan | What will be installed / skipped / updated |
| Installation | Progress bar + live log + password input |
| Done | Result, button to launch the RGB GUI directly |

### Option B: Terminal Installer

```bash
# Ins Projektverzeichnis wechseln
cd "ROG Scripts"

# Sorglos-Installations-Script ausführen (installiert alles automatisch)
sudo bash install-rog-rgb.sh
```

The script performs these steps automatically:

1. Check system prerequisites (kernel, USB device, apt)
2. Install dependencies (`git`, `gcc`, `libusb`, `python3-gi`, …)
3. Build and install `rogauracore` from source
4. Install `rog-rgb-gui` (GUI) to `/usr/local/bin`
5. Install `rog-rgb` (terminal wrapper) to `/usr/local/bin`
6. Install `rog-kbd-diagnose` to `/usr/local/bin`
7. Set up udev rules for device access without root
8. Add `sudo` permission for sysfs brightness control
9. Set up systemd services for autostart and resume
10. Register `.desktop` entry in the application menu
11. Run a functional test

---

## Project Files

```
ROG Scripts/
├── install-rog-rgb-gui.py  # Graphical installer (python3 install-rog-rgb-gui.py)
├── install-rog-rgb.sh      # Terminal installer (sudo bash install-rog-rgb.sh)
├── rog-rgb-gui.py          # Graphical GTK3 control GUI
├── rog-rgb.sh              # Terminal wrapper (local, before installation)
├── rog-kbd-diagnose.sh     # Diagnostic tool  (local, before installation)
├── README.md               # This file (English)
└── README.de.md            # Deutsche Version
```

After installation, also available system-wide:

```
/usr/local/bin/rogauracore      # Kern-Backend (USB HID)
/usr/local/bin/rog-rgb          # Terminal-Steuerung
/usr/local/bin/rog-rgb-gui      # Grafische GUI
/usr/local/bin/rog-kbd-diagnose # Diagnose-Tool
/lib/udev/rules.d/90-rogauracore.rules
/etc/systemd/system/rog-rgb.service
/etc/systemd/system/rog-rgb-resume.service
/etc/sudoers.d/rog-rgb
~/.local/share/applications/rog-rgb-gui.desktop
~/.config/rog-rgb/              # Configuration directory
    ├── last_color              # Last active rogauracore command
    └── gui_settings.json       # GUI settings (effect, color, brightness, language)
```

---

## Usage

### Graphical GUI

```bash
rog-rgb-gui
```

Or via the application menu: **Settings → ROG RGB Control**.

Language can be switched inside the GUI (DE/EN toggle).

**Funktionen der GUI:**

| Area | Description |
|---|---|
| Color preview | Clickable bar opens GTK color chooser with color wheel and palette |
| Hex input | Direct color code entry (e.g. `ff0000`) |
| Quick colors | 12 preset color buttons |
| Brightness | Slider: Off / 33% / 66% / 100% |
| Effects | Static · Breathe · Rainbow · Color Cycle · Off |
| Speed | Slow / Medium / Fast (for animated effects) |
| Keyboard preview | Live visualization on keyboard silhouette |
| Live mode | Instant transfer on every change (toggleable) |
| Apply | Explicit apply + permanent save |
| Reset | Load saved settings |

---

### Terminal Control

```bash
# Set color (hex)
rog-rgb #ff0000
rog-rgb ff0000

# Named colors
rog-rgb red
rog-rgb green
rog-rgb blue
rog-rgb cyan
rog-rgb yellow
rog-rgb gold
rog-rgb magenta
rog-rgb white

# Effects
rog-rgb breathe ff0000          # Atmen mit Farbe (Geschwindigkeit 2)
rog-rgb breathe 00aaff 3        # Atmen mit Geschwindigkeit 3
rog-rgb rainbow                 # Rainbow (speed 2)
rog-rgb rainbow 1               # Rainbow slow
rog-rgb cycle                   # Automatic color cycle

# Control
rog-rgb off                     # Turn off
rog-rgb status                  # Show status
rog-rgb restore                 # Restore last saved setting
```

---

### Diagnostic Tool

```bash
rog-kbd-diagnose
```

Checks automatically:

1. Kernel version and distro
2. ASUS N-KEY USB device
3. Kernel modules (`hid_asus`, `asus_wmi`, `asus_nb_wmi`)
4. sysfs LED interface (`/sys/class/leds/asus::kbd_backlight`)
5. HID raw interface and access permissions
6. asusctl (if installed)
7. OpenRGB (if installed)
8. Kernel messages (dmesg) for errors
9. udev rules
10. Suspend/resume issues

All found problems are summarized at the end with concrete fix commands.

```bash
# With automatic brightness fix
rog-kbd-diagnose --fix
```

---

## Autostart & Suspend/Resume

The installation sets up two systemd services:

| Service | When active |
|---|---|
| `rog-rgb.service` | On boot — restores last color |
| `rog-rgb-resume.service` | After suspend/hibernate/hybrid-sleep |

The last active setting is saved in `~/.config/rog-rgb/last_color`.
On startup, the service reads this file and restores both brightness and color/effect.

```bash
# Check service status
systemctl status rog-rgb.service
systemctl status rog-rgb-resume.service

# Run manually (for testing)
sudo systemctl start rog-rgb.service
```

---

## Uninstallation

```bash
sudo bash install-rog-rgb.sh --uninstall
```

Removes: rogauracore, rog-rgb, rog-rgb-gui, rog-kbd-diagnose, systemd services, udev rules, sudo rule, .desktop entry.

> **Note:** The configuration in `~/.config/rog-rgb/` is preserved.  
> To remove completely: `rm -rf ~/.config/rog-rgb`

---

## Technical Background

### Why not asusctl?

[asusctl](https://gitlab.com/asus-linux/asusctl) is the official ASUS-Linux tool but only supports Ubuntu LTS with specific PPAs. No compatible PPA is available for Linux Mint 22.3.

### How does rogauracore work?

`rogauracore` communicates directly via **libusb USB control transfer** with the N-KEY device:

```
Host → USB Control-Transfer (bmRequestType=0x21, bRequest=9) → N-KEY HID
       ↳ 17-Byte-Nachricht mit Effekt-/Farbdaten
```

Return code `17` means success (= 17 bytes transferred = `MESSAGE_LENGTH`).

### Brightness quirk

The `rogauracore` access resets the sysfs value `/sys/class/leds/asus::kbd_backlight/brightness` to `0`, because the kernel driver briefly releases the USB interface. The wrapper therefore automatically restores brightness after every HID command.

---

## Known Quirks

| Issue | Explanation | Solution |
|---|---|---|
| Brightness = 0 after rogauracore | Kernel driver side effect | Corrected automatically |
| RGB off after suspend | N-KEY loses USB state | `rog-rgb-resume.service` restores it |
| rogauracore needs sudo | USB device access requires permissions | udev rule + sudoers entry set by installer |
| fan_curve_get_factory_default error | asus_wmi dmesg message, affects fan curves only | Can be ignored |

---

*This project was born from a real problem: the ASUS ROG RGB keyboard stopped working after a fresh Linux Mint installation — and there was no simple, complete tool for diagnosis and repair.*
