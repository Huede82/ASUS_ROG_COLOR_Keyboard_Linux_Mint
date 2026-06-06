# ROG Linux Suite — Project Soul

- **Datum:** 2026-06-06
- **Version:** 2.0 (Suite-Erweiterung)
- **Repo:** `ASUS_ROG_COLOR_Keyboard_Linux_Mint` (Owner: Huede82)
- **Hinweis:** Repo wurde ursprünglich für RGB allein angelegt; Umbenennung später möglich (siehe Plan, Track 2 / v1.0)

---

## Mission

Eine zusammengehörige, deutsch/englisch-sprachige Tool-Sammlung für ASUS ROG Laptops unter **Linux Mint / Ubuntu**, die fehlende oder schlecht integrierte ROG-Funktionalität nachrüstet.

Fokus:
- **Einfach installieren** (ein Script pro Modul, GUI-Installer als Bonus)
- **Transparent diagnostizieren** (jedes Modul hat sein `*-diagnose.sh`)
- **Ohne Zwang zu Armoury-Crate-Äquivalenten** — keine schweren Daemons, keine Cloud, kein Kram

---

## Zielsystem (Referenz-Hardware)

- **Laptop:** ASUS ROG Strix G713QM (Hauptnutzer-Gerät)
- **Distro:** Linux Mint 22.3 (Cinnamon)
- **Kernel:** 6.17+
- **Kompatibilität:** Andere ASUS ROG Modelle mit `asus-nb-wmi` Treiber sollen funktionieren, aber primär für die **G7xx-Serie** getestet und garantiert.

---

## Architektur-Prinzipien

Jedes Modul der Suite besteht aus **vier Bausteinen**:

1. `*-diagnose.sh` — Read-Only-Analyse + optionaler `--fix` Mode
2. `install-*.sh` — Setup (Pakete, sudoers, systemd, Konfig)
3. `*.sh` — Terminal-Wrapper für tägliche Nutzung
4. `*-gui.py` — GTK3-Oberfläche für Endanwender

Weitere Leitplanken:

- **Bilingual** — DE primär, EN via `ROG_LANG=en`
- **Einheitlicher Bash-Stil und Farbschema** — bestehende RGB-Scripte sind Referenz
- **systemd-Integration** für Autostart + Suspend/Resume
- **Konfiguration** unter `~/.config/rog-<modul>/`
- **Niemals gegen den Kernel arbeiten** — wenn `asus-nb-wmi` ein Interface bereitstellt (`platform_profile`, `throttle_thermal_policy`, `hwmon`, …), wird dieses genutzt. **Kein direktes EC-Schreiben.**
- **Hotfixes** für Bestands-Installationen werden im jeweiligen Diagnose-Tool als `--fix` Mode angeboten — nicht als separates Patch-Script.

---

## Module der Suite

### 1. RGB-Modul (v1.0 vorhanden, v1.1 mit sudoers-Hotfix)
- **Backend:** `rogauracore`
- **Komponenten:** `rog-rgb`, `rog-rgb-gui`, `rog-kbd-diagnose`, `install-rog-rgb.sh`, GUI-Installer

### 2. Fan-Modul (in Planung, Ziel v1.0)
- **Backend:** `asusctl` (Stack-Entscheidung getroffen — siehe Logbuch im Plan)
- **Komponenten:** `rog-fan`, `rog-fan-gui`, `rog-fan-diagnose`, `install-rog-fan.sh`

### 3. Tray-Modul (Empfehlung, kein Eigenbau)
- **Lösung:** Cinnamon Spices Applet `Sensors@claudiux`
- Wird im Fan-Installer optional referenziert / per Hinweis-Dialog beworben — **kein Auto-Install**, da Spices manuell aus dem Cinnamon-Store geladen werden.

---

## Tech-Stack

- **Bash 5.x** — alle Scripte und Installer
- **Python 3.10+ mit PyGObject + GTK3** — alle GUIs
- **systemd Unit Files** — Autostart, Suspend/Resume, Profil-Wiederherstellung
- **udev Rules** — Hardware-Zugriff für unprivilegierte User
- **Backends:** `rogauracore` (RGB), `asusctl` (Fan / Platform Profile)

---

## Out-of-Scope (explizit ausgeschlossen)

- **Windows-Support** — nie
- **Wayland-spezifische Features** — Tray-Applet ist X11/Cinnamon, kein Hyprland/GNOME-Wayland-Tweaking
- **Direkte EC-Manipulation** — `nbfc-linux` wurde geprüft und **abgelehnt**, da es mit `asus-nb-wmi` kollidiert
- **Battery-Charge-Threshold** — kann später als optionales 4. Modul kommen, aktuell nicht im Scope
- **GPU-Switching / MUX** — `supergfxctl` existiert als eigenständiges Upstream-Tool, wird nicht nachgebaut

---

## Co-Autoren

- **Martin "Der Lemming" Hütter** — Owner, Hardware-Tester, Endabnehmer
- **GitHub Copilot** — AI-Lead-Mode mit Sub-Agenten (PM, Dev, DevOps, Test)
