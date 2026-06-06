<div align="center">

# 🎮 ROG Linux Suite

### Lüftersteuerung & RGB-Tastatur für ASUS ROG Laptops unter Linux Mint

**Weil es kein Armoury-Crate-Pendant für Linux gibt.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.x-4EAA25?logo=gnubash&logoColor=white)]()
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)]()
[![GTK](https://img.shields.io/badge/GTK-3-7C9CCC?logo=gtk&logoColor=white)]()
[![Linux Mint](https://img.shields.io/badge/Linux_Mint-22.x-87CF3E?logo=linuxmint&logoColor=white)]()

🇩🇪 Deutsch · [🇬🇧 English](README.md)

</div>

---

## 👤 Ist das was für dich?

✅ Du hast einen **ASUS ROG Strix G713QM** (oder ein ähnliches ROG-Notebook auf Ryzen + asus-wmi Basis)
✅ Du nutzt **Linux Mint 22.x** oder eine andere Ubuntu-24.04-basierte Distro (`noble`)
✅ Deine **Lüfter drehen nie hoch** unter Volllast · deine **RGB-Tastatur hängt fest**
✅ Du willst eine **Ein-Befehl-Installation**, die wirklich funktioniert · mit **GUI-Installer dazu**

> Referenzgerät ist ein Strix G713QM, aber die meisten ROG-Laptops, die von [asusctl](https://gitlab.com/asus-linux/asusctl) unterstützt werden, sollten laufen. PRs für andere Modelle willkommen.

---

## ✨ Was du bekommst

<table>
<tr>
<td width="50%" valign="top">

### 🌬 Lüfter- / Thermalsteuerung
- Drei Profile: **Quiet · Balanced · Performance**
- **Fan-Key-Unterstützung** mit 2s-OSD-Overlay
- Live-RPM + CPU-Temp + AC/Akku in der GUI
- Wiederherstellung nach Suspend/Resume + Boot
- Eigene Lüfterkurven (CPU / GPU / Mid)

</td>
<td width="50%" valign="top">

### 🎨 RGB-Tastatursteuerung
- Statische Farben, Atmen, Regenbogen, Zyklus
- Farbwähler-GUI mit Live-Vorschau
- Farb-Wiederherstellung nach Suspend/Resume
- Direkter USB-HID-Zugriff via rogauracore (kein Daemon)
- Hex- / Named Colors / Helligkeitsstufen

</td>
</tr>
<tr>
<td valign="top">

### 🧪 Diagnose inklusive
- `rog-fan-diagnose` — 10-Sektionen-Troubleshooter mit `--fix`
- `rog-kbd-diagnose` — Pendant für die RGB-Seite
- `rog-fan-audit` — schreibgeschützte Hardware-Prüfung

</td>
<td valign="top">

### 🌍 Überall zweisprachig
Alle Tools und Installer sprechen **Englisch** und **Deutsch**:
```bash
ROG_LANG=en rog-fan status
ROG_LANG=de rog-fan status
```

</td>
</tr>
</table>

---

## 🚀 Schnellinstallation

```bash
git clone https://github.com/Huede82/ASUS_ROG_COLOR_Keyboard_Linux_Mint.git
cd ASUS_ROG_COLOR_Keyboard_Linux_Mint

# Lüftersteuerung + asusctl + Hotkey-Daemon + GUI:
sudo bash install-rog-fan.sh

# RGB-Tastatur (separates Modul):
sudo bash install-rog-rgb.sh
```

Nach der Installation: **einmal aus- und wieder einloggen** (damit die `input`-Gruppe aktiv wird, vom Fan-Key-Daemon benötigt).

### Lieber eine GUI?
```bash
python3 install-rog-fan-gui.py
python3 install-rog-rgb-gui.py
```
Beide Installer laufen über `pkexec`, zeigen Live-Fortschritt und das komplette Log.

---

## 🖥 Nutzung

### Terminal
| Befehl | Was er tut |
|---|---|
| `rog-fan status` | Profil + Temperaturen + RPMs + AC/Akku |
| `rog-fan quiet \| balanced \| performance` | Profil wechseln |
| `rog-fan watch` | Live-Ansicht |
| `rog-fan-diagnose` | Vollständiger Troubleshooter |
| `rog-rgb red \| 00ff00 \| breathe red` | Tastaturfarbe/-effekt setzen |
| `rog-rgb status` | Aktueller Zustand |

### GUI
| App | Start |
|---|---|
| ROG Fan Control | Menü → **ROG Fan Control** · oder `rog-fan-gui` |
| ROG RGB Control | Menü → **ROG RGB** · oder `rog-rgb-gui` |

### Fan-Key
Drücke den **ROG Fan-Key**, um zwischen Quiet → Balanced → Performance zu rotieren. Ein 2-Sekunden-OSD erscheint. Das Profil bleibt über Reboot und Suspend hinweg erhalten.

---

## 💡 Warum es das gibt

Unter Windows erledigt **Armoury Crate** Lüfterprofile und RGB out of the box. Unter Linux gibt es [asusctl](https://gitlab.com/asus-linux/asusctl) (exzellentes Backend) und [rogauracore](https://github.com/wroberts/rogauracore) (RGB-Treiber) — aber keine integrierte, sorglose Nutzererfahrung für Distributionen wie Linux Mint, besonders seit das offizielle `asus-linux`-PPA Ubuntu 24.04 (`noble`) nicht mehr unterstützt.

Diese Suite schließt die Lücke: **einmal installieren, alles läuft** — Fan-Key inklusive, OSD inklusive, GUI inklusive, Boot/Resume-Wiederherstellung inklusive.

---

## 🛠 Architektur

```
┌─────────────────────────────────────────────────────────┐
│  Nutzer-Tools                                           │
│    rog-fan (CLI)    rog-fan-gui (GTK)                   │
│    rog-rgb (CLI)    rog-rgb-gui (GTK)                   │
│    rog-fan-keyd (Fan-Key → OSD)                         │
├─────────────────────────────────────────────────────────┤
│  Installer & Diagnose                                   │
│    install-rog-fan(.sh|-gui.py)                         │
│    install-rog-rgb(.sh|-gui.py)                         │
│    rog-fan-diagnose · rog-kbd-diagnose · rog-fan-audit  │
├─────────────────────────────────────────────────────────┤
│  Backends                                               │
│    asusctl v6.3.8 (aus Quellcode) — DBus xyz.ljones.Asusd│
│    rogauracore — direkter USB-HID-Zugriff               │
├─────────────────────────────────────────────────────────┤
│  Kernel                                                 │
│    asus-nb-wmi · platform_profile · hwmon               │
└─────────────────────────────────────────────────────────┘
```

Installierte systemd-Services:
- `asusd.service` (System) — asusctl-Daemon
- `rog-fan-boot.service` (System) — Profil-Wiederherstellung beim Boot
- `rog-fan-resume.service` (System) — Profil-Wiederherstellung nach Suspend
- `rog-fan-keyd.service` (User) — Fan-Key-Listener
- `rog-rgb-resume.service` (System) — Wiederherstellung der Tastaturfarbe

---

## 🧰 Kompatibilität

| | Getestet |
|---|---|
| Laptop | ASUS ROG Strix G713QM (Ryzen 9 5900HX + Vega iGPU + RTX 3060 Mobile) |
| OS | Linux Mint 22.3 Cinnamon (Ubuntu 24.04 `noble`) |
| Kernel | 6.17 (funktioniert ab 5.15+) |
| Tastatur-USB-ID | `0b05:1866` (interne N-KEY-Tastatur) |
| Fan-Key | `KEY_PROG4` (Code 203) |

**Sollte ebenfalls funktionieren auf:** anderen ROG-Laptops, die von asusctl unterstützt werden (Strix G15/G17, Zephyrus G14/G15, TUF-Serie mit platform_profile). Ungetestet — Rückmeldungen willkommen.

**Benötigte Kernel-Module:** `asus-nb-wmi`, `asus_wmi`
**Benötigte sysfs:** `/sys/firmware/acpi/platform_profile`, `/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy`

---

## 🗑 Deinstallation

```bash
sudo bash install-rog-fan.sh --uninstall
sudo bash install-rog-rgb.sh --uninstall
```

Stellt `power-profiles-daemon` wieder her, entfernt Binaries, Services, sudoers-Regeln, Desktop-Einträge. Nutzerkonfiguration in `~/.config/rog-fan/` und `~/.config/rog-rgb/` bleibt standardmäßig erhalten.

## 🔧 Fehlerbehebung

Starte zuerst die Diagnose-Tools — sie finden das Problem meistens selbst:

```bash
bash rog-fan-diagnose.sh         # Vollbericht
bash rog-fan-diagnose.sh --fix   # sichere Fixes anwenden
bash rog-kbd-diagnose.sh         # RGB-Seite
```

Häufige Fälle:

| Symptom | Fix |
|---|---|
| Fan-Key tut nichts | Neu einloggen — `groups \| grep input` sollte `input` zeigen |
| OSD nicht sichtbar | Compositor nötig (Cinnamon/GNOME ok) |
| Profil setzt sich nach Suspend zurück | `systemctl status rog-fan-resume.service` prüfen |
| asusd startet nicht (203/EXEC) | Symlinks: `sudo ln -sf /usr/local/bin/asusd /usr/bin/asusd` |

---

## 📊 Tray-Indikator (optional)

Für eine Live-Anzeige von Lüfter-RPM und CPU-Temp im Panel empfehlen wir das Community-Cinnamon-Applet **[Sensors@claudiux](https://cinnamon-spices.linuxmint.com/applets/view/337)**:
> Rechtsklick auf das Panel → Applets → Herunterladen → "Sensors" suchen → `Sensors@claudiux` installieren

---

## 🤝 Mitwirken

Issues, Fehlerberichte und PRs willkommen. Wenn du das Projekt auf einem anderen ROG-Modell getestet hast — bitte [öffne ein Issue](https://github.com/Huede82/ASUS_ROG_COLOR_Keyboard_Linux_Mint/issues) mit `lsb_release -a`, `uname -r` und deinem Laptop-Modell.

---

## 📜 Credits

| Projekt | Verwendet für |
|---|---|
| [asusctl](https://gitlab.com/asus-linux/asusctl) | Lüfter-/Thermal-Backend (DBus-Daemon) |
| [rogauracore](https://github.com/wroberts/rogauracore) | RGB-Tastatur-USB-Treiber |
| [Sensors@claudiux](https://cinnamon-spices.linuxmint.com/applets/view/337) | Empfohlenes Tray-Applet |

Lizenz: [MIT](LICENSE) · Gebaut von [Huede82](https://github.com/Huede82) mit Unterstützung von GitHub Copilot · 2026

---

<div align="center">
<sub>Wenn dir das Stunden Distro-Hopping erspart hat — ein ⭐ auf dem Repo ist der beste Dank.</sub>
</div>
