# ROG Linux Suite — Project Plan

- **Letztes Update:** 2026-06-06 (v1.0 ROG Linux Suite Release)
- **Konvention:** `[x]` erledigt · `[ ]` offen · `[~]` in Arbeit

---

## Track 1: RGB-Modul (v1.x)

### v1.0 — Initial Release (ERLEDIGT)

- [x] rogauracore-Build-Integration
- [x] `rog-rgb` Terminal-Wrapper
- [x] `rog-rgb-gui` (GTK3)
- [x] `rog-kbd-diagnose`
- [x] `install-rog-rgb.sh` + GUI-Installer (`install-rog-rgb-gui.py`)
- [x] systemd Boot + Resume Services
- [x] Bilingual DE/EN (`ROG_LANG=en`)
- [x] `README.md` + `README.de.md`

### v1.1 — Hotfix sudoers-Bug (IN ARBEIT)

- [x] Bug identifiziert: `::` in sudoers nicht escaped (führt zu Syntaxfehler bei sudo-Aufrufen über `asus::kbd_backlight`-Pfade)
- [x] Installer-Fix in `install-rog-rgb.sh` Zeile 350 (`asus\:\:kbd_backlight`)
- [ ] `rog-kbd-diagnose --fix` erweitern: erkennt fehlerhafte sudoers-Datei via `visudo -c` und repariert sie automatisch
- [ ] Hinweis in README für Bestandsinstallationen (1-Zeilen `sed`-Befehl als Quick-Fix dokumentieren)

---

## Track 2: Fan-Modul (v0.x → v1.0)

### v0.1 — Hardware-Audit & Stack-Entscheidung (ERLEDIGT)

- [x] `rog-fan-audit.sh` (Read-Only Hardware-Detection) implementiert
- [x] Audit auf Referenz-Hardware ausgeführt (G713QM, Kernel 6.17, Mint 22.3)
- [x] Befund:
  - `throttle_thermal_policy` verfügbar
  - `platform_profile` verfügbar
  - `fan_curve_get_factory_default = -19` (bekannter Quirk, asusctl-bekannt, kein Blocker)
- [x] **Stack-Entscheidung: `asusctl`** (nicht `nbfc-linux`, nicht `fancontrol`)
- [x] Sofort-Workaround dokumentiert:
  ```
  echo performance | sudo tee /sys/firmware/acpi/platform_profile
  ```

### v0.2 — Diagnose-Tool (ERLEDIGT)

- [x] `rog-fan-diagnose.sh` analog zu `rog-kbd-diagnose.sh`
- [x] 10 Diagnose-Sektionen:
  1. Kernel-Module (`asus-nb-wmi`, `asus-wmi`)
  2. `asusctl`-Status (Version, `asusd` läuft?)
  3. `platform_profile` (aktuell + verfügbar)
  4. `throttle_thermal_policy` (aktuell + verfügbar)
  5. `hwmon` (Sensoren, Fan-RPMs)
  6. Fan curves (`asusctl fan-curve --get`)
  7. `asusd`-Service (systemd-Status, Logs)
  8. `dmesg`-Quirks (bekannte Fehlermuster, z.B. `-19`)
  9. systemd Wiederherstellungs-Service (existiert / aktiv?)
  10. Reparatur-Vorschläge (Klartext-Befehlsliste)
- [x] `--fix` Mode:
  - setzt `platform_profile` auf `balanced`
  - korrigiert sudoers (falls Schreibrechte-Eintrag kaputt)
  - restartet `asusd`

### v0.3 — Installer (ERLEDIGT)

- [x] Hotfix: Resume-Bug — Service der nach jedem Resume das letzte platform_profile aus ~/.config/rog-fan/last_profile wiederherstellt
- [x] `install-rog-fan.sh` analog zu RGB-Installer
- [x] PPA `ppa:asus-linux/stable` einbinden
  - Fallback: Build aus Source via Rust/`cargo`
- [x] Pakete: `asusctl`, `lm-sensors`, ggf. `power-profiles-daemon`
- [x] **Konflikt-Check** beim Install — warnen wenn installiert:
  - `nbfc` / `nbfc-linux`
  - `fancontrol`
  - `tlp` (im aggressiven Modus)
