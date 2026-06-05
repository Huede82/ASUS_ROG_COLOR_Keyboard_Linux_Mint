# ⚡ ROG RGB — Tastaturbeleuchtungs-Steuerung für Linux

> ASUS ROG N-KEY Laptop-Tastatur RGB unter Linux Mint / Ubuntu vollständig steuern

🌐 **Sprache / Language:** [🇩🇪 Deutsch](README.de.md) · [🇬🇧 English](README.md)

---

| | |
|---|---|
| **Version** | 1.0 |
| **Datum** | 2026-06-05 |
| **Autor** | Martin "Der Lemming" Hütter |
| **Co-Autor** | GitHub Copilot (Claude Sonnet 4.6) |
| **Lizenz** | MIT |
| **Plattform** | Linux Mint 22.x / Ubuntu 24.04 · Kernel ≥ 5.11 |

---

## Inhalt

- [Hintergrund](#hintergrund)
- [Systemvoraussetzungen](#systemvoraussetzungen)
- [Installation](#installation)
- [Dateien im Projekt](#dateien-im-projekt)
- [Verwendung](#verwendung)
  - [Grafische GUI](#grafische-gui)
  - [Terminal-Steuerung](#terminal-steuerung)
  - [Diagnose-Tool](#diagnose-tool)
- [Autostart & Suspend/Resume](#autostart--suspendresume)
- [Deinstallation](#deinstallation)
- [Technischer Hintergrund](#technischer-hintergrund)
- [Bekannte Eigenheiten](#bekannte-eigenheiten)

---

## Hintergrund

ASUS ROG Laptops verwenden ein proprietäres **N-KEY USB HID Device** (USB `0b05:1866`) für die RGB-Tastaturbeleuchtung.  
Unter Linux existiert zwar ein Kernel-Treiber (`hid_asus`), der ein einfaches Helligkeitsinterface unter `/sys/class/leds/asus::kbd_backlight/` bereitstellt — die eigentliche **Farbsteuerung** ist jedoch nur über direkte USB HID Control-Transfers möglich.

Das Tool [rogauracore](https://github.com/wroberts/rogauracore) übernimmt diese Kommunikation.  
Dieses Projekt stellt eine komfortable Steuerungsebene darüber bereit:
eine **grafische GUI**, ein **Terminal-Wrapper** und ein **Diagnose-Tool**.

---

## Systemvoraussetzungen

| Anforderung | Version / Paket |
|---|---|
| Linux-Kernel | ≥ 5.11 (N-KEY vollständig unterstützt) |
| Distro | Ubuntu 24.04 / Linux Mint 22.x (apt-basiert) |
| Python | 3.10+ |
| GTK | `python3-gi`, `gir1.2-gtk-3.0`, `python3-gi-cairo` |
| Build | `gcc`, `make`, `autoconf`, `automake`, `libtool` |
| USB | `libusb-1.0-0-dev`, `libhidapi-dev` |

---

## Installation

### Option A: Grafischer Installer (empfohlen)

```bash
cd "ROG Scripts"
python3 install-rog-rgb-gui.py
```

Der grafische Installer führt durch einen 5-seitigen Wizard:

| Seite | Inhalt |
|---|---|
| Willkommen | Überblick über die drei Phasen |
| Diagnose | Animierte Prüfung von Hardware, Modulen, Tools |
| Installationsplan | Was wird installiert / übersprungen / aktualisiert |
| Installation | Fortschrittsbalken + Live-Log + Passwort-Eingabe |
| Fertig | Ergebnis, Button zum direkten Start der RGB-GUI |

### Option B: Terminal-Installer

```bash
# Ins Projektverzeichnis wechseln
cd "ROG Scripts"

# Sorglos-Installations-Script ausführen (installiert alles automatisch)
sudo bash install-rog-rgb.sh
```

Das Script führt folgende Schritte aus:

1. Systemvoraussetzungen prüfen (Kernel, USB-Gerät, apt)
2. Abhängigkeiten installieren (`git`, `gcc`, `libusb`, `python3-gi`, …)
3. `rogauracore` aus dem Quellcode bauen und installieren
4. `rog-rgb-gui` (GUI) nach `/usr/local/bin` installieren
5. `rog-rgb` (Terminal-Wrapper) nach `/usr/local/bin` installieren
6. `rog-kbd-diagnose` nach `/usr/local/bin` installieren
7. udev-Regeln für Gerätezugriff ohne root aktivieren
8. `sudo`-Berechtigung für sysfs-Helligkeit anlegen
9. systemd-Services für Autostart und Resume anlegen
10. `.desktop`-Eintrag im Anwendungsmenü registrieren
11. Funktionstest

---

## Dateien im Projekt

```
ROG Scripts/
├── install-rog-rgb-gui.py  # Grafischer Installer (python3 install-rog-rgb-gui.py)
├── install-rog-rgb.sh      # Terminal-Installer (sudo bash install-rog-rgb.sh)
├── rog-rgb-gui.py          # Grafische GTK3-Oberfläche
├── rog-rgb.sh              # Terminal-Wrapper (lokal, vor Installation)
├── rog-kbd-diagnose.sh     # Diagnose-Tool (lokal, vor Installation)
└── README.md               # Diese Datei
```

Nach der Installation zusätzlich systemweit verfügbar:

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
~/.config/rog-rgb/              # Konfigurationsverzeichnis
    ├── last_color              # Letzter aktiver rogauracore-Befehl
    └── gui_settings.json       # GUI-Einstellungen (Effekt, Farbe, Helligkeit)
```

---

## Verwendung

### Grafische GUI

```bash
rog-rgb-gui
```

Oder im Anwendungsmenü unter **Einstellungen → ROG RGB Steuerung**.

**Funktionen der GUI:**

| Bereich | Beschreibung |
|---|---|
| Farbvorschau | Klickbarer Balken öffnet GTK-Farbwähler mit Farbkreis und Palette |
| Hex-Eingabe | Direkte Farbcode-Eingabe (z. B. `ff0000`) |
| Schnellfarben | 12 vordefinierte Farb-Buttons |
| Helligkeit | Slider: Aus / 33% / 66% / 100% |
| Effekte | Statisch · Atmen · Regenbogen · Farbzyklus · Ausschalten |
| Geschwindigkeit | Langsam / Mittel / Schnell (für animierte Effekte) |
| Tastatur-Vorschau | Live-Darstellung der Beleuchtung auf Keyboard-Silhouette |
| Live-Modus | Sofortige Übertragung bei jeder Änderung (umschaltbar) |
| Anwenden | Explizites Anwenden + dauerhaftes Speichern |
| Zurücksetzen | Gespeicherte Einstellungen laden |

---

### Terminal-Steuerung

```bash
# Farbe setzen (Hex)
rog-rgb #ff0000
rog-rgb ff0000

# Vordefinierte Farben
rog-rgb red
rog-rgb green
rog-rgb blue
rog-rgb cyan
rog-rgb yellow
rog-rgb gold
rog-rgb magenta
rog-rgb white

# Effekte
rog-rgb breathe ff0000          # Atmen mit Farbe (Geschwindigkeit 2)
rog-rgb breathe 00aaff 3        # Atmen mit Geschwindigkeit 3
rog-rgb rainbow                 # Regenbogen (Geschwindigkeit 2)
rog-rgb rainbow 1               # Regenbogen langsam
rog-rgb cycle                   # Automatischer Farbzyklus

# Steuerung
rog-rgb off                     # Ausschalten
rog-rgb status                  # Status anzeigen
rog-rgb restore                 # Letzte gespeicherte Einstellung laden
```

---

### Diagnose-Tool

```bash
rog-kbd-diagnose
```

Prüft automatisch:

1. Kernel-Version und Distro
2. ASUS N-KEY USB-Gerät
3. Kernel-Module (`hid_asus`, `asus_wmi`, `asus_nb_wmi`)
4. sysfs LED-Interface (`/sys/class/leds/asus::kbd_backlight`)
5. HID Raw-Schnittstelle und Zugriffsrechte
6. asusctl (falls installiert)
7. OpenRGB (falls installiert)
8. Kernel-Meldungen (dmesg) auf Fehler
9. udev-Regeln
10. Suspend/Resume-Probleme

Am Ende werden alle gefundenen Probleme mit konkreten Fix-Befehlen zusammengefasst.

```bash
# Mit automatischem Helligkeits-Fix
rog-kbd-diagnose --fix
```

---

## Autostart & Suspend/Resume

Die Installation richtet zwei systemd-Services ein:

| Service | Wann aktiv |
|---|---|
| `rog-rgb.service` | Beim Booten — stellt letzte Farbe wieder her |
| `rog-rgb-resume.service` | Nach Suspend/Hibernate/Hybrid-Sleep |

Die letzte aktive Einstellung wird in `~/.config/rog-rgb/last_color` gespeichert.  
Beim Start liest der Service diese Datei und setzt Helligkeit und Farbe/Effekt.

```bash
# Service-Status prüfen
systemctl status rog-rgb.service
systemctl status rog-rgb-resume.service

# Manuell ausführen (zum Testen)
sudo systemctl start rog-rgb.service
```

---

## Deinstallation

```bash
sudo bash install-rog-rgb.sh --uninstall
```

Entfernt: rogauracore, rog-rgb, rog-rgb-gui, rog-kbd-diagnose, systemd-Services, udev-Regeln, sudo-Regel, .desktop-Eintrag.

> **Hinweis:** Die Konfiguration in `~/.config/rog-rgb/` bleibt erhalten.  
> Vollständig entfernen: `rm -rf ~/.config/rog-rgb`

---

## Technischer Hintergrund

### Warum kein asusctl?

[asusctl](https://gitlab.com/asus-linux/asusctl) ist das offizielle ASUS-Linux-Tool, unterstützt jedoch nur Ubuntu LTS mit spezifischen PPAs. Für Linux Mint 22.3 ist kein kompatibles PPA verfügbar.

### Wie funktioniert rogauracore?

`rogauracore` kommuniziert direkt per **libusb USB Control-Transfer** mit dem N-KEY Device:

```
Host → USB Control-Transfer (bmRequestType=0x21, bRequest=9) → N-KEY HID
       ↳ 17-Byte-Nachricht mit Effekt-/Farbdaten
```

Der Rückgabecode `17` bedeutet Erfolg (= 17 übertragene Bytes = `MESSAGE_LENGTH`).

### Helligkeit-Eigenheit

Der `rogauracore`-Zugriff setzt den sysfs-Wert `/sys/class/leds/asus::kbd_backlight/brightness` auf `0` zurück, da der Kernel-Treiber die USB-Schnittstelle kurz freigibt. Der Wrapper setzt die Helligkeit deshalb nach jedem HID-Kommando automatisch zurück.

---

## Bekannte Eigenheiten

| Problem | Erklärung | Lösung |
|---|---|---|
| Helligkeit = 0 nach rogauracore | Kernel-Treiber-Sideeffect | Wird automatisch korrigiert |
| RGB erlischt nach Suspend | N-KEY verliert USB-State | `rog-rgb-resume.service` stellt her |
| rogauracore braucht sudo | USB-Gerätezugriff erfordert Berechtigungen | udev-Regel + sudoers-Eintrag wird von Installer gesetzt |
| fan_curve_get_factory_default Fehler | asus_wmi dmesg-Meldung, betrifft nur Lüfterkurven | Kann ignoriert werden |

---

*Dieses Projekt entstand aus der echten Problemstellung: Die ASUS ROG RGB-Tastatur leuchtete nach einer Linux-Mint-Installation nicht — und es gab kein einfaches, vollständiges Werkzeug zur Diagnose und Behebung.*
