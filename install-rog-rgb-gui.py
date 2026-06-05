#!/usr/bin/env python3
"""
ROG RGB — Grafischer Installer
Wizard mit Hardware-Erkennung, Treiber-Check und geführter Installation
"""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Pango

import subprocess, threading, os, sys, socket, re, time, json
from pathlib import Path

SCRIPT_DIR   = Path(__file__).resolve().parent
INSTALL_SH   = SCRIPT_DIR / "install-rog-rgb.sh"
CONFIG_DIR   = Path.home() / ".config" / "rog-rgb"
CONFIG_FILE  = CONFIG_DIR / "gui_settings.json"
INSTALL_USER = os.environ.get("SUDO_USER", os.environ.get("USER", ""))

# ── Language ──────────────────────────────────────────────────────────────────
def _load_lang():
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f).get("language", "de")
    except Exception:
        return os.environ.get("ROG_LANG", "de")

def _save_lang(lang):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        data = {}
        try:
            with open(CONFIG_FILE) as f:
                data = json.load(f)
        except Exception:
            pass
        data["language"] = lang
        with open(CONFIG_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

_LANG = _load_lang()

TR = {
    "de": {
        "win_title":       "ROG RGB Installer",
        "hb_subtitle":     "ASUS N-KEY Tastaturbeleuchtung",
        "lang_btn":        "🌐 EN",
        "lang_tooltip":    "Switch to English",
        "dots":            ["Willkommen", "Diagnose", "Plan", "Installation", "Fertig"],
        "nav_back":        "◀  Zurück",
        "nav_next":        "Weiter  ▶",
        "nav_check":       "Diagnose starten  ▶",
        "nav_install":     "Installation starten  ▶",
        "nav_wait":        "Bitte warten …",
        "nav_close":       "✕  Schließen",
        "status_welcome":  "Willkommen",
        "status_checking": "Diagnose läuft …",
        "status_plan":     "Installationsplan",
        "status_running":  "Installation läuft …",
        "status_done_ok":  "✓  Installation erfolgreich!",
        "status_done_err": "✗  Fehler aufgetreten",
        "status_done":     "Fertig",
        "page1_sub":       "Tastaturbeleuchtungs-Installer",
        "page1_note":      ("Dieses Tool richtet rogauracore, den rog-rgb Befehl, die grafische GUI\n"
                            "und alle systemd-Services für Autostart & Suspend-Resume ein."),
        "p1_cards":        [
            ("🔍", "Diagnose",       "Prüft Hardware,\nKernel-Module,\nTreiber & Tools"),
            ("📋", "Installationsplan", "Zeigt was fehlt\nund was bereits\nvorhanden ist"),
            ("🚀", "Installation",   "Installiert alles\nautomatisch mit\nFortschrittsanzeige"),
        ],
        "page2_title":     "🔍  System-Diagnose",
        "page2_sub":       "Prüft Hardware, Kernel-Module, Treiber und installierte Software.",
        "check_all_ok":    "✓  Alle Checks bestanden — System ist bereit",
        "check_warns":     lambda w: f"⚠  {w} Warnung(en) — Installation empfohlen",
        "check_fails":     lambda f, w: f"✗  {f} Fehler, {w} Warnungen gefunden",
        "page3_title":     "📋  Installationsplan",
        "page3_sub":       "Was wird installiert, aktualisiert oder übersprungen.",
        "plan_section":    "WIRD INSTALLIERT / AKTUALISIERT",
        "plan_present":    "✓ (vorhanden)",
        "plan_install":    "✗ → wird installiert",
        "plan_update":     "⚠ → wird eingerichtet",
        "sudo_root":       "✓  Läuft als root — Installation kann direkt starten.",
        "sudo_cached":     "✓  sudo-Berechtigung gecacht — kein Passwort nötig.",
        "sudo_ask":        "🔒  Sudo-Passwort eingeben, um die Installation zu starten:",
        "pw_placeholder":  "Passwort …",
        "page4_title":     "🚀  Installation",
        "page4_output":    "AUSGABE",
        "step_names":      ["Abhängigkeiten", "rogauracore", "Skripte", "udev/sudo", "Services", "Test"],
        "log_start":       "▶  Installation gestartet …",
        "log_ok":          "✓  Installation erfolgreich abgeschlossen!",
        "log_err":         lambda rc: f"✗  Installation fehlgeschlagen (Exit-Code: {rc})",
        "log_warn":        "   → Log oben auf Fehlermeldungen prüfen",
        "log_no_script":   "Installationsskript nicht gefunden.",
        "log_script_path": lambda p: f"   Script: {p}",
        "log_exec_err":    lambda e: f"AUSFÜHRUNGSFEHLER: {e}",
        "status_script_miss": "✗  Script fehlt",
        "done_ok_title":   "Installation abgeschlossen!",
        "done_ok_sub":     "Alle Komponenten wurden erfolgreich installiert.",
        "done_err_title":  "Installation unvollständig",
        "done_err_sub":    "Mindestens ein Schritt ist fehlgeschlagen. Log auf Fehler prüfen.",
        "done_ok_items":   [
            ("rog-rgb-gui",      "Grafische RGB-Steuerung (Terminal: rog-rgb-gui)"),
            ("rog-rgb #ff0000",  "Terminal-Steuerung (z. B. rog-rgb #ff0000)"),
            ("rog-kbd-diagnose", "Diagnose-Tool"),
            ("Autostart",        "RGB wird beim Booten & nach Standby wiederhergestellt"),
            ("Menü",             "App im Anwendungsmenü: Einstellungen → ROG RGB Steuerung"),
        ],
        "done_err_items":  [
            ("Log prüfen",          "Details im Log auf der vorherigen Seite"),
            ("sudo-Berechtigung?",  "Das Script braucht sudo-Rechte"),
            ("Internetzugang?",     "rogauracore wird von GitHub geladen"),
        ],
        "done_err_manual": lambda p: f"Manuell ausführen: sudo bash {p}",
        "btn_launch_gui":  "🖥  GUI starten",
        "btn_close":       "✕  Schließen",
        "checks": {
            "kernel_ok":     lambda v: (f"Kernel {v}", "N-KEY RGB vollständig unterstützt"),
            "kernel_warn":   lambda v: (f"Kernel {v}", "Kernel < 5.11: eingeschränkte N-KEY Unterstützung"),
            "kernel_unk":    lambda v: (f"Kernel {v}", "Version konnte nicht geprüft werden"),
            "distro_ok":     lambda d: (d, "Unterstützte Distribution"),
            "distro_warn":   lambda d: (d, "Möglicherweise eingeschränkte Unterstützung"),
            "apt_ok":        ("apt Paketmanager", "Paketmanager verfügbar"),
            "apt_fail":      ("apt nicht gefunden", "Nur apt-basierte Systeme unterstützt"),
            "usb_ok":        lambda n, p: (f"ASUS {n} (0b05:{p})", "USB N-KEY Gerät erkannt"),
            "usb_fail":      ("ASUS N-KEY USB nicht gefunden", "Gerät nicht verbunden oder unbekannte PID"),
            "sysfs_ok":      lambda b, m: (f"kbd_backlight ({b}/{m})", "sysfs LED-Interface vorhanden"),
            "sysfs_warn":    ("kbd_backlight sysfs fehlt", "hid_asus Modul geladen? Wird nach Modultest geprüft"),
            "mod_ok":        lambda n: (f"{n} geladen", "Modul aktiv"),
            "mod_fail":      lambda n, fix: (f"{n} fehlt", fix),
            "build_ok":      ("Build-Tools verfügbar", "gcc, make, git, autoconf"),
            "build_warn":    lambda m: (f"Fehlende Tools: {m}", "Werden beim Installieren nachgezogen"),
            "libusb_ok":     ("libusb-1.0-0-dev installiert", ""),
            "libusb_warn":   ("libusb-1.0-0-dev fehlt", "Wird beim Installieren nachgezogen"),
            "pygtk_ok":      lambda v: ("Python GTK3 verfügbar", f"gi {v}"),
            "pygtk_fail":    lambda e: ("Python GTK3 fehlt", str(e)),
            "rogaura_ok":    ("rogauracore installiert", ""),
            "rogaura_warn":  ("rogauracore nicht installiert", "Wird beim Installieren gebaut und installiert"),
            "internet_ok":   ("Internetzugang vorhanden", "GitHub für rogauracore-Quellcode erreichbar"),
            "internet_fail": ("Kein Internetzugang", "rogauracore-Quellcode kann nicht heruntergeladen werden"),
            "udev_ok":       lambda p: ("udev-Regel vorhanden", str(p)),
            "udev_warn":     ("udev-Regel fehlt", "Wird beim Installieren angelegt"),
            "svc_ok":        ("rog-rgb.service aktiviert", "Autostart bei Boot konfiguriert"),
            "svc_warn":      ("rog-rgb.service fehlt", "Wird beim Installieren eingerichtet"),
            "script_ok":     lambda p: ("install-rog-rgb.sh gefunden", str(p)),
            "script_fail":   lambda p: ("install-rog-rgb.sh nicht gefunden", f"Erwartet in: {p}"),
        },
        "plan_items": [
            ("rogauracore",  "rogauracore bauen & installieren", "rogauracore", "Wird aus GitHub-Quellcode gebaut"),
            ("rogaura",      "rogauracore",                       "rogauracore", "Wird aktualisiert"),
            ("rog-rgb",      "rog-rgb Terminal-Befehl",           None,          "Wird nach /usr/local/bin installiert"),
            ("rog-gui",      "rog-rgb-gui grafische Oberfläche",  None,          "Wird nach /usr/local/bin installiert"),
            ("rog-diag",     "rog-kbd-diagnose Diagnose-Tool",    None,          "Wird nach /usr/local/bin installiert"),
            ("udev",         "udev-Regel (Gerätezugriff)",        "udev",        "Wird in /lib/udev/rules.d/ installiert"),
            ("service",      "systemd Autostart-Service",         "svc",         "rog-rgb.service + rog-rgb-resume.service"),
            ("build_pkg",    "Build-Pakete (gcc, make, …)",       "build",       "Via apt installiert"),
            ("libusb_pkg",   "libusb-1.0-0-dev",                  "libusb",      "Via apt installiert"),
        ],
        "check_group_labels": {
            "SYSTEM":       ("SYSTEM",       [("kernel","Kernel-Version"),("distro","Linux-Distribution"),("apt","Paketmanager (apt)"),("internet","Internetzugang")]),
            "HARDWARE":     ("HARDWARE",     [("usb","ASUS N-KEY USB-Gerät"),("sysfs","kbd_backlight sysfs")]),
            "KERNEL-MODULE":("KERNEL-MODULE",[("hid","hid_asus Modul"),("wmi","asus_wmi Modul"),("nb","asus_nb_wmi Modul")]),
            "SOFTWARE":     ("SOFTWARE",     [("build","Build-Tools"),("libusb","libusb-1.0-0-dev"),("pygtk","Python GTK3"),("rogaura","rogauracore")]),
            "INSTALLATION": ("INSTALLATION", [("script","Installations-Script"),("udev","udev-Regel"),("svc","systemd-Service")]),
        },
    },
    "en": {
        "win_title":       "ROG RGB Installer",
        "hb_subtitle":     "ASUS N-KEY Keyboard Backlight",
        "lang_btn":        "🌐 DE",
        "lang_tooltip":    "Zu Deutsch wechseln",
        "dots":            ["Welcome", "Diagnostics", "Plan", "Installation", "Done"],
        "nav_back":        "◀  Back",
        "nav_next":        "Next  ▶",
        "nav_check":       "Start diagnostics  ▶",
        "nav_install":     "Start installation  ▶",
        "nav_wait":        "Please wait …",
        "nav_close":       "✕  Close",
        "status_welcome":  "Welcome",
        "status_checking": "Running diagnostics …",
        "status_plan":     "Installation plan",
        "status_running":  "Installing …",
        "status_done_ok":  "✓  Installation successful!",
        "status_done_err": "✗  Errors occurred",
        "status_done":     "Done",
        "page1_sub":       "Keyboard Backlight Installer",
        "page1_note":      ("This tool sets up rogauracore, the rog-rgb command, the graphical GUI\n"
                            "and all systemd services for autostart & suspend-resume."),
        "p1_cards":        [
            ("🔍", "Diagnostics",  "Checks hardware,\nkernel modules,\ndrivers & tools"),
            ("📋", "Plan",         "Shows what's missing\nand what's already\ninstalled"),
            ("🚀", "Installation", "Installs everything\nautomatically with\nprogress display"),
        ],
        "page2_title":     "🔍  System Diagnostics",
        "page2_sub":       "Checks hardware, kernel modules, drivers and installed software.",
        "check_all_ok":    "✓  All checks passed — system is ready",
        "check_warns":     lambda w: f"⚠  {w} warning(s) — installation recommended",
        "check_fails":     lambda f, w: f"✗  {f} error(s), {w} warning(s) found",
        "page3_title":     "📋  Installation Plan",
        "page3_sub":       "What will be installed, updated, or skipped.",
        "plan_section":    "WILL BE INSTALLED / UPDATED",
        "plan_present":    "✓ (already installed)",
        "plan_install":    "✗ → will be installed",
        "plan_update":     "⚠ → will be configured",
        "sudo_root":       "✓  Running as root — installation can start directly.",
        "sudo_cached":     "✓  sudo credentials cached — no password needed.",
        "sudo_ask":        "🔒  Enter sudo password to start installation:",
        "pw_placeholder":  "Password …",
        "page4_title":     "🚀  Installation",
        "page4_output":    "OUTPUT",
        "step_names":      ["Dependencies", "rogauracore", "Scripts", "udev/sudo", "Services", "Test"],
        "log_start":       "▶  Installation started …",
        "log_ok":          "✓  Installation completed successfully!",
        "log_err":         lambda rc: f"✗  Installation failed (exit code: {rc})",
        "log_warn":        "   → Check log above for error messages",
        "log_no_script":   "Install script not found.",
        "log_script_path": lambda p: f"   Script: {p}",
        "log_exec_err":    lambda e: f"EXECUTION ERROR: {e}",
        "status_script_miss": "✗  Script missing",
        "done_ok_title":   "Installation complete!",
        "done_ok_sub":     "All components were successfully installed.",
        "done_err_title":  "Installation incomplete",
        "done_err_sub":    "At least one step failed. Check the log for errors.",
        "done_ok_items":   [
            ("rog-rgb-gui",      "Graphical RGB control (terminal: rog-rgb-gui)"),
            ("rog-rgb #ff0000",  "Terminal control (e.g. rog-rgb #ff0000)"),
            ("rog-kbd-diagnose", "Diagnostic tool"),
            ("Autostart",        "RGB restored on boot & after suspend"),
            ("Menu",             "App in menu: Settings → ROG RGB Control"),
        ],
        "done_err_items":  [
            ("Check log",        "Details in the log on the previous page"),
            ("sudo permission?", "The script needs sudo rights"),
            ("Internet?",        "rogauracore is downloaded from GitHub"),
        ],
        "done_err_manual": lambda p: f"Run manually: sudo bash {p}",
        "btn_launch_gui":  "🖥  Launch GUI",
        "btn_close":       "✕  Close",
        "checks": {
            "kernel_ok":     lambda v: (f"Kernel {v}", "N-KEY RGB fully supported"),
            "kernel_warn":   lambda v: (f"Kernel {v}", "Kernel < 5.11: limited N-KEY support"),
            "kernel_unk":    lambda v: (f"Kernel {v}", "Could not verify version"),
            "distro_ok":     lambda d: (d, "Supported distribution"),
            "distro_warn":   lambda d: (d, "May have limited support"),
            "apt_ok":        ("apt package manager", "Package manager available"),
            "apt_fail":      ("apt not found", "Only apt-based systems supported"),
            "usb_ok":        lambda n, p: (f"ASUS {n} (0b05:{p})", "USB N-KEY device detected"),
            "usb_fail":      ("ASUS N-KEY USB not found", "Device not connected or unknown PID"),
            "sysfs_ok":      lambda b, m: (f"kbd_backlight ({b}/{m})", "sysfs LED interface present"),
            "sysfs_warn":    ("kbd_backlight sysfs missing", "hid_asus module loaded? Checked after module test"),
            "mod_ok":        lambda n: (f"{n} loaded", "Module active"),
            "mod_fail":      lambda n, fix: (f"{n} missing", fix),
            "build_ok":      ("Build tools available", "gcc, make, git, autoconf"),
            "build_warn":    lambda m: (f"Missing tools: {m}", "Will be installed automatically"),
            "libusb_ok":     ("libusb-1.0-0-dev installed", ""),
            "libusb_warn":   ("libusb-1.0-0-dev missing", "Will be installed automatically"),
            "pygtk_ok":      lambda v: ("Python GTK3 available", f"gi {v}"),
            "pygtk_fail":    lambda e: ("Python GTK3 missing", str(e)),
            "rogaura_ok":    ("rogauracore installed", ""),
            "rogaura_warn":  ("rogauracore not installed", "Will be built and installed"),
            "internet_ok":   ("Internet connection available", "GitHub reachable for rogauracore source"),
            "internet_fail": ("No internet connection", "Cannot download rogauracore source"),
            "udev_ok":       lambda p: ("udev rule present", str(p)),
            "udev_warn":     ("udev rule missing", "Will be created during installation"),
            "svc_ok":        ("rog-rgb.service enabled", "Boot autostart configured"),
            "svc_warn":      ("rog-rgb.service missing", "Will be set up during installation"),
            "script_ok":     lambda p: ("install-rog-rgb.sh found", str(p)),
            "script_fail":   lambda p: ("install-rog-rgb.sh not found", f"Expected at: {p}"),
        },
        "plan_items": [
            ("rogauracore",  "Build & install rogauracore",     "rogauracore", "Built from GitHub source"),
            ("rogaura",      "rogauracore",                      "rogauracore", "Will be updated"),
            ("rog-rgb",      "rog-rgb terminal command",         None,          "Installed to /usr/local/bin"),
            ("rog-gui",      "rog-rgb-gui graphical interface",  None,          "Installed to /usr/local/bin"),
            ("rog-diag",     "rog-kbd-diagnose diagnostic tool", None,          "Installed to /usr/local/bin"),
            ("udev",         "udev rule (device access)",        "udev",        "Installed to /lib/udev/rules.d/"),
            ("service",      "systemd autostart service",        "svc",         "rog-rgb.service + rog-rgb-resume.service"),
            ("build_pkg",    "Build packages (gcc, make, …)",   "build",       "Installed via apt"),
            ("libusb_pkg",   "libusb-1.0-0-dev",                "libusb",      "Installed via apt"),
        ],
        "check_group_labels": {
            "SYSTEM":        ("SYSTEM",       [("kernel","Kernel version"),("distro","Linux distribution"),("apt","Package manager (apt)"),("internet","Internet connection")]),
            "HARDWARE":      ("HARDWARE",     [("usb","ASUS N-KEY USB device"),("sysfs","kbd_backlight sysfs")]),
            "KERNEL MODULES":("KERNEL MODULES",[("hid","hid_asus module"),("wmi","asus_wmi module"),("nb","asus_nb_wmi module")]),
            "SOFTWARE":      ("SOFTWARE",     [("build","Build tools"),("libusb","libusb-1.0-0-dev"),("pygtk","Python GTK3"),("rogaura","rogauracore")]),
            "INSTALLATION":  ("INSTALLATION", [("script","Install script"),("udev","udev rule"),("svc","systemd service")]),
        },
    },
}

def _t(key):
    return TR.get(_LANG, TR["de"]).get(key, TR["de"].get(key, key))

# ── CSS ────────────────────────────────────────────────────────────────────────
CSS = """
* { -gtk-outline-radius: 0; outline: none; }
window, .background { background-color: #1e1e2e; }

headerbar, .titlebar {
    background-color: #181825; background-image: none;
    border-bottom: 1px solid #313244; box-shadow: none; padding: 4px 8px;
}
headerbar .title  { color: #cba6f7; font-weight: bold; font-size: 14px; }
headerbar .subtitle { color: #6c7086; font-size: 11px; }
headerbar button {
    background: transparent; background-image: none;
    border: none; border-radius: 6px; color: #6c7086; padding: 4px 8px;
}
headerbar button:hover { background: #313244; background-image: none; color: #cdd6f4; }

label { color: #cdd6f4; }

.page-title  { color: #cba6f7; font-size: 22px; font-weight: bold; }
.page-sub    { color: #6c7086; font-size: 13px; }
.card-title  { color: #6c7086; font-size: 10px; font-weight: bold; letter-spacing: 2px; }

.card {
    background-color: #181825; border-radius: 12px;
    border: 1px solid #313244; padding: 14px; margin: 5px;
}

/* Check items */
.check-row    { padding: 3px 0; }
.check-label  { color: #cdd6f4; font-size: 13px; }
.check-ok     { color: #a6e3a1; font-size: 14px; font-weight: bold; }
.check-warn   { color: #f9e2af; font-size: 14px; font-weight: bold; }
.check-fail   { color: #f38ba8; font-size: 14px; font-weight: bold; }
.check-wait   { color: #585b70; font-size: 14px; }
.check-detail { color: #6c7086; font-size: 11px; }
.cat-label    { color: #89b4fa; font-size: 11px; font-weight: bold; letter-spacing: 1px; margin-top: 4px; }

/* Plan items */
.plan-install { color: #a6e3a1; font-size: 13px; }
.plan-skip    { color: #585b70; font-size: 13px; }
.plan-update  { color: #f9e2af; font-size: 13px; }

/* Buttons */
.btn-primary {
    background-color: #8839ef; background-image: none;
    color: #ffffff; border: none; border-radius: 10px;
    padding: 10px 28px; font-size: 13px; font-weight: bold; min-width: 120px;
}
.btn-primary:hover   { background-color: #9947f7; background-image: none; }
.btn-primary:active  { background-color: #7028d4; background-image: none; }
.btn-primary:disabled { background-color: #313244; background-image: none; color: #45475a; }

.btn-success {
    background-color: #40a02b; background-image: none;
    color: #1e1e2e; border: none; border-radius: 10px;
    padding: 10px 28px; font-size: 13px; font-weight: bold;
}
.btn-success:hover  { background-color: #4caf33; background-image: none; }
.btn-success:active { background-color: #338022; background-image: none; }

.btn-secondary {
    background-color: #24273a; background-image: none;
    color: #a6adc8; border: 1px solid #363a4f;
    border-radius: 10px; padding: 10px 18px; font-size: 13px;
}
.btn-secondary:hover  { background-color: #313244; background-image: none; color: #cdd6f4; }
.btn-secondary:active { background-color: #1e1e2e; background-image: none; }

/* Progress */
progressbar trough {
    min-height: 8px; border-radius: 4px;
    background-color: #313244; background-image: none; border: none;
}
progressbar progress {
    min-height: 8px; border-radius: 4px;
    background-color: #8839ef; background-image: none;
}
progressbar.ok progress { background-color: #40a02b; background-image: none; }
progressbar.err progress { background-color: #f38ba8; background-image: none; }

/* Log */
.log-view {
    background-color: #11111b; color: #cdd6f4;
    font-family: monospace; font-size: 12px;
    border-radius: 8px; border: 1px solid #313244;
    padding: 8px;
}

/* Step indicator */
.step-active   { color: #cba6f7; font-weight: bold; font-size: 12px; }
.step-done     { color: #a6e3a1; font-size: 12px; }
.step-pending  { color: #45475a; font-size: 12px; }

/* Password */
entry {
    background-color: #24273a; background-image: none;
    color: #cdd6f4; border: 1px solid #363a4f;
    border-radius: 6px; padding: 8px 12px; font-size: 13px;
}
entry:focus { border-color: #8839ef; }

/* Status bar */
.status-bar { background-color: #181825; border-top: 1px solid #313244; padding: 6px 12px; }
.status-ok  { color: #a6e3a1; font-size: 12px; }
.status-err { color: #f38ba8; font-size: 12px; }
.status-run { color: #cba6f7; font-size: 12px; }
.status-inf { color: #6c7086; font-size: 12px; }

/* Welcome logo */
.logo-box { padding: 20px; }
.logo-title { color: #cba6f7; font-size: 32px; font-weight: bold; }
.logo-sub   { color: #6c7086; font-size: 14px; }
.desc-text  { color: #a6adc8; font-size: 13px; }

/* Separator */
separator { background-color: #313244; min-height: 1px; margin: 4px 0; }
"""

# ── System Checks ──────────────────────────────────────────────────────────────

def _run(*cmd):
    try:
        return subprocess.run(list(cmd), capture_output=True, text=True, timeout=5)
    except Exception:
        return None

CHECKS = [
    # (id, category, label, detail_fn)
    # category is shown as a section header
]

def check_kernel():
    r = _run("uname", "-r")
    v = r.stdout.strip() if r else "?"
    parts = v.split(".")
    ck = TR[_LANG]["checks"]
    try:
        maj, minor = int(parts[0]), int(parts[1])
        if maj > 5 or (maj == 5 and minor >= 11):
            lbl, det = ck["kernel_ok"](v)
        else:
            lbl, det = ck["kernel_warn"](v)
    except Exception:
        lbl, det = ck["kernel_unk"](v)
    st = "ok" if "ok" in lbl.lower() or maj > 5 or (maj == 5 and minor >= 11) else "warn"
    return st, lbl, det

def check_kernel():
    r = _run("uname", "-r")
    v = r.stdout.strip() if r else "?"
    parts = v.split(".")
    ck = TR[_LANG]["checks"]
    try:
        maj, minor = int(parts[0]), int(parts[1])
        if maj > 5 or (maj == 5 and minor >= 11):
            lbl_t, det = ck["kernel_ok"](v)
            return "ok", lbl_t, det
        lbl_t, det = ck["kernel_warn"](v)
        return "warn", lbl_t, det
    except Exception:
        lbl_t, det = ck["kernel_unk"](v)
        return "warn", lbl_t, det

def check_distro():
    r = _run("lsb_release", "-ds")
    distro = r.stdout.strip().strip('"') if r else "?"
    ck = TR[_LANG]["checks"]
    if "mint" in distro.lower() or "ubuntu" in distro.lower():
        lbl_t, det = ck["distro_ok"](distro)
        return "ok", lbl_t, det
    lbl_t, det = ck["distro_warn"](distro)
    return "warn", lbl_t, det

def check_apt():
    r = _run("which", "apt-get")
    ck = TR[_LANG]["checks"]
    if r and r.returncode == 0:
        return "ok", *ck["apt_ok"]
    return "fail", *ck["apt_fail"]

def check_usb_nkey():
    r = _run("lsusb")
    ck = TR[_LANG]["checks"]
    if r:
        known = {"1866": "N-KEY", "1869": "N-KEY (GL503)", "1854": "N-KEY (GL553)", "19b6": "N-KEY (GA503)"}
        for pid, name in known.items():
            if f"0b05:{pid}" in r.stdout:
                lbl_t, det = ck["usb_ok"](name, pid)
                return "ok", lbl_t, det
    return "fail", *ck["usb_fail"]

def check_sysfs():
    p = Path("/sys/class/leds/asus::kbd_backlight")
    ck = TR[_LANG]["checks"]
    if p.exists():
        bri = (p / "brightness").read_text().strip() if (p / "brightness").exists() else "?"
        mx  = (p / "max_brightness").read_text().strip() if (p / "max_brightness").exists() else "?"
        lbl_t, det = ck["sysfs_ok"](bri, mx)
        return "ok", lbl_t, det
    return "warn", *ck["sysfs_warn"]

def check_mod(name):
    def _check():
        r = _run("lsmod")
        ck = TR[_LANG]["checks"]
        if r and re.search(rf"^{name}\b", r.stdout, re.MULTILINE):
            lbl_t, det = ck["mod_ok"](name)
            return "ok", lbl_t, det
        lbl_t, det = ck["mod_fail"](name, f"sudo modprobe {name}")
        return "fail", lbl_t, det
    return _check

check_hid_asus = check_mod("hid_asus")
check_asus_wmi = check_mod("asus_wmi")
check_asus_nb  = check_mod("asus_nb_wmi")

def check_build_tools():
    missing = [t for t in ("gcc", "make", "git", "autoconf") if _run("which", t) is None or _run("which", t).returncode != 0]
    ck = TR[_LANG]["checks"]
    if not missing:
        return "ok", *ck["build_ok"]
    lbl_t, det = ck["build_warn"](", ".join(missing))
    return "warn", lbl_t, det

def check_libusb():
    r = _run("dpkg", "-l", "libusb-1.0-0-dev")
    ck = TR[_LANG]["checks"]
    if r and "ii" in r.stdout:
        return "ok", *ck["libusb_ok"]
    return "warn", *ck["libusb_warn"]

def check_python_gtk():
    ck = TR[_LANG]["checks"]
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gtk
        lbl_t, det = ck["pygtk_ok"](gi.__version__)
        return "ok", lbl_t, det
    except Exception as e:
        lbl_t, det = ck["pygtk_fail"](e)
        return "fail", lbl_t, det

def check_rogauracore():
    r = _run("which", "rogauracore")
    ck = TR[_LANG]["checks"]
    if r and r.returncode == 0:
        return "ok", *ck["rogaura_ok"]
    return "warn", *ck["rogaura_warn"]

def check_internet():
    ck = TR[_LANG]["checks"]
    try:
        socket.setdefaulttimeout(3)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect(("8.8.8.8", 53))
        return "ok", *ck["internet_ok"]
    except Exception:
        return "fail", *ck["internet_fail"]

def check_udev():
    rule = Path("/lib/udev/rules.d/90-rogauracore.rules")
    ck = TR[_LANG]["checks"]
    if rule.exists():
        lbl_t, det = ck["udev_ok"](rule)
        return "ok", lbl_t, det
    return "warn", *ck["udev_warn"]

def check_systemd_service():
    r = _run("systemctl", "is-enabled", "rog-rgb.service")
    ck = TR[_LANG]["checks"]
    if r and r.returncode == 0:
        return "ok", *ck["svc_ok"]
    return "warn", *ck["svc_warn"]

def check_install_script():
    ck = TR[_LANG]["checks"]
    if INSTALL_SH.exists():
        lbl_t, det = ck["script_ok"](INSTALL_SH)
        return "ok", lbl_t, det
    lbl_t, det = ck["script_fail"](INSTALL_SH)
    return "fail", lbl_t, det

def get_check_groups():
    _CHECK_FNS = {
        "kernel":        check_kernel,
        "distro":        check_distro,
        "apt":           check_apt,
        "internet":      check_internet,
        "usb":           check_usb_nkey,
        "sysfs":         check_sysfs,
        "hid":           check_hid_asus,
        "wmi":           check_asus_wmi,
        "nb":            check_asus_nb,
        "build":         check_build_tools,
        "libusb":        check_libusb,
        "pygtk":         check_python_gtk,
        "rogaura":       check_rogauracore,
        "script":        check_install_script,
        "udev":          check_udev,
        "svc":           check_systemd_service,
    }
    result = []
    for key, (cat_name, items) in _t("check_group_labels").items():
        result.append((cat_name, [(cid, lbl, _CHECK_FNS[cid]) for cid, lbl in items]))
    return result

CHECK_GROUPS = None  # Initialized at runtime via get_check_groups()


# ── Hilfsfunktionen ────────────────────────────────────────────────────────────

def apply_css():
    prov = Gtk.CssProvider()
    prov.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

def styled(widget, *classes):
    ctx = widget.get_style_context()
    for c in classes:
        ctx.add_class(c)
    return widget

def lbl(text, *classes, xalign=0.0, wrap=False):
    w = Gtk.Label(label=text)
    w.set_xalign(xalign)
    if wrap:
        w.set_line_wrap(True)
        w.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
    return styled(w, *classes)

def sep():
    s = Gtk.Separator()
    s.set_margin_top(4); s.set_margin_bottom(4)
    return s


# ── Haupt-Fenster ──────────────────────────────────────────────────────────────

class InstallerWindow(Gtk.ApplicationWindow):
    PAGES = ["welcome", "check", "plan", "install", "done"]

    def __init__(self, app):
        super().__init__(application=app, title="ROG RGB Installer")
        self.set_default_size(720, 580)
        self.set_resizable(False)
        apply_css()

        self._page_idx    = 0
        self._check_results = {}   # id → (status, label, detail)
        self._password    = ""
        self._install_ok  = None

        self._build_header()
        self._build_body()
        self.show_all()
        self._update_nav()

    # ── Header ─────────────────────────────────────────────────────────────────

    def _build_header(self):
        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title(_t("win_title"))
        hb.set_subtitle(_t("hb_subtitle"))

        # Step indicator (dots)
        dot_box = Gtk.Box(spacing=6, valign=Gtk.Align.CENTER)
        self._dots = []
        labels = _t("dots")
        for i, name in enumerate(labels):
            d = Gtk.Label(label=f"● {name}" if i == 0 else f"○ {name}")
            d.get_style_context().add_class("step-active" if i == 0 else "step-pending")
            dot_box.pack_start(d, False, False, 0)
            self._dots.append(d)
        hb.set_custom_title(dot_box)

        lang_btn = Gtk.Button(label=_t("lang_btn"))
        lang_btn.set_tooltip_text(_t("lang_tooltip"))
        lang_btn.connect("clicked", self._on_lang_toggle)
        hb.pack_end(lang_btn)

        self.set_titlebar(hb)

    def _update_dots(self):
        for i, d in enumerate(self._dots):
            ctx = d.get_style_context()
            for c in ("step-active", "step-done", "step-pending"):
                ctx.remove_class(c)
            if i < self._page_idx:
                d.set_label(d.get_label().replace("○", "✓"))
                ctx.add_class("step-done")
            elif i == self._page_idx:
                ctx.add_class("step-active")
            else:
                ctx.add_class("step-pending")

    # ── Body ───────────────────────────────────────────────────────────────────

    def _build_body(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(root)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(220)

        self.stack.add_named(self._build_welcome(), "welcome")
        self.stack.add_named(self._build_check(),   "check")
        self.stack.add_named(self._build_plan(),    "plan")
        self.stack.add_named(self._build_install(), "install")
        self.stack.add_named(self._build_done(),    "done")
        root.pack_start(self.stack, True, True, 0)

        # Navigation bar
        nav = Gtk.Box(spacing=10)
        nav.set_margin_start(16); nav.set_margin_end(16)
        nav.set_margin_top(10);   nav.set_margin_bottom(12)
        nav.get_style_context().add_class("status-bar")

        self.status_lbl = lbl(_t("status_welcome"), "status-inf")
        self.back_btn   = Gtk.Button(label=_t("nav_back"))
        self.next_btn   = Gtk.Button(label=_t("nav_next"))
        styled(self.back_btn, "btn-secondary")
        styled(self.next_btn, "btn-primary")
        self.back_btn.connect("clicked", self._on_back)
        self.next_btn.connect("clicked", self._on_next)

        nav.pack_start(self.status_lbl, True, True, 4)
        nav.pack_end(self.next_btn, False, False, 0)
        nav.pack_end(self.back_btn, False, False, 0)
        root.pack_start(nav, False, False, 0)

    # ── Page 1: Willkommen ─────────────────────────────────────────────────────

    def _build_welcome(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_start(32); page.set_margin_end(32)
        page.set_margin_top(24);   page.set_margin_bottom(0)

        # Logo
        logo_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, halign=Gtk.Align.CENTER)
        logo_box.set_margin_bottom(24)
        logo_box.pack_start(lbl("⚡ ROG RGB", "logo-title", xalign=0.5), False, False, 0)
        logo_box.pack_start(lbl(_t("page1_sub"), "logo-sub", xalign=0.5), False, False, 0)
        page.pack_start(logo_box, False, False, 0)

        # Info-Karten Reihe
        row = Gtk.Box(spacing=0, homogeneous=True)
        page.pack_start(row, False, False, 0)

        for icon, title, text in _t("p1_cards"):
            c = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            c.get_style_context().add_class("card")
            c.set_margin_start(4); c.set_margin_end(4)
            c.pack_start(lbl(icon, xalign=0.5), False, False, 0)
            c.pack_start(lbl(title, xalign=0.5), False, False, 0)
            c.pack_start(lbl(text,  "check-detail", xalign=0.5, wrap=True), False, False, 0)
            row.pack_start(c, True, True, 0)

        page.pack_start(Gtk.Box(), True, True, 0)  # spacer

        note = lbl(_t("page1_note"), "desc-text", xalign=0.5, wrap=True)
        note.set_margin_bottom(16)
        page.pack_start(note, False, False, 0)

        return page

    # ── Page 2: Hardware & Software Diagnose ───────────────────────────────────

    def _build_check(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_start(16); outer.set_margin_end(16)
        outer.set_margin_top(12);   outer.set_margin_bottom(0)

        title_row = Gtk.Box(spacing=10)
        title_row.pack_start(lbl(_t("page2_title"), "page-title"), False, False, 0)
        self.check_spinner = Gtk.Spinner()
        self.check_spinner.set_size_request(24, 24)
        title_row.pack_start(self.check_spinner, False, False, 0)
        outer.pack_start(title_row, False, False, 4)
        outer.pack_start(lbl(_t("page2_sub"), "page-sub"), False, False, 8)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)

        self._check_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self._check_box.set_margin_start(4); self._check_box.set_margin_end(4)
        self._check_rows = {}  # id → (icon_lbl, label_lbl, detail_lbl)

        for cat_name, checks in get_check_groups():
            # Kategorie-Header
            cat_lbl = lbl(cat_name, "cat-label")
            cat_lbl.set_margin_top(8)
            self._check_box.pack_start(cat_lbl, False, False, 0)

            for check_id, check_label, _ in checks:
                row = Gtk.Box(spacing=10, margin_start=8)
                row.get_style_context().add_class("check-row")

                icon_lbl   = styled(Gtk.Label(label="○"), "check-wait")
                name_lbl   = styled(Gtk.Label(label=check_label), "check-label")
                detail_lbl = styled(Gtk.Label(label=""), "check-detail")
                name_lbl.set_xalign(0); detail_lbl.set_xalign(0)

                info_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
                info_col.pack_start(name_lbl, False, False, 0)
                info_col.pack_start(detail_lbl, False, False, 0)

                row.pack_start(icon_lbl, False, False, 0)
                row.pack_start(info_col, True, True, 0)
                self._check_box.pack_start(row, False, False, 0)
                self._check_rows[check_id] = (icon_lbl, name_lbl, detail_lbl)

        scroll.add(self._check_box)
        outer.pack_start(scroll, True, True, 0)

        # Zusammenfassung
        self.check_summary = lbl("", "status-inf")
        self.check_summary.set_margin_top(8)
        outer.pack_start(self.check_summary, False, False, 0)

        return outer

    def _run_checks(self):
        """Läuft in eigenem Thread; aktualisiert GUI via GLib.idle_add."""
        GLib.idle_add(self.check_spinner.start)
        GLib.idle_add(self.next_btn.set_sensitive, False)

        all_checks = [(cid, cfn) for _, grp in CHECK_GROUPS for cid, _, cfn in grp]

        for check_id, check_fn in all_checks:
            try:
                status, label, detail = check_fn()
            except Exception as e:
                status, label, detail = "fail", "Fehler", str(e)

            self._check_results[check_id] = (status, label, detail)

            def _update(cid=check_id, st=status, lbl_text=label, det=detail):
                icon_lbl, name_lbl, detail_lbl = self._check_rows[cid]
                icons = {"ok": "✓", "warn": "⚠", "fail": "✗"}
                classes = {"ok": "check-ok", "warn": "check-warn", "fail": "check-fail"}
                icon_lbl.set_text(icons.get(st, "○"))
                for c in ("check-ok", "check-warn", "check-fail", "check-wait"):
                    icon_lbl.get_style_context().remove_class(c)
                icon_lbl.get_style_context().add_class(classes.get(st, "check-wait"))
                name_lbl.set_text(lbl_text)
                if det:
                    detail_lbl.set_text(det)
                return False
            GLib.idle_add(_update)
            time.sleep(0.08)

        # Zusammenfassung
        fails = sum(1 for s, _, _ in self._check_results.values() if s == "fail")
        warns = sum(1 for s, _, _ in self._check_results.values() if s == "warn")

        def _done():
            self.check_spinner.stop()
            if fails == 0 and warns == 0:
                self.check_summary.set_text(_t("check_all_ok"))
                self.check_summary.get_style_context().remove_class("status-err")
                self.check_summary.get_style_context().add_class("status-ok")
            elif fails == 0:
                self.check_summary.set_text(_t("check_warns")(warns))
                self.check_summary.get_style_context().remove_class("status-ok")
                self.check_summary.get_style_context().add_class("status-run")
            else:
                self.check_summary.set_text(_t("check_fails")(fails, warns))
                self.check_summary.get_style_context().add_class("status-err")
            self.next_btn.set_sensitive(True)
            self._build_plan_content()
            return False
        GLib.idle_add(_done)

    # ── Page 3: Installationsplan ──────────────────────────────────────────────

    def _build_plan(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_start(16); outer.set_margin_end(16)
        outer.set_margin_top(12);   outer.set_margin_bottom(0)

        outer.pack_start(lbl(_t("page3_title"), "page-title"), False, False, 4)
        outer.pack_start(lbl(_t("page3_sub"), "page-sub"), False, False, 8)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        self._plan_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self._plan_box.set_margin_start(4)
        scroll.add(self._plan_box)
        outer.pack_start(scroll, True, True, 0)

        # sudo-Hinweis
        self.sudo_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.sudo_box.set_margin_top(10)
        outer.pack_start(self.sudo_box, False, False, 0)

        return outer

    def _build_plan_content(self):
        """Wird nach den Checks aufgebaut (läuft im GUI-Thread via idle_add)."""
        for child in self._plan_box.get_children():
            self._plan_box.remove(child)

        PLAN_ITEMS = _t("plan_items")

        def add_section(title):
            l = lbl(title, "cat-label")
            l.set_margin_top(8)
            self._plan_box.pack_start(l, False, False, 0)

        add_section(_t("plan_section"))
        for _, display, check_id, detail in PLAN_ITEMS:
            status = self._check_results.get(check_id, ("warn",))[0] if check_id else "warn"
            if status == "ok":
                icon, cls = _t("plan_present"), "plan-skip"
            elif status == "fail":
                icon, cls = _t("plan_install"), "plan-install"
            else:
                icon, cls = _t("plan_update"), "plan-update"

            row = Gtk.Box(spacing=10, margin_start=8)
            row.pack_start(styled(Gtk.Label(label=display), cls), False, False, 0)
            row.pack_start(styled(Gtk.Label(label=icon), "check-detail"), False, False, 0)
            self._plan_box.pack_start(row, False, False, 0)
            if detail:
                d = styled(Gtk.Label(label=f"     {detail}"), "check-detail")
                d.set_xalign(0)
                self._plan_box.pack_start(d, False, False, 0)

        self._plan_box.show_all()

        # sudo-Bereich aufbauen
        for child in self.sudo_box.get_children():
            self.sudo_box.remove(child)

        if os.geteuid() == 0:
            note = lbl(_t("sudo_root"), "status-ok")
            self.sudo_box.pack_start(note, False, False, 0)
            self._password = ""
        else:
            # Prüfe ob sudo ohne Passwort geht (Cache)
            cached = subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0
            if cached:
                note = lbl(_t("sudo_cached"), "status-ok")
                self.sudo_box.pack_start(note, False, False, 0)
                self._password = "__cached__"
            else:
                note = lbl(_t("sudo_ask"), "status-run")
                self.sudo_box.pack_start(note, False, False, 0)
                pw_row = Gtk.Box(spacing=8)
                self._pw_entry = Gtk.Entry()
                self._pw_entry.set_visibility(False)
                self._pw_entry.set_placeholder_text(_t("pw_placeholder"))
                self._pw_entry.set_hexpand(True)
                self._pw_entry.connect("activate", lambda _: self.next_btn.emit("clicked"))
                pw_row.pack_start(self._pw_entry, True, True, 0)
                self.sudo_box.pack_start(pw_row, False, False, 0)

        self.sudo_box.show_all()

    # ── Page 4: Installation ───────────────────────────────────────────────────

    def _build_install(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_start(16); outer.set_margin_end(16)
        outer.set_margin_top(12);   outer.set_margin_bottom(0)

        outer.pack_start(lbl(_t("page4_title"), "page-title"), False, False, 4)

        # Schritt-Anzeige
        steps_box = Gtk.Box(spacing=16)
        steps_box.set_margin_top(6); steps_box.set_margin_bottom(6)
        self._step_labels = []
        step_names = _t("step_names")
        for name in step_names:
            sl = styled(Gtk.Label(label=f"○ {name}"), "step-pending")
            steps_box.pack_start(sl, False, False, 0)
            self._step_labels.append(sl)
        outer.pack_start(steps_box, False, False, 0)

        # Fortschrittsbalken
        self.prog_bar = Gtk.ProgressBar()
        self.prog_bar.set_fraction(0)
        self.prog_bar.set_margin_bottom(8)
        outer.pack_start(self.prog_bar, False, False, 4)

        # Live-Log
        outer.pack_start(lbl(_t("page4_output"), "card-title"), False, False, 0)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_view.get_style_context().add_class("log-view")
        self.log_buf = self.log_view.get_buffer()

        # Farb-Tags für Log
        self.log_buf.create_tag("ok",   foreground="#a6e3a1")
        self.log_buf.create_tag("err",  foreground="#f38ba8")
        self.log_buf.create_tag("warn", foreground="#f9e2af")
        self.log_buf.create_tag("step", foreground="#cba6f7", weight=Pango.Weight.BOLD)
        self.log_buf.create_tag("dim",  foreground="#45475a")

        scroll.add(self.log_view)
        outer.pack_start(scroll, True, True, 0)

        return outer

    def _log(self, text, tag=None):
        def _do():
            end = self.log_buf.get_end_iter()
            if tag:
                self.log_buf.insert_with_tags_by_name(end, text + "\n", tag)
            else:
                self.log_buf.insert(end, text + "\n")
            # Scroll to bottom
            adj = self.log_view.get_parent().get_vadjustment()
            adj.set_value(adj.get_upper())
            return False
        GLib.idle_add(_do)

    def _set_step(self, idx):
        def _do():
            for i, sl in enumerate(self._step_labels):
                ctx = sl.get_style_context()
                for c in ("step-active", "step-done", "step-pending"):
                    ctx.remove_class(c)
                name = sl.get_label().lstrip("○●✓ ")
                if i < idx:
                    sl.set_label(f"✓ {name}"); ctx.add_class("step-done")
                elif i == idx:
                    sl.set_label(f"● {name}"); ctx.add_class("step-active")
                else:
                    sl.set_label(f"○ {name}"); ctx.add_class("step-pending")
            self.prog_bar.set_fraction((idx) / len(self._step_labels))
            return False
        GLib.idle_add(_do)

    def _run_install(self):
        if not INSTALL_SH.exists():
            self._log(f"FEHLER: {INSTALL_SH} nicht gefunden!", "err")
            GLib.idle_add(self._install_failed)
            return

        pw = self._password

        # Befehlsaufbau
        if os.geteuid() == 0:
            cmd = ["bash", str(INSTALL_SH)]
        elif pw == "__cached__":
            cmd = ["sudo", "-n", "bash", str(INSTALL_SH)]
        else:
            cmd = ["sudo", "-S", "bash", str(INSTALL_SH)]

        env = os.environ.copy()
        env["TERM"] = "xterm"

        self._log(_t("log_start"), "step")
        self._log(_t("log_script_path")(INSTALL_SH), "dim")

        try:
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE if (pw and pw != "__cached__") else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                cwd=str(SCRIPT_DIR),
                bufsize=1
            )

            if pw and pw not in ("", "__cached__"):
                try:
                    proc.stdin.write(pw + "\n")
                    proc.stdin.flush()
                    proc.stdin.close()
                except Exception:
                    pass

            # Step-Schlüsselwörter für Fortschritt
            step_triggers = [
                ("Abhängigkeiten", 0),
                ("rogauracore aus Quellcode", 1),
                ("Skript", 2),
                ("sudo-Berechtigung|udev", 3),
                ("systemd", 4),
                ("Funktionstest", 5),
            ]
            ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

            for raw_line in proc.stdout:
                line = ansi_escape.sub("", raw_line.rstrip())
                if not line:
                    continue

                # Farbe bestimmen
                tag = None
                ll = line.lower()
                if any(x in ll for x in ("[ok]", "erfolgreich", "✓", "ok ")):
                    tag = "ok"
                elif any(x in ll for x in ("[fehler]", "error", "failed", "✗")):
                    tag = "err"
                elif any(x in ll for x in ("[warnung]", "warn", "⚠")):
                    tag = "warn"
                elif line.startswith("  [>>]") or "Schritt" in line or "step" in ll:
                    tag = "step"

                self._log(line, tag)

                # Fortschritt aktualisieren
                for pattern, step_idx in step_triggers:
                    if re.search(pattern, line, re.IGNORECASE):
                        self._set_step(step_idx)
                        break

            proc.wait()
            rc = proc.returncode

        except Exception as e:
            self._log(_t("log_exec_err")(e), "err")
            rc = -1

        def _finish():
            if rc == 0:
                self._install_ok = True
                for sl in self._step_labels:
                    ctx = sl.get_style_context()
                    for c in ("step-active", "step-done", "step-pending"):
                        ctx.remove_class(c)
                    ctx.add_class("step-done")
                    name = sl.get_label().lstrip("○●✓ ")
                    sl.set_label(f"✓ {name}")
                self.prog_bar.set_fraction(1.0)
                self.prog_bar.get_style_context().add_class("ok")
                self._log("", None)
                self._log(_t("log_ok"), "ok")
                self._build_done_content(True)
                self._set_status(_t("status_done_ok"), "status-ok")
            else:
                self._install_ok = False
                self.prog_bar.get_style_context().add_class("err")
                self._log(f"", None)
                self._log(_t("log_err")(rc), "err")
                self._log(_t("log_warn"), "warn")
                self._build_done_content(False)
                self._set_status(_t("status_done_err"), "status-err")
            self.next_btn.set_sensitive(True)
            self.next_btn.set_label(_t("nav_next"))
            return False
        GLib.idle_add(_finish)

    def _install_failed(self):
        self.prog_bar.get_style_context().add_class("err")
        self._log(_t("log_no_script"), "err")
        self._set_status(_t("status_script_miss"), "status-err")
        self.next_btn.set_sensitive(True)

    # ── Page 5: Fertig ─────────────────────────────────────────────────────────

    def _build_done(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_start(32); outer.set_margin_end(32)
        outer.set_margin_top(20);   outer.set_margin_bottom(0)
        self._done_outer = outer
        return outer

    def _build_done_content(self, success):
        for child in self._done_outer.get_children():
            self._done_outer.remove(child)

        if success:
            icon = "🎉"; title = _t("done_ok_title")
            sub = _t("done_ok_sub")
            items = _t("done_ok_items")
            title_cls = "status-ok"
        else:
            icon = "⚠"; title = _t("done_err_title")
            sub = _t("done_err_sub")
            items = _t("done_err_items") + [("→", _t("done_err_manual")(INSTALL_SH))]
            title_cls = "status-err"

        self._done_outer.pack_start(lbl(f"{icon}  {title}", "page-title"), False, False, 4)
        self._done_outer.pack_start(lbl(sub, "page-sub"), False, False, 8)

        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card.get_style_context().add_class("card")
        for key, val in items:
            row = Gtk.Box(spacing=10)
            row.pack_start(styled(Gtk.Label(label=key), "check-ok" if success else "check-warn"), False, False, 0)
            row.pack_start(lbl(val, "check-detail"), True, True, 0)
            card.pack_start(row, False, False, 0)
        self._done_outer.pack_start(card, False, False, 0)

        self._done_outer.pack_start(Gtk.Box(), True, True, 0)

        # Aktions-Buttons
        btn_row = Gtk.Box(spacing=10, halign=Gtk.Align.CENTER)
        btn_row.set_margin_bottom(16)
        if success:
            gui_btn = Gtk.Button(label=_t("btn_launch_gui"))
            styled(gui_btn, "btn-success")
            gui_btn.connect("clicked", self._launch_gui)
            btn_row.pack_start(gui_btn, False, False, 0)
        close_btn = Gtk.Button(label=_t("btn_close"))
        styled(close_btn, "btn-secondary")
        close_btn.connect("clicked", lambda _: self.get_application().quit())
        btn_row.pack_start(close_btn, False, False, 0)
        self._done_outer.pack_start(btn_row, False, False, 0)

        self._done_outer.show_all()

    def _launch_gui(self, _):
        gui = Path("/usr/local/bin/rog-rgb-gui")
        if not gui.exists():
            gui = SCRIPT_DIR / "rog-rgb-gui.py"
        try:
            subprocess.Popen(["python3", str(gui)] if gui.suffix == ".py" else [str(gui)])
        except Exception as e:
            self._set_status(f"Error: {e}", "status-err")

    # ── Navigation ─────────────────────────────────────────────────────────────

    def _on_lang_toggle(self, _):
        global _LANG
        _LANG = "en" if _LANG == "de" else "de"
        _save_lang(_LANG)
        os.execv(sys.executable, [sys.executable] + sys.argv)

    def _update_nav(self):
        self._update_dots()
        page = self.PAGES[self._page_idx]
        self.stack.set_visible_child_name(page)

        # Back-Button
        self.back_btn.set_sensitive(self._page_idx > 0 and self._page_idx < 4)

        # Next-Button
        if page == "welcome":
            self.next_btn.set_label(_t("nav_check"))
            self.next_btn.set_sensitive(True)
        elif page == "check":
            self.next_btn.set_label("Weiter  ▶")
            self.next_btn.set_sensitive(False)  # Wird nach Checks aktiviert
        elif page == "plan":
            self.next_btn.set_label(_t("nav_install"))
            self.next_btn.set_sensitive(True)
        elif page == "install":
            self.next_btn.set_label(_t("nav_wait"))
            self.next_btn.set_sensitive(False)
        elif page == "done":
            self.next_btn.set_label(_t("nav_close"))
            self.next_btn.set_sensitive(True)
            self.back_btn.set_sensitive(False)

    def _set_status(self, msg, cls="status-inf"):
        def _do():
            self.status_lbl.set_text(msg)
            ctx = self.status_lbl.get_style_context()
            for c in ("status-ok", "status-err", "status-run", "status-inf"):
                ctx.remove_class(c)
            ctx.add_class(cls)
            return False
        GLib.idle_add(_do)

    def _on_next(self, _):
        page = self.PAGES[self._page_idx]

        if page == "welcome":
            self._page_idx = 1
            self._update_nav()
            self._set_status(_t("status_checking"), "status-run")
            threading.Thread(target=self._run_checks, daemon=True).start()

        elif page == "check":
            self._page_idx = 2
            self._update_nav()
            self._set_status(_t("status_plan"), "status-inf")

        elif page == "plan":
            # Passwort holen
            if hasattr(self, "_pw_entry"):
                self._password = self._pw_entry.get_text()
            elif self._password == "":
                pass  # root oder cached
            self._page_idx = 3
            self._update_nav()
            self._set_status(_t("status_running"), "status-run")
            threading.Thread(target=self._run_install, daemon=True).start()

        elif page == "install":
            self._page_idx = 4
            self._update_nav()
            self._set_status(_t("status_done_ok") if self._install_ok else _t("status_done_err"), "status-ok" if self._install_ok else "status-err")

        elif page == "done":
            self.get_application().quit()

    def _on_back(self, _):
        if self._page_idx > 0:
            self._page_idx -= 1
            self._update_nav()
            self._set_status("", "status-inf")


# ── App ────────────────────────────────────────────────────────────────────────

class InstallerApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="de.rogscripts.installer")

    def do_activate(self):
        InstallerWindow(self).present()


if __name__ == "__main__":
    InstallerApp().run(sys.argv)