- [x] systemd-Service zum Wiederherstellen des letzten Profils nach Boot + Resume
- [x] sudoers für `platform_profile`-Schreibzugriff (Doppelpunkte korrekt escaped, falls nötig — Lehre aus Track 1 / v1.1)

### v0.4 — Terminal-Wrapper (ERLEDIGT)

- [x] `rog-fan.sh` mit folgenden Befehlen:
  - `rog-fan status` — aktuelles Profil + RPM + Temps
  - `rog-fan quiet|balanced|performance` — Profilwechsel
  - `rog-fan curve <cpu|gpu> <profile>` — asusctl-Curve setzen
  - `rog-fan watch` — Live-Anzeige im Terminal, Polling alle 1 s
  - `rog-fan restore` — letztes gespeichertes Profil wiederherstellen
- [x] Zusätzliche Befehle: `next`, `info`, `curve-show`, `curve-default`
- [x] Profil-Normalisierung (lowercase ↔ Capitalized für asusctl v6)
- [x] Resume-kompatibles Speichern in `~/.config/rog-fan/last_profile`
- [x] Farb-Coding für Profile/Temp/RPM, Live-Watch mit konfigurierbarem Intervall
- [x] Bilingual DE/EN, kein sudo nötig
- [x] Validiert auf G713QM (asusctl v6.3.8): Profilwechsel + Live-Watch funktionieren

### v0.5 — GTK3 GUI (ERLEDIGT)

- [x] `rog-fan-gui.py` analog zu `rog-rgb-gui.py`
- [x] 3 große Profil-Buttons: **quiet / balanced / performance**
- [x] Live-Anzeige: CPU/GPU Temp + Fan RPMs (Polling alle 1–2 s)
- [x] Fan-Curve-Editor (optional, falls Zeit)
- [x] `.desktop` Entry (Menü-Eintrag in Cinnamon)

### v0.6 — Hotkey-Daemon + OSD + Boot-Service (ERLEDIGT)

- [x] Identifikation Fan-Taste (G713QM): `KEY_PROG4` (Code 203, Scancode `ff3100ae`) auf `/dev/input/event6` (Asus Keyboard)
- [x] `rog-fan-keyd.py` — Python-Daemon mit `python3-evdev`, auto-discovery aller Devices mit `KEY_PROG4`-Capability
- [x] OSD-Overlay (GTK3 POPUP, transparent, 2s Auto-Hide, oben-mitte zentriert, Profil-Farbcode)
- [x] Debouncing (0.4s) gegen Doppel-Trigger
- [x] `rog-fan-keyd.service` — systemd User-Service (Autostart bei Login)
- [x] `rog-fan-boot.service` — systemd System-Service (Profil-Restore beim Boot, analog zum Resume-Service)
- [x] Installer (`install-rog-fan.sh`) erweitert: Schritt 8b für Boot-Service, Uninstall räumt beide Services ab, T_STEP_BOOT / T_BOOT_OK bilingual
- [x] On-Device validiert auf G713QM: Fan-Taste rotiert Quiet → Balanced → Performance, OSD sichtbar, last_profile wird mitgeschrieben, Boot-Service stellt Profil wieder her

### v0.7 — Tray-Integration & GUI-Installer (ERLEDIGT)

- [x] `install-rog-fan-gui.py` — GTK3-Wizard analog zu `install-rog-rgb-gui.py` (für nicht-Terminal-User)
- [x] Installer erweitern: `python3-evdev` zu apt-deps, User in `input`-Gruppe, `rog-fan-keyd` deployen, User-Service einrichten
- [x] README-Sektion: Installation des `Sensors@claudiux` Applets aus Cinnamon-Spices (manuell, kein Auto-Install)
- [x] `.desktop`-Entries für `rog-fan-gui` (Cinnamon-Menü)

### v1.0 — Release (ERLEDIGT)

- [x] Bilingual DE/EN komplett (`ROG_LANG=en` durchgängig)
- [x] `README.md` erweitern (Fan-Sektion)
- [x] `README.de.md` spiegeln
- [x] End-to-End-Test auf G713QM (alle Profile, Suspend/Resume, Boot, Konflikt-Szenarien)
- [ ] **Repo-Umbenennung erwägen:** `ASUS_ROG_COLOR_Keyboard_Linux_Mint` → `ASUS_ROG_Suite_Linux_Mint` (optional, Track 3)

