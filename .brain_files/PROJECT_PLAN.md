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
- [x] (2026-06-06) Installer-Härtung `install-rog-fan.sh`: `rog-fan-keyd.service` auf `WantedBy=default.target` umgestellt (Z. 14), idempotenter `loginctl enable-linger`-Guard vor User-Service-Enable (Z. 814–817) und Post-Install-Sanity-Check für `rog-fan-boot.service` / User-`rog-fan-keyd.service` (Z. 864–869). Behebt: User-Unit nach Reboot nicht aktiv.
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

### v1.0.1 — Hotfix Installer (ERLEDIGT)

- [x] Bugfix: `rog-fan-keyd`-Service-Aktivierung unter `pkexec` (neuer `user_systemctl()`-Helper in `install-rog-fan.sh`)

### v0.7.1 — GUI-Uninstaller Hotfix (ERLEDIGT)

- [x] Fix 1 — `install-rog-fan.sh`: `read -rp`-Prompt im Uninstall-Pfad nur noch ausführen wenn `[[ -t 0 && -t 1 ]]`. Verhinderte Deadlock, wenn die GUI das Skript via `pkexec` aufruft und stdout eine Pipe ist; Prompt-Text wurde durch `stdbuf -oL` zusätzlich verschluckt → wirkte wie kompletter Hang nach „[OK] asusd deaktiviert".
- [x] Fix 2 — `install-rog-fan-gui.py`: `subprocess.Popen` jetzt mit `stdin=subprocess.DEVNULL` als Defense-in-Depth gegen künftige `read`-Stellen. **(In v0.7.2 revertiert — brach pkexec/Polkit-Auth-Agent: „Einlesen der Argumente schlug fehl: Anzeige kann nicht geöffnet werden". Patch A reicht alleine.)**
- [x] Verifiziert auf Linux Mint nach Reboot: Fan-Service lädt sauber, Fan-Taste funktioniert.

### v0.7.2 — GUI-Hotfix Revert (ERLEDIGT)

- [x] Revert von Patch B aus v0.7.1: `stdin=subprocess.DEVNULL` aus `subprocess.Popen` in `install-rog-fan-gui.py` entfernt. Hat den Polkit-GTK-Auth-Agenten am `gtk_init` zerlegt (DISPLAY-/FD-Vererbung gestört), wodurch Install und Uninstall mit Exit-Code 1 noch vor der eigentlichen Skript-Logik scheiterten.
- [x] Patch A (`[[ -t 0 && -t 1 ]]` in `install-rog-fan.sh`) bleibt drin und fixt den Uninstall-Hang weiterhin zuverlässig.
- [x] Verifiziert: Install + Uninstall via GUI laufen sauber durch, asusctl bleibt im GUI-Pfad korrekt installiert.
- [x] Lesson Learned: Bei pkexec-Aufrufen `stdin`/`stdout`/`stderr` möglichst unangetastet lassen — Polkit-Auth-Agenten sind empfindlich gegen FD-Manipulation.

### v0.6.2 — rog-fan-keyd Auto-Reconnect (ERLEDIGT)

- [x] **Bug:** `rog-fan-keyd` verlor nach Suspend/Resume oder USB-Re-Enumeration die Verbindung zum Asus-Keyboard-Device (`OSError ENODEV` auf `/dev/input/eventX`) und blieb dann dauerhaft taub — Fan-Taste reagierte ab dem Disconnect nicht mehr, Workaround war manueller `systemctl --user restart rog-fan-keyd`.
- [x] **Fix in `rog-fan-keyd.py`:**
  - Neue `_find_device(name, phys)` rescannt `evdev.list_devices()` nach `name`+`TARGET_KEY`-Capability (überlebt `eventX`-Re-Nummerierung).
  - Neue `_reconnect(name, phys)` mit Backoff 1s → 2s → 5s → 10s (unbegrenzt) auf `threading.Event.wait()` (SIGTERM/SIGINT bricht sofort ab).
  - `_read_loop` fängt jetzt `OSError ENODEV` / `EBADF`, schließt das Handle, ruft `_reconnect()`, fügt das neue Handle in `self.devices` ein und macht weiter. Andere Devices (z.B. `event8 = Asus WMI hotkeys`) laufen währenddessen ungestört weiter.
  - VERSION 0.6.1 → 0.6.2.
- [x] **Verifiziert:** Über `echo 0 > /sys/bus/usb/devices/1-3/authorized` einen echten USB-Disconnect erzwungen. Journal zeigt `Device /dev/input/event6 disconnected` und 8 s später (1+2+5 Backoff) `[reconnect] OK: /dev/input/event6 (Asus Keyboard)`. Fan-Taste funktioniert anschließend wieder ohne Service-Restart.
- [x] **Nebenbefund (offen, NICHT in v0.6.2 gefixt):** `_on_keypress` läuft auf dem GTK-Main-Thread mit zwei synchronen `asusctl`-Subprozessen + 150 ms-Sleep → blockiert die UI 150 ms – 6 s pro Tastendruck und friert das OSD-Fenster bei `asusd`-Stalls ein. Kandidat für v0.6.3: Worker-Thread für asusctl-Calls, `osd.show_profile()` per `GLib.idle_add` zurück auf Main-Thread.

---

## Track 3: Übergreifend

**Status:** Track 1 und Track 2 v1.0 sind released. Track 3 ist optional/poliert.

### v2.0 — Meta-Installer (IN ARBEIT)

- [~] `install-rog-suite.sh` — dünner Orchestrator über `install-rog-rgb.sh` + `install-rog-fan.sh`, keine Logik-Duplikation, idempotent
  - [ ] 9.1 Skript-Skeleton: Header-Box „ROG Suite Meta-Installer", i18n via `ROG_LANG` (DE/EN, Bash-Assoziativ-Array `TR`), `step/ok/info/warn/die`-Helper, `require_root` + Auto-Relaunch via `pkexec` **einmal** am Anfang
  - [ ] 9.2 Flags `--rgb-only` / `--fan-only` / `--uninstall` / `--lang de|en`; Default-Install-Reihenfolge **RGB → Fan**, Uninstall-Reihenfolge **Fan → RGB**; Sub-Installer-Aufruf via `env ROG_LANG=… INSTALL_USER=… INSTALL_HOME=… bash <script>` (kein erneutes `pkexec`); Fehler im Install → harter Stopp, Fehler im Uninstall → best-effort (`|| true`)
  - [ ] 9.3 Akzeptanztest-Lauf auf G713QM: frischer Lauf, `--rgb-only`, `--fan-only`, `--uninstall`, `--uninstall --fan-only`, `--lang en`, Fehlersimulation (Sub-Installer umbenannt)
  - [ ] 9.4 README-Eintrag (EN + DE) im Installations-Abschnitt: empfohlener Einstiegspunkt für Neuinstallationen

### Sonstige (offen)

- [ ] Gemeinsames `rog-diagnose.sh` (ruft `rog-kbd-diagnose` + `rog-fan-diagnose` auf)
- [ ] GUI-Meta-Installer `install-rog-suite-gui.py` (Folge-Ticket nach v2.0 CLI)
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

### 2026-06-06 (Hotfix v1.0.1)

- **Bug:** Bei Installation über `install-rog-fan-gui.py` (pkexec) blieb `rog-fan-keyd.service` `inactive (dead)`. `systemctl --user enable --now` schlug still fehl, weil `DBUS_SESSION_BUS_ADDRESS` in der pkexec-Umgebung nicht gesetzt war und Fehler durch `2>/dev/null` verschluckt wurden. Konsequenz: Fan-Taste ohne Funktion nach GUI-Install.
- **Fix:** Neuer Helper `user_systemctl()` in `install-rog-fan.sh` (Zeilen 311–355). Setzt `XDG_RUNTIME_DIR` + `DBUS_SESSION_BUS_ADDRESS`, prüft User-Bus-Socket, startet bei Bedarf `user@UID.service`, leitet echte Fehlermeldungen durch.
- **Touched:** Install-Path (Zeilen 814–815) und Uninstall-Path (Zeile 377) nutzen jetzt den Helper statt direkter `sudo -u … systemctl --user`-Aufrufe.
- **Betroffene Datei:** `install-rog-fan.sh` (CLI- und GUI-Installer-Pfad gleichermaßen abgedeckt). README EN/DE: Troubleshooting-Zeile + Changelog-Eintrag ergänzt.

### 2026-06-06 (Hotfix v1.0.2)

- **Bug 1 — Fan-Hotkey-OSD zeigt ANSI-gefärbten Fehlertext `asusd is not running …`:**
  - Ursache lokalisiert in `rog-fan-keyd.py` Zeile 91: `return r.returncode == 0, (r.stdout or r.stderr).strip()` reichte asusctl-stderr (inkl. `\x1b[0;31m`-Sequenzen) als „Erfolgsausgabe" durch. `get_current_profile()` fiel danach auf `out.strip().capitalize()` zurück und gab den Warntext als vermeintlichen Profilnamen an `OSDWindow.show_profile()` — Pango escaped den Text, ANSI-Bytes überleben jedoch sichtbar.
  - **Fix:** `run_asusctl()` liefert jetzt `(ok, stdout, stderr)` getrennt und filtert ANSI per `ANSI_RE`. `get_current_profile()` akzeptiert ausschließlich `Quiet|Balanced|Performance` (kein Free-Text-Fallback mehr). `OSDWindow.show_profile()` strippt defensiv ANSI und verwirft unbekannte Profile.
- **Bug 2 — `install-rog-fan-gui.py` wirft `KeyboardInterrupt`-Traceback bei Ctrl+C:**
  - Ursache: kein eigener SIGINT-Handler → PyGObject `_ossighelper.register_sigint_fallback` ruft `signal.default_int_handler` auf, das den Traceback in `gi/_ossighelper.py:237` zeigt.
  - **Fix:** `GLib.unix_signal_add(SIGINT|SIGTERM, → Gtk.main_quit)` in neuem `_install_sigint_handler()`, plus `try/except KeyboardInterrupt` um `Gtk.main()`.
- **Betroffene Dateien:** `rog-fan-keyd.py` (v0.6 → v0.6.1), `install-rog-fan-gui.py`.

### 2026-06-06 (Installer-Härtung: User-Unit Persistenz nach Reboot)

- **Symptom:** GUI-Installer läuft erfolgreich durch, aber nach Reboot ist `rog-fan-keyd.service` (User-Unit) nicht aktiv → Fan-Hotkey ohne Funktion bis manuelle Re-Aktivierung.
- **Fix A — `rog-fan-keyd.service` Z. 14:** `WantedBy=graphical-session.target` → `WantedBy=default.target`. Der `graphical-session.target`-Symlink im User-WantedBy-Dir überlebt einen Reboot nicht zuverlässig; `default.target` ist die kanonische User-Bus-Boot-Stufe.
- **Fix B — `install-rog-fan.sh` Z. 814–817:** Idempotenter Guard `loginctl show-user … | grep Linger=yes || loginctl enable-linger "$INSTALL_USER"` direkt vor `user_systemctl enable --now rog-fan-keyd.service`. Ohne Linger startet die User-systemd-Instanz erst beim Login → Enable ist persistent, Aktivierung aber nicht.
- **Post-Install-Sanity-Check — `install-rog-fan.sh` Z. 864–869:** WARN-Ausgabe (bilingual) falls `rog-fan-boot.service` (system) oder User-`rog-fan-keyd.service` nach Install nicht `enabled` + `active` sind. Macht künftige Regressionen sofort sichtbar.
- **Anfangsverdacht widerlegt:** „fehlendes `daemon-reload`" — `systemctl daemon-reload` bzw. `--user daemon-reload` waren vor beiden Service-Enables bereits gesetzt.
- **Betroffene Dateien:** `rog-fan-keyd.service`, `install-rog-fan.sh`.
