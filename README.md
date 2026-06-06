<div align="center">

# 🎮 ROG Linux Suite

### Fan control & RGB keyboard for ASUS ROG laptops on Linux Mint

**Because the Armoury Crate equivalent simply doesn't exist on Linux.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnubash&logoColor=white)]()
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)]()
[![GTK](https://img.shields.io/badge/GTK-3-7C9CCC?logo=gtk&logoColor=white)]()
[![Linux Mint](https://img.shields.io/badge/Linux_Mint-22.x-87CF3E?logo=linuxmint&logoColor=white)]()

🇬🇧 English · [🇩🇪 Deutsch](README.de.md)

</div>

---

## 👤 Is this for you?

✅ You have an **ASUS ROG Strix G713QM** (or similar Ryzen + asus-wmi based ROG laptop)
✅ You run **Linux Mint 22.x** or another Ubuntu 24.04-based distro (`noble`)
✅ Your **fans never spin** at full load · your **RGB keyboard is stuck**
✅ You want a **one-command install** that actually works · with a **GUI installer too**

> The reference machine is a Strix G713QM, but most ROG laptops supported by [asusctl](https://gitlab.com/asus-linux/asusctl) should work. PRs welcome for other models.

---

## ✨ What you get

<table>
<tr>
<td width="50%" valign="top">

### 🌬 Fan / Thermal Control
- Three profiles: **Quiet · Balanced · Performance**
- **Fan-Key support** with 2s OSD overlay
- Live RPM + CPU temp + AC/Battery in GUI
- Suspend/Resume + Boot profile restore
- Custom fan curves (CPU / GPU / Mid)

</td>
<td width="50%" valign="top">

### 🎨 RGB Keyboard Control
- Static colors, breathe, rainbow, cycle
- Color picker GUI with live preview
- Suspend/Resume color restore
- Direct USB HID via rogauracore (no daemon)
- Hex / named colors / brightness levels

</td>
</tr>
<tr>
<td valign="top">

### 🧪 Diagnostics included
- `rog-fan-diagnose` — 10-section troubleshooter with `--fix`
- `rog-kbd-diagnose` — RGB-side equivalent
- `rog-fan-audit` — read-only hardware probe

</td>
<td valign="top">

### 🌍 Bilingual everywhere
All tools and installers speak **English** and **German**:
```bash
ROG_LANG=en rog-fan status
ROG_LANG=de rog-fan status
```

</td>
</tr>
</table>

---

## 🚀 Quick Install

```bash
git clone https://github.com/Huede82/ASUS_ROG_COLOR_Keyboard_Linux_Mint.git
cd ASUS_ROG_COLOR_Keyboard_Linux_Mint

# Fan control + asusctl + Hotkey-Daemon + GUI:
sudo bash install-rog-fan.sh

# RGB keyboard (separate module):
sudo bash install-rog-rgb.sh
```

After install: **log out once and back in** (for the `input` group to activate, needed by the Fan-Key daemon).

### Prefer a GUI?
```bash
python3 install-rog-fan-gui.py
python3 install-rog-rgb-gui.py
```
Both installers run via `pkexec`, show live progress and the full log.

---

## 🖥 Usage

### Terminal
| Command | What it does |
|---|---|
| `rog-fan status` | profile + temps + RPMs + AC/Battery |
| `rog-fan quiet \| balanced \| performance` | switch profile |
| `rog-fan watch` | live view |
| `rog-fan-diagnose` | full troubleshooter |
| `rog-rgb red \| 00ff00 \| breathe red` | set keyboard color/effect |
| `rog-rgb status` | current state |

### GUI
| App | Launch |
|---|---|
| ROG Fan Control | menu → **ROG Fan Control** · or `rog-fan-gui` |
| ROG RGB Control | menu → **ROG RGB** · or `rog-rgb-gui` |

### Fan key
Press the **ROG Fan key** to rotate Quiet → Balanced → Performance. A 2-second OSD pops up. Profile is persisted across reboot and suspend.

---

## 💡 Why this exists

On Windows, **Armoury Crate** handles fan profiles and RGB out of the box. On Linux there's [asusctl](https://gitlab.com/asus-linux/asusctl) (excellent backend) and [rogauracore](https://github.com/wroberts/rogauracore) (RGB driver) — but no integrated, no-fuss user experience for distros like Linux Mint, especially since the official `asus-linux` PPA stopped supporting Ubuntu 24.04 (`noble`).

This suite fills that gap: **install once, everything just works** — Fan-Key included, OSD included, GUI included, Boot/Resume restore included.

---

## 🛠 Architecture

```
┌─────────────────────────────────────────────────────────┐
│  User-facing tools                                      │
│    rog-fan (CLI)    rog-fan-gui (GTK)                   │
│    rog-rgb (CLI)    rog-rgb-gui (GTK)                   │
│    rog-fan-keyd (Fan key → OSD)                         │
├─────────────────────────────────────────────────────────┤
│  Installers & diagnostics                               │
│    install-rog-fan(.sh|-gui.py)                         │
│    install-rog-rgb(.sh|-gui.py)                         │
│    rog-fan-diagnose · rog-kbd-diagnose · rog-fan-audit  │
├─────────────────────────────────────────────────────────┤
│  Backends                                               │
│    asusctl v6.3.8 (source-built) — DBus xyz.ljones.Asusd│
│    rogauracore — direct USB HID                         │
├─────────────────────────────────────────────────────────┤
│  Kernel                                                 │
│    asus-nb-wmi · platform_profile · hwmon               │
└─────────────────────────────────────────────────────────┘
```

systemd services installed:
- `asusd.service` (system) — asusctl daemon
- `rog-fan-boot.service` (system) — profile restore at boot
- `rog-fan-resume.service` (system) — profile restore after suspend
- `rog-fan-keyd.service` (user) — Fan-Key listener
- `rog-rgb-resume.service` (system) — keyboard color restore

---

## 🧰 Compatibility

| | Tested |
|---|---|
| Laptop | ASUS ROG Strix G713QM (Ryzen 9 5900HX + Vega iGPU + RTX 3060 Mobile) |
| OS | Linux Mint 22.3 Cinnamon (Ubuntu 24.04 `noble`) |
| Kernel | 6.17 (works from 5.15+) |
| Keyboard USB-ID | `0b05:1866` (N-KEY internal keyboard) |
| Fan key | `KEY_PROG4` (code 203) |

**Should also work on:** other ROG laptops supported by asusctl (Strix G15/G17, Zephyrus G14/G15, TUF series with platform_profile). Untested — feedback welcome.

**Required kernel modules:** `asus-nb-wmi`, `asus_wmi`
**Required sysfs:** `/sys/firmware/acpi/platform_profile`, `/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy`

---

## 🗑 Uninstall

```bash
sudo bash install-rog-fan.sh --uninstall
sudo bash install-rog-rgb.sh --uninstall
```

Restores `power-profiles-daemon`, removes binaries, services, sudoers rules, desktop entries. User config in `~/.config/rog-fan/` and `~/.config/rog-rgb/` is kept by default.

## 🔧 Troubleshooting

Run the diagnostics first — they usually find the problem:

```bash
bash rog-fan-diagnose.sh         # full report
bash rog-fan-diagnose.sh --fix   # apply safe fixes
bash rog-kbd-diagnose.sh         # RGB side
```

Common ones:

| Symptom | Fix |
|---|---|
| Fan key does nothing | Re-login needed — `groups \| grep input` should show `input` |
| Fan key still dead after GUI install | Fixed in current build (see Changelog). On older installs: `systemctl --user enable --now rog-fan-keyd.service` |
| OSD invisible | Needs a compositor (Cinnamon/GNOME OK) |
| Profile reverts after suspend | check `systemctl status rog-fan-resume.service` |
| asusd won't start (203/EXEC) | symlinks: `sudo ln -sf /usr/local/bin/asusd /usr/bin/asusd` |

### Changelog

**2026-06-06 — Fixed**
- `rog-fan-keyd.service` was not auto-activated when installing via the GUI (`pkexec`). A new `user_systemctl()` helper in `install-rog-fan.sh` now reliably sets `DBUS_SESSION_BUS_ADDRESS` and `XDG_RUNTIME_DIR`, starts `user@UID.service` on demand, and surfaces real errors instead of swallowing them with `2>/dev/null`.

---

## 📊 Tray indicator (optional)

For a live fan-RPM + CPU-temp indicator in your panel, we recommend the community Cinnamon applet **[Sensors@claudiux](https://cinnamon-spices.linuxmint.com/applets/view/337)**:
> Right-click panel → Applets → Download → search "Sensors" → install `Sensors@claudiux`

---

## 🤝 Contributing

Issues, bug reports and PRs welcome. If you tested this on a different ROG model — please [open an issue](https://github.com/Huede82/ASUS_ROG_COLOR_Keyboard_Linux_Mint/issues) with `lsb_release -a`, `uname -r` and your laptop model.

---

## 📜 Credits

| Project | Used for |
|---|---|
| [asusctl](https://gitlab.com/asus-linux/asusctl) | Fan/thermal backend (DBus daemon) |
| [rogauracore](https://github.com/wroberts/rogauracore) | RGB keyboard USB driver |
| [Sensors@claudiux](https://cinnamon-spices.linuxmint.com/applets/view/337) | Recommended tray applet |

License: [MIT](LICENSE) · Built by [Huede82](https://github.com/Huede82) with help from GitHub Copilot · 2026

---

<div align="center">
<sub>If this saved you hours of distro-hopping — a ⭐ on the repo is the best thanks.</sub>
</div>