---

## Track 3: Übergreifend

**Status:** Track 1 und Track 2 v1.0 sind released. Track 3 ist optional/poliert.

- [ ] `install-rog-suite.sh` Meta-Installer (ruft RGB- + Fan-Installer nacheinander auf)
- [ ] Gemeinsames `rog-diagnose.sh` (ruft `rog-kbd-diagnose` + `rog-fan-diagnose` auf)
- [ ] Versionierung vereinheitlichen — alle Module tragen die gleiche Suite-Version (z.B. `2.0`, `2.1`, …)

---

## Logbuch

### 2026-06-06

- Brain-Files angelegt: `PROJECT_SOUL.md`, `PROJECT_PLAN.md`
- Hardware-Audit auf G713QM durchgeführt (Kernel 6.17, Mint 22.3)
- **Fan-Stack-Entscheidung:** `asusctl` (nbfc-linux abgelehnt, würde mit `asus-nb-wmi` kollidieren)
- **sudoers-Bug in RGB-Installer entdeckt** (Zeile 350 — fehlende Escapes bei `asus::kbd_backlight`) und gefixt
- **Tray-Empfehlung:** Cinnamon `Sensors@claudiux` Spices-Applet (keine Eigenentwicklung)
- v0.2 abgeschlossen: rog-fan-diagnose.sh implementiert (10 Sektionen, bilingual, --fix Modus)
- Funktionstest auf G713QM bestanden: Lüfter drehen jetzt 3000 RPM, CPU 49°C, throttle_thermal_policy=1 (performance)
- Bekannter Quirk vom Diagnose-Script korrekt erkannt und als harmlos markiert: fan_curve_get_factory_default = -19
- Offen für v0.3+: platform_profile setzt sich nach Suspend/Resume zurück → braucht systemd-resume.service

### 2026-06-06 (Abend)

- **Track 2 v0.3 abgeschlossen** — `install-rog-fan.sh` final
  - Source-Build-Chain stabilisiert (4 Iterationen): `--locked` raus, `rog-control-center` aus Cargo.toml entfernt, user-rustup-PATH-Detection für `edition2024`, apt build-deps erweitert (`clang, libclang-dev, libdbus-1-dev, pkg-config, libgtk-3-dev, libsystemd-dev, libudev-dev`)
  - Bug 203/EXEC gefixt: Symlinks `/usr/local/bin/asusd|asusctl` → `/usr/bin/asusd|asusctl` (Service-Unit hardcoded `/usr/bin/asusd`)
  - Uninstall-Block erweitert: räumt Source-Build-Binaries + Symlinks ab
  - PPD-Disable reversibel, Resume-Service aktiv, sudoers für `platform_profile` + `throttle_thermal_policy` validiert
  - asusd läuft (`active (running)`), DBus `xyz.ljones.Asusd` hoch, Aura-Manager erkennt Tastatur
- **Track 2 v0.4 abgeschlossen** — `rog-fan.sh` Terminal-Wrapper
  - ~680 Zeilen, bilingual DE/EN, kein `set -euo pipefail` (graceful errors)
  - Befehle: `status | quiet | balanced | performance | next | watch | restore | curve | curve-show | curve-default | info | help`
  - Profil-Normalisierung (lowercase user-facing ↔ Capitalized für asusctl v6)
  - Live-Watch mit Farb-Coding (Temp-Schwellen, RPM-Bänder, Profil-Farben)
  - last_profile in `~/.config/rog-fan/` (resume-service kompatibel)
  - On-Device validiert: Quiet/Balanced/Performance-Wechsel, Live-Watch mit Custom-Interval, Status-Output korrekt
- asusctl v6 CLI-Syntax dokumentiert (kein `-h`/`-P`/`--version` mehr; stattdessen `--help help`, `profile set <Cap>`, `info`)
- **Nächster Schritt:** Track 2 v0.5 — `rog-fan-gui.py` (GTK3, 3 Profil-Buttons + Live-Polling)

### 2026-06-06 (Spät)

- **Track 2 v0.5 abgeschlossen** — `rog-fan-gui.py` (742 Zeilen)
  - GTK3 Window 540×560, HeaderBar, About-Dialog
  - 3 Profil-Buttons mit Live-Highlight, CSS-styling
  - Status-Grid: aktuelles Profil, platform_profile, throttle_thermal_policy, AC/Battery (+ %), CPU-Temp, Fan-RPMs
  - 2s-Polling via GLib.timeout_add_seconds
  - Restore + Next Buttons, last_profile-Anzeige
  - AppIndicator/AyatanaAppIndicator3-Tray (Fallback: ohne Tray)
  - Bilingual DE/EN
- **Track 2 v0.6 abgeschlossen** — Hotkey-Daemon + OSD + Boot-Service
  - Fan-Taste identifiziert: `KEY_PROG4` (G713QM, `Asus Keyboard` Input-Device)
  - `rog-fan-keyd.py` (345 Zeilen) mit evdev-Listener, OSD-Popup (transparent, 2s, profile-coloured), Debouncing
  - User-Service `rog-fan-keyd.service` (graphical-session.target)
  - System-Service `rog-fan-boot.service` (Profil-Restore beim Boot, analog Resume-Service)
  - Installer erweitert (Schritt 8b + Uninstall-Cleanup + T_STEP_BOOT/T_BOOT_OK)
  - On-Device validiert: Tastendruck → Profilwechsel + OSD sichtbar, Boot/Resume-Restore funktioniert
- asusd speichert intern auch ein letztes Profil — unser System überschreibt es mit `~/.config/rog-fan/last_profile` (single source of truth)
- **Nächster Schritt:** Track 2 v0.7 — GUI-Installer + Tray-Docs, Installer-Erweiterung für keyd-Deployment (`python3-evdev`, `input`-Gruppe, User-Service)

### 2026-06-06 (Release v1.0)

- **Track 2 v0.7 abgeschlossen** — Installer-Erweiterung + GUI-Installer
  - `install-rog-fan.sh` deployt jetzt komplette Suite: `rog-fan`, `rog-fan-gui`, `rog-fan-keyd` nach `/usr/local/bin/`
  - apt-deps erweitert um `python3-evdev`
  - User wird automatisch in `input`-Gruppe aufgenommen (Hotkey-Daemon braucht das)
  - User-Service `rog-fan-keyd.service` wird via `sudo -u + systemctl --user` aktiviert
  - `.desktop`-Entry für `rog-fan-gui` (Cinnamon-Menü-Eintrag)
  - Uninstall räumt alle neuen Komponenten ab
  - Bilingual T_*-Strings (DE + EN) für alle neuen Schritte
  - `install-rog-fan-gui.py` (510 Zeilen) — GTK3-Wizard mit pkexec, Live-Log-Output, Sprachwahl, Uninstall-Toggle
- **Track 2 v1.0 RELEASE** — Bilingual + README komplett
  - `README.md` (Englisch, primary) komplett neu strukturiert: ROG Linux Suite Branding, RGB + Fan + Diagnostics Features, Installation, Usage, Architecture, Hardware Compatibility, Troubleshooting, Uninstall
  - `README.de.md` (Deutsch-Spiegel) — 1:1 lokalisiert
  - Existierende RGB-spezifische Doku (rogauracore-Backend-Details, USB-ID, Brightness-Quirk-Erklärung, rog-kbd-diagnose) sauber in RGB-Sektionen integriert
  - End-to-End-Test auf G713QM bestanden: Profile, Hotkey-Taste, OSD, Boot-Restore, Resume-Restore, Suspend/Resume, kompletter Installer-Run
- **Erreicht:**
  - Vollständige ROG Linux Suite v1.0: 4 User-facing Tools (rog-fan, rog-fan-gui, rog-fan-keyd, rog-rgb*), 2 Diagnose-Tools, 2 Installer (CLI + GUI), 3 systemd-Services (boot, resume, keyd-user)
  - Backend: asusctl v6.3.8 (source-built), rogauracore (RGB)
  - Bilingual durchgängig (ROG_LANG=de|en)
- **Offen (optional, Track 3):**
  - Repo-Umbenennung `ASUS_ROG_COLOR_Keyboard_Linux_Mint` → `ASUS_ROG_Suite_Linux_Mint`
  - Meta-Installer `install-rog-suite.sh`
  - Gemeinsames `rog-diagnose.sh`
