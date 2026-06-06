#!/usr/bin/env bash
# ============================================================
#  ROG Fan — Install Script  |  Installations-Script
#  ASUS ROG Lüftersteuerung (asusctl) · Linux Mint / Ubuntu
#
#  Usage / Verwendung:
#    bash install-rog-fan.sh
#    bash install-rog-fan.sh --uninstall
#    ROG_LANG=en bash install-rog-fan.sh   (English output)
#
#  Installs / Installiert:
#    • asusctl (PPA bevorzugt, Source-Build als Fallback)
#    • asusd systemd Daemon
#    • lm-sensors + drivetemp
#    • sudoers-Regel für platform_profile / throttle_thermal_policy
#    • rog-fan-resume.service (Hotfix für Resume-Bug)
#    • Default-Konfiguration in ~/.config/rog-fan/
#
#  Disables / Deaktiviert (reversibel):
#    • power-profiles-daemon (konkurriert mit asusd)
#
#  Hinweis: rog-fan-Wrapper (v0.4) und GUI (v0.5) folgen noch.
# ============================================================
set -euo pipefail

# ── Auto-relaunch in terminal if started by double-click ─────
if [[ ! -t 0 ]] && [[ ! -t 1 ]]; then
    SELF="$(realpath "$0")"
    WAIT='echo; read -rp "  Fertig – Enter zum Schließen / Done – press Enter: "'
    CMD="sudo bash \"$SELF\" $(printf '%q ' "$@"); $WAIT"
    for T in x-terminal-emulator gnome-terminal xfce4-terminal mate-terminal tilix xterm; do
        if command -v "$T" &>/dev/null; then
            case "$T" in
                gnome-terminal|tilix) exec "$T" -- bash -c "$CMD" ;;
                *)                    exec "$T" -e "bash -c '$CMD'" ;;
            esac
        fi
    done
    # Fallback: kein Terminal gefunden
    notify-send "ROG Fan Installer" "Kein Terminal gefunden – bitte manuell ausführen:\nsudo bash $SELF" 2>/dev/null || true
    exit 1
fi

# ── Language / Sprache: de (Deutsch, default) | en (English) ─
ROG_LANG="${ROG_LANG:-de}"

# ── Farben / Colors ──────────────────────────────────────────
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
CYN='\033[1;36m'; MAG='\033[1;35m'; WHT='\033[1;37m'
DIM='\033[2m'; RST='\033[0m'

if [[ "$ROG_LANG" == "en" ]]; then
    OK="  ${GRN}[OK]${RST}";   ERR="  ${RED}[ERROR]${RST}"
    INFO="  ${CYN}[INFO]${RST}"; STEP="  ${MAG}[>>]${RST}"
    WARN="  ${YLW}[!]${RST}"
    T_HEADER_1="ROG Fan Installation Script"
    T_HEADER_2="ASUS ROG Fan Control (asusctl) for Linux"
    T_TARGET_USER="Target user"
    T_HOME_DIR="Home directory"
    T_CHECK_PREREQ="Checking prerequisites"
    T_APT_OK="apt available"
    T_KERNEL_OK="Kernel supports ASUS platform_profile"
    T_KERNEL_WARN="Kernel < 5.15 — platform_profile support may be limited"
    T_PP_OK="platform_profile interface present"
    T_PP_ERR="System does NOT expose /sys/firmware/acpi/platform_profile — unsupported"
    T_WMI_OK="asus-nb-wmi module loaded"
    T_WMI_WARN="asus-nb-wmi module NOT loaded — asusctl may be limited"
    T_CONFLICT_STEP="Checking for conflicting services"
    T_CONFLICT_NBFC="nbfc / nbfc-linux detected — conflicts with asus_wmi. Remove first:"
    T_CONFLICT_FANCTRL="fancontrol service active — please stop manually:"
    T_CONFLICT_OK="No blocking conflicts detected"
    T_STEP_DEPS="Installing dependencies"
    T_DEPS_OK="Dependencies installed (lm-sensors, curl, gnupg, ...)"
    T_SENSORS_RUN="Running sensors-detect (auto)..."
    T_SENSORS_OK="lm-sensors initialised"
    T_DRIVETEMP_OK="drivetemp module loaded + persisted in /etc/modules"
    T_STEP_ASUSCTL="Installing asusctl"
    T_PPA_TRY="Trying PPA: ppa:asus-linux/stable"
    T_PPA_OK="asusctl installed from PPA"
    T_PPA_FAIL="PPA install failed — falling back to source build"
    T_PPA_SKIP="No PPA for Ubuntu codename"
    T_PPA_SKIP2="building from source directly"
    T_BUILD_DEPS="Installing build dependencies (rust, cargo, gcc, ...)"
    T_BUILD_CLONE="Cloning asusctl repo to /tmp/asusctl-build"
    T_BUILD_COMPILE="Compiling asusctl (this can take several minutes)..."
    T_BUILD_OK="asusctl built and installed from source"
    T_ASUSCTL_VERIFY_FAIL="asusctl installation failed — neither PPA nor source build worked"
    T_STEP_PPD="Disabling power-profiles-daemon (reversible)"
    T_PPD_DISABLED="power-profiles-daemon disabled (still installed, not purged)"
    T_PPD_REENABLE="Re-enable later via: sudo systemctl enable --now power-profiles-daemon"
    T_PPD_NONE="power-profiles-daemon not active — nothing to do"
    T_STEP_ASUSD="Enabling asusd service"
    T_ASUSD_OK="asusd is active"
    T_ASUSD_FAIL="asusd failed to start — check: systemctl status asusd"
    T_STEP_SUDO="Setting up sudo rule for platform_profile"
    T_SUDO_OK="sudoers rule /etc/sudoers.d/rog-fan validated and installed"
    T_SUDO_FAIL="sudoers syntax check failed — rule removed"
    T_STEP_RESUME="Creating resume service (Hotfix for resume bug)"
    T_RESUME_OK="rog-fan-resume.service enabled"
    T_STEP_BOOT="Setting up boot service (restores profile at boot)"
    T_BOOT_OK="rog-fan-boot.service enabled"
    T_STEP_DEPLOY="Deploying Suite components (rog-fan, rog-fan-gui, rog-fan-keyd)"
    T_DEPLOY_OK="Suite components installed to /usr/local/bin/"
    T_DEPLOY_MISSING="Source file missing — skipping:"
    T_STEP_KEYD="Setting up Fan-Hotkey daemon (KEY_PROG4 + OSD)"
    T_KEYD_EVDEV_OK="python3-evdev installed"
    T_KEYD_INPUT_OK="User added to 'input' group (active after re-login)"
    T_KEYD_INPUT_ALREADY="User already in 'input' group"
    T_KEYD_SERVICE_OK="rog-fan-keyd user service installed and enabled"
    T_KEYD_SERVICE_FAIL="rog-fan-keyd service could not be enabled (run manually: systemctl --user enable --now rog-fan-keyd.service)"
    T_STEP_DESKTOP="Creating menu entries (.desktop)"
    T_DESKTOP_OK=".desktop entries installed (rog-fan-gui)"
    T_STEP_CFG="Setting up default configuration"
    T_CFG_DEFAULT="Default profile set to: balanced"
    T_CFG_KEPT="Existing profile configuration kept"
    T_STEP_TEST="Functional test"
    T_TEST_OK="asusctl works — profile applied"
    T_TEST_WARN="asusctl command syntax differs in this version — applied directly via sysfs"
    T_CURRENT_PROFILE="Current platform_profile"
    T_DONE_TITLE="Installation completed successfully!"
    T_DONE_NOTE="All components are installed: rog-fan (terminal), rog-fan-gui (GTK), rog-fan-keyd (hotkey + OSD)."
    T_DONE_CMDS="Available right now:"
    # T_DONE_FUTURE removed — all components are now installed
    T_DONE_LANG="Switch language: ROG_LANG=en  or  ROG_LANG=de"
    T_UNINSTALL_TITLE="Uninstalling..."
    T_UNINST_RESUME="Disabling and removing rog-fan-resume.service"
    T_UNINST_RESUME_OK="rog-fan-resume.service removed"
    T_UNINST_SUDO="Removing sudoers rule"
    T_UNINST_SUDO_OK="sudoers rule removed"
    T_UNINST_PPD="Re-enabling power-profiles-daemon"
    T_UNINST_PPD_OK="power-profiles-daemon re-enabled"
    T_UNINST_PPD_SKIP="power-profiles-daemon not installed — skipped"
    T_UNINST_ASUSD="Disabling asusd"
    T_UNINST_ASUSD_OK="asusd disabled"
    T_UNINST_ASK="Remove asusctl package as well? [y/N]: "
    T_UNINST_ASUSCTL_OK="asusctl removed"
    T_UNINST_ASUSCTL_KEPT="asusctl kept installed"
    T_UNINST_DONE="Uninstallation complete."
    T_UNINST_NOTE1="Configuration in"
    T_UNINST_NOTE2="was NOT deleted."
    T_UNINST_NOTE3="To remove completely:"
    T_ROOT_ERR="This script must be run with sudo:"
    T_APT_ERR="Only Ubuntu/Debian/Linux-Mint-based systems supported (apt missing)."
else
    OK="  ${GRN}[OK]${RST}";   ERR="  ${RED}[FEHLER]${RST}"
    INFO="  ${CYN}[INFO]${RST}"; STEP="  ${MAG}[>>]${RST}"
    WARN="  ${YLW}[!]${RST}"
    T_HEADER_1="ROG Fan Installations-Script"
    T_HEADER_2="ASUS ROG Lüftersteuerung (asusctl) für Linux"
    T_TARGET_USER="Ziel-Benutzer"
    T_HOME_DIR="Home-Verzeichnis"
    T_CHECK_PREREQ="Systemvoraussetzungen prüfen"
    T_APT_OK="apt verfügbar"
    T_KERNEL_OK="Kernel unterstützt ASUS platform_profile"
    T_KERNEL_WARN="Kernel < 5.15 — platform_profile-Unterstützung evtl. eingeschränkt"
    T_PP_OK="platform_profile-Interface vorhanden"
    T_PP_ERR="System bietet /sys/firmware/acpi/platform_profile NICHT — nicht unterstützt"
    T_WMI_OK="asus-nb-wmi Modul geladen"
    T_WMI_WARN="asus-nb-wmi Modul NICHT geladen — asusctl evtl. eingeschränkt"
    T_CONFLICT_STEP="Konflikt-Prüfung auf konkurrierende Dienste"
    T_CONFLICT_NBFC="nbfc / nbfc-linux gefunden — kollidiert mit asus_wmi. Bitte erst entfernen:"
    T_CONFLICT_FANCTRL="fancontrol-Service aktiv — bitte manuell stoppen:"
    T_CONFLICT_OK="Keine blockierenden Konflikte gefunden"
    T_STEP_DEPS="Abhängigkeiten installieren"
    T_DEPS_OK="Abhängigkeiten installiert (lm-sensors, curl, gnupg, ...)"
    T_SENSORS_RUN="Führe sensors-detect (auto) aus..."
    T_SENSORS_OK="lm-sensors initialisiert"
    T_DRIVETEMP_OK="drivetemp-Modul geladen + in /etc/modules eingetragen"
    T_STEP_ASUSCTL="asusctl installieren"
    T_PPA_TRY="Versuche PPA: ppa:asus-linux/stable"
    T_PPA_OK="asusctl aus PPA installiert"
    T_PPA_FAIL="PPA-Installation fehlgeschlagen — wechsle auf Source-Build"
    T_PPA_SKIP="Kein PPA für Ubuntu-Codename"
    T_PPA_SKIP2="baue direkt aus dem Quellcode"
    T_BUILD_DEPS="Build-Abhängigkeiten installieren (rust, cargo, gcc, ...)"
    T_BUILD_CLONE="Klone asusctl-Repository nach /tmp/asusctl-build"
    T_BUILD_COMPILE="Kompiliere asusctl (kann mehrere Minuten dauern)..."
    T_BUILD_OK="asusctl aus Quellcode gebaut und installiert"
    T_ASUSCTL_VERIFY_FAIL="asusctl-Installation fehlgeschlagen — weder PPA noch Source-Build erfolgreich"
    T_STEP_PPD="power-profiles-daemon deaktivieren (reversibel)"
    T_PPD_DISABLED="power-profiles-daemon deaktiviert (weiter installiert, nicht entfernt)"
    T_PPD_REENABLE="Reaktivierung später via: sudo systemctl enable --now power-profiles-daemon"
    T_PPD_NONE="power-profiles-daemon nicht aktiv — nichts zu tun"
    T_STEP_ASUSD="asusd-Service aktivieren"
    T_ASUSD_OK="asusd ist aktiv"
    T_ASUSD_FAIL="asusd konnte nicht gestartet werden — prüfe: systemctl status asusd"
    T_STEP_SUDO="sudo-Regel für platform_profile einrichten"
    T_SUDO_OK="sudoers-Regel /etc/sudoers.d/rog-fan validiert und installiert"
    T_SUDO_FAIL="sudoers Syntax-Prüfung fehlgeschlagen — Regel entfernt"
    T_STEP_RESUME="Resume-Service anlegen (Hotfix für Resume-Bug)"
    T_RESUME_OK="rog-fan-resume.service aktiviert"
    T_STEP_BOOT="systemd Boot-Service einrichten (stellt Profil beim Hochfahren wieder her)"
    T_BOOT_OK="rog-fan-boot.service aktiviert"
    T_STEP_DEPLOY="Suite-Komponenten ausrollen (rog-fan, rog-fan-gui, rog-fan-keyd)"
    T_DEPLOY_OK="Suite-Komponenten nach /usr/local/bin/ installiert"
    T_DEPLOY_MISSING="Quelldatei fehlt — übersprungen:"
    T_STEP_KEYD="Fan-Hotkey-Daemon einrichten (KEY_PROG4 + OSD)"
    T_KEYD_EVDEV_OK="python3-evdev installiert"
    T_KEYD_INPUT_OK="User zur Gruppe 'input' hinzugefügt (wirkt nach Re-Login)"
    T_KEYD_INPUT_ALREADY="User bereits in 'input'-Gruppe"
    T_KEYD_SERVICE_OK="rog-fan-keyd User-Service installiert und aktiviert"
    T_KEYD_SERVICE_FAIL="rog-fan-keyd-Service konnte nicht aktiviert werden (manuell: systemctl --user enable --now rog-fan-keyd.service)"
    T_STEP_DESKTOP="Menüeinträge erstellen (.desktop)"
    T_DESKTOP_OK=".desktop-Einträge installiert (rog-fan-gui)"
    T_STEP_CFG="Standard-Konfiguration anlegen"
    T_CFG_DEFAULT="Standard-Profil gesetzt auf: balanced"
    T_CFG_KEPT="Vorhandene Profil-Konfiguration beibehalten"
    T_STEP_TEST="Funktionstest"
    T_TEST_OK="asusctl funktioniert — Profil angewendet"
    T_TEST_WARN="asusctl-Syntax weicht in dieser Version ab — direkt via sysfs gesetzt"
    T_CURRENT_PROFILE="Aktuelles platform_profile"
    T_DONE_TITLE="Installation erfolgreich abgeschlossen!"
    T_DONE_NOTE="Alle Komponenten sind installiert: rog-fan (Terminal), rog-fan-gui (GTK), rog-fan-keyd (Hotkey + OSD)."
    T_DONE_CMDS="Sofort verfügbar:"
    # T_DONE_FUTURE entfernt — alle Komponenten sind jetzt installiert
    T_DONE_LANG="Sprache wechseln: ROG_LANG=de  oder  ROG_LANG=en"
    T_UNINSTALL_TITLE="Deinstallation wird durchgeführt..."
    T_UNINST_RESUME="rog-fan-resume.service deaktivieren und entfernen"
    T_UNINST_RESUME_OK="rog-fan-resume.service entfernt"
    T_UNINST_SUDO="sudoers-Regel entfernen"
    T_UNINST_SUDO_OK="sudoers-Regel entfernt"
    T_UNINST_PPD="power-profiles-daemon reaktivieren"
    T_UNINST_PPD_OK="power-profiles-daemon reaktiviert"
    T_UNINST_PPD_SKIP="power-profiles-daemon nicht installiert — übersprungen"
    T_UNINST_ASUSD="asusd deaktivieren"
    T_UNINST_ASUSD_OK="asusd deaktiviert"
    T_UNINST_ASK="asusctl-Paket ebenfalls deinstallieren? [j/N]: "
    T_UNINST_ASUSCTL_OK="asusctl entfernt"
    T_UNINST_ASUSCTL_KEPT="asusctl bleibt installiert"
    T_UNINST_DONE="Deinstallation abgeschlossen."
    T_UNINST_NOTE1="Konfiguration in"
    T_UNINST_NOTE2="wurde NICHT gelöscht."
    T_UNINST_NOTE3="Zum vollständigen Entfernen:"
    T_ROOT_ERR="Dieses Script muss mit sudo ausgeführt werden:"
    T_APT_ERR="Nur Ubuntu/Debian/Linux-Mint-basierte Systeme werden unterstützt (apt fehlt)."
fi

# ── Konfiguration ────────────────────────────────────────────
# User-Detection — robust für sudo UND pkexec
# Reihenfolge: SUDO_USER → PKEXEC_UID-Lookup → ersten regulären User aus /etc/passwd
detect_install_user() {
    local u=""
    # 1. Klassisches sudo
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"
        return 0
    fi
    # 2. pkexec setzt PKEXEC_UID
    if [[ -n "${PKEXEC_UID:-}" ]]; then
        u=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
        if [[ -n "$u" && "$u" != "root" ]]; then
            echo "$u"
            return 0
        fi
    fi
    # 3. Heuristik: ersten regulären User mit UID >= 1000, der ein existierendes Home hat
    while IFS=: read -r name _ uid _ _ home _; do
        if [[ "$uid" -ge 1000 && "$uid" -lt 65000 && -d "$home" ]]; then
            echo "$name"
            return 0
        fi
    done < /etc/passwd
    # 4. Fallback (sollte praktisch nie passieren)
    echo "${USER:-root}"
}

INSTALL_USER="$(detect_install_user)"
INSTALL_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/asusctl-build"
ASUSCTL_REPO="https://gitlab.com/asus-linux/asusctl.git"
SERVICE_USER="$INSTALL_USER"
CONFIG_DIR="$INSTALL_HOME/.config/rog-fan"
DEFAULT_PROFILE="balanced"

# ── Hilfsfunktionen ──────────────────────────────────────────
print_header() {
    [[ -t 1 ]] && clear
    echo -e "${MAG}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   $T_HEADER_1              ║"
    echo "  ║   $T_HEADER_2  ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RST}"
    echo -e "${DIM}  $T_TARGET_USER : $INSTALL_USER${RST}"
    echo -e "${DIM}  $T_HOME_DIR: $INSTALL_HOME${RST}"
    echo ""
}

step() { echo -e "\n${STEP} ${WHT}$*${RST}"; }
ok()   { echo -e "${OK} $*"; }
info() { echo -e "${INFO} $*"; }
warn() { echo -e "${WARN} $*"; }
err()  { echo -e "${ERR} $*" >&2; }
die()  { err "$*"; [[ -t 1 ]] && read -rp "  [ Enter ]" _ 2>/dev/null || true; exit 1; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        print_header
        echo ""
        echo -e "${RED}  ╔══════════════════════════════════════════════════════╗${RST}"
        echo -e "${RED}  ║  $T_ROOT_ERR${RST}"
        echo -e "${RED}  ║  sudo bash $0${RST}"
        echo -e "${RED}  ╚══════════════════════════════════════════════════════╝${RST}"
        echo ""
        [[ -t 1 ]] && read -rp "  [ Enter zum Beenden / press Enter to exit ]" _ 2>/dev/null || true
        exit 1
    fi
}

# ── User-Systemctl-Helper ────────────────────────────────────
# Führt `systemctl --user ...` zuverlässig als $INSTALL_USER aus, auch wenn
# der Installer über pkexec/sudo läuft. Setzt XDG_RUNTIME_DIR UND
# DBUS_SESSION_BUS_ADDRESS, prüft ob der User-Bus überhaupt erreichbar ist,
# und gibt echte Fehler aus (anstatt sie nach /dev/null zu werfen).
#
# Usage: user_systemctl daemon-reload
#        user_systemctl enable --now rog-fan-keyd.service
# Rückgabe: 0 = Erfolg, 1 = Fehler (Fehlermeldung auf stderr)
user_systemctl() {
    local uid runtime_dir bus_socket out rc
    uid="$(id -u "$INSTALL_USER")"
    runtime_dir="/run/user/$uid"
    bus_socket="$runtime_dir/bus"

    if [[ ! -d "$runtime_dir" ]]; then
        echo "user_systemctl: $runtime_dir nicht vorhanden — $INSTALL_USER hat keine aktive Login-Session" >&2
        return 1
    fi
    if [[ ! -S "$bus_socket" ]]; then
        # systemd-user-manager läuft nicht — starten und kurz warten
        systemctl start "user@${uid}.service" 2>/dev/null || true
        local i=0
        while [[ ! -S "$bus_socket" && $i -lt 20 ]]; do
            sleep 0.1
            i=$((i + 1))
        done
        if [[ ! -S "$bus_socket" ]]; then
            echo "user_systemctl: User-Bus $bus_socket nicht erreichbar (systemd-user-manager nicht aktiv)" >&2
            return 1
        fi
    fi

    out=$(runuser -u "$INSTALL_USER" -- env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_socket" \
        systemctl --user "$@" 2>&1)
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "user_systemctl ($*) fehlgeschlagen (rc=$rc):" >&2
        echo "$out" | sed 's/^/    /' >&2
    fi
    return $rc
}

# ── Deinstallation ───────────────────────────────────────────
uninstall() {
    print_header
    echo -e "${YLW}  $T_UNINSTALL_TITLE${RST}\n"

    step "$T_UNINST_RESUME"
    if systemctl is-enabled rog-fan-resume.service &>/dev/null; then
        systemctl disable --now rog-fan-resume.service 2>/dev/null || true
    fi
    rm -f /etc/systemd/system/rog-fan-resume.service
    systemctl daemon-reload
    if systemctl is-enabled rog-fan-boot.service &>/dev/null; then
        systemctl disable --now rog-fan-boot.service 2>/dev/null || true
    fi
    rm -f /etc/systemd/system/rog-fan-boot.service
    systemctl daemon-reload
    ok "$T_UNINST_RESUME_OK"

    # Fan-Hotkey-Daemon (User-Service)
    USER_SVC_DIR="$INSTALL_HOME/.config/systemd/user"
    if [[ -f "$USER_SVC_DIR/rog-fan-keyd.service" ]]; then
        user_systemctl disable --now rog-fan-keyd.service || true
        rm -f "$USER_SVC_DIR/rog-fan-keyd.service"
    fi
    # Suite-Binaries
    rm -f /usr/local/bin/rog-fan /usr/local/bin/rog-fan-gui /usr/local/bin/rog-fan-keyd
    # Menüeintrag
    rm -f /usr/share/applications/rog-fan-gui.desktop
    update-desktop-database 2>/dev/null || true

    step "$T_UNINST_SUDO"
    rm -f /etc/sudoers.d/rog-fan
    ok "$T_UNINST_SUDO_OK"

    step "$T_UNINST_PPD"
    if dpkg -l power-profiles-daemon 2>/dev/null | grep -q '^ii'; then
        systemctl enable --now power-profiles-daemon 2>/dev/null || true
        ok "$T_UNINST_PPD_OK"
    else
        info "$T_UNINST_PPD_SKIP"
    fi

    step "$T_UNINST_ASUSD"
    if systemctl is-enabled asusd.service &>/dev/null; then
        systemctl disable --now asusd.service 2>/dev/null || true
    fi
    ok "$T_UNINST_ASUSD_OK"

    echo ""
    ANSWER="n"
    if [[ -t 0 ]]; then
        read -rp "  $T_UNINST_ASK" ANSWER || ANSWER="n"
    fi
    case "${ANSWER,,}" in
        y|j|yes|ja)
            apt-get remove -y asusctl 2>&1 | tail -5 || true
            ok "$T_UNINST_ASUSCTL_OK"
            ;;
        *)
            info "$T_UNINST_ASUSCTL_KEPT"
            ;;
    esac

    rm -f /usr/local/bin/asusd /usr/local/bin/asusctl
    rm -f /usr/bin/asusd /usr/bin/asusctl

    echo ""
    echo -e "${GRN}  $T_UNINST_DONE${RST}"
    echo -e "${DIM}  $T_UNINST_NOTE1 $CONFIG_DIR/ $T_UNINST_NOTE2${RST}"
    echo -e "${DIM}  $T_UNINST_NOTE3 rm -rf $CONFIG_DIR${RST}"
    exit 0
}

# ── Argument-Auswertung ──────────────────────────────────────
[[ "${1:-}" == "--uninstall" ]] && { require_root; uninstall; }

# ── Voraussetzungen prüfen ───────────────────────────────────
print_header
require_root

# ── Schritt 1: Voraussetzungen prüfen ────────────────────────
step "$T_CHECK_PREREQ"

# Distro prüfen
if ! command -v apt-get &>/dev/null; then
    die "$T_APT_ERR"
fi
ok "$T_APT_OK"

# Kernel-Version prüfen
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)
if [[ $KERNEL_MAJOR -lt 5 ]] || [[ $KERNEL_MAJOR -eq 5 && $KERNEL_MINOR -lt 15 ]]; then
    warn "$T_KERNEL_WARN: $(uname -r)"
else
    ok "$T_KERNEL_OK: $(uname -r)"
fi

# platform_profile prüfen — Hard-Requirement
if [[ ! -f /sys/firmware/acpi/platform_profile ]]; then
    die "$T_PP_ERR"
fi
ok "$T_PP_OK"

# asus-nb-wmi prüfen — Soft-Requirement
if [[ -d /sys/devices/platform/asus-nb-wmi ]]; then
    ok "$T_WMI_OK"
else
    warn "$T_WMI_WARN"
fi

# ── Schritt 2: Konflikt-Check ────────────────────────────────
step "$T_CONFLICT_STEP"

CONFLICT_FOUND=0
if dpkg -l 2>/dev/null | awk '{print $2}' | grep -qE '^(nbfc|nbfc-linux)$'; then
    err "$T_CONFLICT_NBFC"
    echo -e "       ${DIM}sudo apt remove nbfc nbfc-linux${RST}"
    CONFLICT_FOUND=1
fi
if [[ $CONFLICT_FOUND -eq 1 ]]; then
    die "Konflikt — bitte erst auflösen / Conflict — please resolve first."
fi

if systemctl is-active fancontrol &>/dev/null; then
    warn "$T_CONFLICT_FANCTRL"
    echo -e "       ${DIM}sudo systemctl disable --now fancontrol${RST}"
else
    ok "$T_CONFLICT_OK"
fi

# ── Schritt 3: Dependencies ──────────────────────────────────
step "$T_STEP_DEPS"
apt-get update -qq 2>&1 | grep -E 'Fehler|error|Error' || true
apt-get install -y \
    lm-sensors \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    2>&1 | grep -vE '^(Lese|Les|Get|Hol|OK|Paket|ok\b|Trigger)' || true
ok "$T_DEPS_OK"

# sensors-detect im Hintergrund mit Defaults
echo -e "  ${DIM}$T_SENSORS_RUN${RST}"
yes "" 2>/dev/null | sensors-detect --auto >/dev/null 2>&1 || true
ok "$T_SENSORS_OK"

# drivetemp aktivieren
modprobe drivetemp 2>/dev/null || true
if ! grep -qE '^drivetemp$' /etc/modules 2>/dev/null; then
    echo "drivetemp" >> /etc/modules
fi
ok "$T_DRIVETEMP_OK"

# ── Schritt 4: asusctl installieren ──────────────────────────
step "$T_STEP_ASUSCTL"

ASUSCTL_INSTALLED=0

# Methode A: PPA (nur für ältere Ubuntu-Codenames — neuere wie noble/oracular sind nicht supported)
PPA_SUPPORTED_CODENAMES="bionic focal jammy"   # alle <= 22.04 (asus-linux PPA Ende 2024 eingestellt für 24.04+)
UBUNTU_CODENAME="$(lsb_release -cs 2>/dev/null || true)"
if [[ -z "${UBUNTU_CODENAME}" ]] && [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
fi

if [[ $ASUSCTL_INSTALLED -eq 0 ]]; then
    if echo " $PPA_SUPPORTED_CODENAMES " | grep -q " $UBUNTU_CODENAME "; then
        info "$T_PPA_TRY"
        PPA_OK=1
        add-apt-repository -y ppa:asus-linux/stable 2>&1 | tail -3 || PPA_OK=0
        if [[ $PPA_OK -eq 1 ]]; then
            apt-get update -qq 2>&1 | grep -E 'Fehler|error|Error' || true
            if apt-get install -y asusctl 2>&1 | tail -5; then
                if command -v asusctl &>/dev/null; then
                    ok "$T_PPA_OK"
                    ASUSCTL_INSTALLED=1
                fi
            fi
        fi
        if [[ $ASUSCTL_INSTALLED -eq 0 ]]; then
            warn "$T_PPA_FAIL"
            add-apt-repository -y --remove ppa:asus-linux/stable 2>/dev/null | tail -1 || true
        fi
    else
        info "$T_PPA_SKIP $UBUNTU_CODENAME — $T_PPA_SKIP2"
    fi
fi

# Methode B: Source-Build
if [[ $ASUSCTL_INSTALLED -eq 0 ]]; then
    info "$T_BUILD_DEPS"
    apt-get install -y \
        cargo \
        clang \
        gcc \
        git \
        libclang-dev \
        libdbus-1-dev \
        libgtk-3-dev \
        libsystemd-dev \
        libudev-dev \
        make \
        pkg-config \
        rustc \
        2>&1 | grep -vE '^(Lese|Les|Get|Hol|OK|Paket|ok\b|Trigger)' || true

    info "$T_BUILD_CLONE"
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR" 2>/dev/null || { chmod -R u+w "$BUILD_DIR" 2>/dev/null; rm -rf "$BUILD_DIR"; }
    fi
    git clone --depth=1 "$ASUSCTL_REPO" "$BUILD_DIR" 2>&1 | grep -vE '^(remote:|Klone|Cloning|Receive)' || true

    if [[ -d "$BUILD_DIR" ]]; then
        echo -e "  ${DIM}$T_BUILD_COMPILE${RST}"

        # rog-control-center aus dem Cargo-Workspace entfernen (kaputte slint-Git-Dependency)
        # Wir bauen nur asusd (Daemon) + asusctl (CLI) — unsere eigene GUI kommt später in v0.5
        if [[ -f "$BUILD_DIR/Cargo.toml" ]]; then
            sed -i '/"rog-control-center"/d' "$BUILD_DIR/Cargo.toml"
        fi

        (
            cd "$BUILD_DIR" || exit 1

            # Bevorzugt user-rustup Cargo (modern), Fallback auf System-Cargo
            # Suche zuerst beim erkannten INSTALL_USER, dann scanne /home/* nach
            # einem rustup-Cargo (falls Detection fehlschlug, z.B. bei pkexec).
            USER_CARGO_BIN=""
            if [[ -x "$INSTALL_HOME/.cargo/bin/cargo" ]]; then
                USER_CARGO_BIN="$INSTALL_HOME/.cargo/bin"
                USER_CARGO_HOME_PATH="$INSTALL_HOME/.cargo"
                USER_RUSTUP_HOME_PATH="$INSTALL_HOME/.rustup"
            else
                # Fallback: scanne alle Home-Verzeichnisse
                for h in /home/*; do
                    if [[ -x "$h/.cargo/bin/cargo" ]]; then
                        USER_CARGO_BIN="$h/.cargo/bin"
                        USER_CARGO_HOME_PATH="$h/.cargo"
                        USER_RUSTUP_HOME_PATH="$h/.rustup"
                        echo "  [INFO] User-rustup gefunden in: $h"
                        break
                    fi
                done
            fi
            if [[ -n "$USER_CARGO_BIN" ]]; then
                export PATH="$USER_CARGO_BIN:$PATH"
                export CARGO_HOME="$USER_CARGO_HOME_PATH"
                export RUSTUP_HOME="$USER_RUSTUP_HOME_PATH"
            fi

            CARGO_VERSION=$(cargo --version 2>/dev/null | awk '{print $2}')
            CARGO_MAJOR=$(echo "$CARGO_VERSION" | cut -d. -f1)
            CARGO_MINOR=$(echo "$CARGO_VERSION" | cut -d. -f2)

            if [[ -z "$CARGO_VERSION" ]] || \
               { [[ "$CARGO_MAJOR" -le 1 ]] && [[ "$CARGO_MINOR" -lt 80 ]]; }; then
                echo ""
                echo "  [FEHLER] Cargo ${CARGO_VERSION:-fehlt} ist zu alt fuer asusctl."
                echo "          Benoetigt: Cargo >= 1.80 (fuer edition2024)"
                echo ""
                echo "  Loesung: rustup als USER (NICHT als root) installieren:"
                echo "    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
                echo "    source \"\$HOME/.cargo/env\""
                echo ""
                echo "  Falls rustup bereits installiert ist (z.B. unter /home/$INSTALL_USER/.cargo/),"
                echo "  pruefe ob 'cargo --version' als User >= 1.80 zeigt."
                echo "  Dann diesen Installer erneut starten."
                exit 1
            fi

            echo "  [INFO] Verwende Cargo $CARGO_VERSION ($(command -v cargo))"
            cargo build --release -p asusd -p asusctl 2>&1 | tail -20

            if [[ -f target/release/asusd && -f target/release/asusctl ]]; then
                install -Dm755 target/release/asusd   /usr/local/bin/asusd
                install -Dm755 target/release/asusctl /usr/local/bin/asusctl
                ln -sf /usr/local/bin/asusd   /usr/bin/asusd
                ln -sf /usr/local/bin/asusctl /usr/bin/asusctl

                # systemd-Unit, udev-Rules, D-Bus-Policy (Pfade je nach asusctl-Version)
                for f in data/asusd.service asusd/data/asusd.service; do
                    [[ -f "$f" ]] && install -Dm644 "$f" /etc/systemd/system/asusd.service && break
                done
                for f in data/99-asusd.rules data/asusd.rules asusd/data/99-asusd.rules; do
                    [[ -f "$f" ]] && install -Dm644 "$f" /etc/udev/rules.d/99-asusd.rules && break
                done
                for f in data/asusd.conf asusd/data/asusd.conf; do
                    [[ -f "$f" ]] && install -Dm644 "$f" /etc/dbus-1/system.d/asusd.conf && break
                done

                # Profil-Konfigurationen (.ron)
                mkdir -p /etc/asusd
                find . -path ./target -prune -o -name "*.ron" -print 2>/dev/null | while read -r ron; do
                    install -Dm644 "$ron" "/etc/asusd/$(basename "$ron")" 2>/dev/null || true
                done

                systemctl daemon-reload 2>/dev/null || true
                udevadm control --reload-rules 2>/dev/null || true
            fi
        ) || true

        if command -v asusctl &>/dev/null; then
            ok "$T_BUILD_OK"
            ASUSCTL_INSTALLED=1
        fi
        rm -rf "$BUILD_DIR" 2>/dev/null || true
    fi
fi

if [[ $ASUSCTL_INSTALLED -eq 0 ]] || ! command -v asusctl &>/dev/null; then
    die "$T_ASUSCTL_VERIFY_FAIL"
fi

# ── Schritt 5: PPD deaktivieren ──────────────────────────────
step "$T_STEP_PPD"

if systemctl is-enabled power-profiles-daemon &>/dev/null; then
    systemctl disable --now power-profiles-daemon 2>/dev/null || true
    ok "$T_PPD_DISABLED"
    info "$T_PPD_REENABLE"
else
    info "$T_PPD_NONE"
fi

# ── Schritt 6: asusd aktivieren ──────────────────────────────
step "$T_STEP_ASUSD"

systemctl daemon-reload
systemctl enable --now asusd 2>&1 | tail -3 || true
sleep 1
if [[ "$(systemctl is-active asusd 2>/dev/null)" == "active" ]]; then
    ok "$T_ASUSD_OK"
else
    err "$T_ASUSD_FAIL"
fi

# ── Schritt 7: sudoers für platform_profile ──────────────────
step "$T_STEP_SUDO"

cat > /etc/sudoers.d/rog-fan << SUDORULE
# Erlaubt $INSTALL_USER das ROG Lüfter-Profil ohne Passwort zu setzen
$INSTALL_USER ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/firmware/acpi/platform_profile
$INSTALL_USER ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy
SUDORULE

chmod 440 /etc/sudoers.d/rog-fan
if visudo -c -f /etc/sudoers.d/rog-fan &>/dev/null; then
    ok "$T_SUDO_OK"
else
    rm -f /etc/sudoers.d/rog-fan
    die "$T_SUDO_FAIL"
fi

# ── Schritt 8: systemd Resume-Service ────────────────────────
step "$T_STEP_RESUME"

cat > /etc/systemd/system/rog-fan-resume.service << SVCEOF
[Unit]
Description=ROG Fan Profile nach Suspend/Resume wiederherstellen
After=suspend.target hibernate.target hybrid-sleep.target
Wants=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
User=root
ExecStart=/bin/sh -c 'LAST=/home/${SERVICE_USER}/.config/rog-fan/last_profile; if [ -f "\$LAST" ]; then PROFILE=\$(cat "\$LAST"); echo \$PROFILE > /sys/firmware/acpi/platform_profile; fi'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
SVCEOF

systemctl daemon-reload
systemctl enable rog-fan-resume.service 2>&1 | tail -3 || true
ok "$T_RESUME_OK"

# ── Schritt 8b: systemd Boot-Service ─────────────────────────
step "$T_STEP_BOOT"

cat > /etc/systemd/system/rog-fan-boot.service << SVCEOF
[Unit]
Description=ROG Fan Profile beim Boot wiederherstellen
After=asusd.service multi-user.target
Wants=asusd.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=/bin/sh -c 'LAST=/home/${SERVICE_USER}/.config/rog-fan/last_profile; if [ -f "\$LAST" ]; then PROFILE=\$(cat "\$LAST"); echo \$PROFILE > /sys/firmware/acpi/platform_profile 2>/dev/null || true; fi'

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable rog-fan-boot.service 2>&1 | tail -3 || true
ok "$T_BOOT_OK"

# ── Schritt 9: Default-Konfiguration ─────────────────────────
step "$T_STEP_CFG"

mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/last_profile" ]]; then
    echo "$DEFAULT_PROFILE" > "$CONFIG_DIR/last_profile"
    ok "$T_CFG_DEFAULT"
else
    ok "$T_CFG_KEPT: $(cat "$CONFIG_DIR/last_profile")"
fi
chown -R "$INSTALL_USER:$INSTALL_USER" "$CONFIG_DIR"

# Aktuelles Profil prüfen und ggf. auf balanced setzen (wenn quiet)
CURRENT_PP=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "unknown")
if [[ "$CURRENT_PP" == "quiet" ]]; then
    echo "$DEFAULT_PROFILE" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
fi
# ── Schritt 9b: Suite-Binaries deployen ──────────────────────
step "$T_STEP_DEPLOY"

deploy_file() {
    local src="$1" dst="$2" mode="${3:-755}"
    if [[ -f "$SCRIPT_DIR/$src" ]]; then
        install -Dm"$mode" "$SCRIPT_DIR/$src" "$dst"
        ok "${src} → ${dst}"
    else
        warn "$T_DEPLOY_MISSING $src"
    fi
}

deploy_file "rog-fan.sh"     "/usr/local/bin/rog-fan"
deploy_file "rog-fan-gui.py" "/usr/local/bin/rog-fan-gui"
deploy_file "rog-fan-keyd.py" "/usr/local/bin/rog-fan-keyd"

ok "$T_DEPLOY_OK"

# ── Schritt 9c: Fan-Hotkey-Daemon ────────────────────────
step "$T_STEP_KEYD"

# python3-evdev
apt-get install -y python3-evdev 2>&1 | tail -3 || true
ok "$T_KEYD_EVDEV_OK"

# User in 'input' Gruppe (für /dev/input/event*)
if id -nG "$INSTALL_USER" | tr ' ' '\n' | grep -qx input; then
    info "$T_KEYD_INPUT_ALREADY"
else
    usermod -aG input "$INSTALL_USER"
    ok "$T_KEYD_INPUT_OK"
fi

# User-Service (~/.config/systemd/user/)
USER_SVC_DIR="$INSTALL_HOME/.config/systemd/user"
mkdir -p "$USER_SVC_DIR"
if [[ -f "$SCRIPT_DIR/rog-fan-keyd.service" ]]; then
    install -Dm644 "$SCRIPT_DIR/rog-fan-keyd.service" "$USER_SVC_DIR/rog-fan-keyd.service"
    chown -R "$INSTALL_USER:$INSTALL_USER" "$INSTALL_HOME/.config/systemd"
    if user_systemctl daemon-reload && \
       user_systemctl enable --now rog-fan-keyd.service; then
        ok "$T_KEYD_SERVICE_OK"
    else
        warn "$T_KEYD_SERVICE_FAIL"
    fi
else
    warn "$T_DEPLOY_MISSING rog-fan-keyd.service"
fi

# ── Schritt 9d: Menüeinträge ────────────────────────────
step "$T_STEP_DESKTOP"

cat > /usr/share/applications/rog-fan-gui.desktop << 'DESKTOPEOF'
[Desktop Entry]
Type=Application
Name=ROG Fan Control
Name[de]=ROG Lüftersteuerung
Comment=ASUS ROG fan profile control (asusctl GUI)
Comment[de]=ASUS ROG Lüfter-Profil-Steuerung (asusctl GUI)
Exec=/usr/local/bin/rog-fan-gui
Icon=fan-symbolic
Terminal=false
Categories=System;HardwareSettings;Settings;
Keywords=fan;asus;rog;profile;thermal;
DESKTOPEOF
chmod 644 /usr/share/applications/rog-fan-gui.desktop
update-desktop-database 2>/dev/null || true
ok "$T_DESKTOP_OK"
# ── Schritt 10: Funktionstest ────────────────────────────────
step "$T_STEP_TEST"

# asusctl v6 will Capitalized Profil-Namen; alte v5-Syntax als Fallback, sonst sysfs
PROFILE_CAP="$(echo "${DEFAULT_PROFILE:0:1}" | tr '[:lower:]' '[:upper:]')${DEFAULT_PROFILE:1}"
if asusctl profile set "$PROFILE_CAP" &>/dev/null; then
    ok "$T_TEST_OK: $DEFAULT_PROFILE"
elif asusctl profile -P "$DEFAULT_PROFILE" &>/dev/null; then
    ok "$T_TEST_OK: $DEFAULT_PROFILE"
else
    warn "$T_TEST_WARN"
    echo "$DEFAULT_PROFILE" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
fi

CURRENT_PP=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo "unknown")
info "$T_CURRENT_PROFILE: ${YLW}$CURRENT_PP${RST}"

# ── Abschluss ────────────────────────────────────────────────
echo ""
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${GRN}  $T_DONE_TITLE${RST}"
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""
echo -e "  ${YLW}$T_DONE_NOTE${RST}"
echo ""

if [[ "$ROG_LANG" == "en" ]]; then
    echo -e "  $T_DONE_CMDS"
    echo -e "    ${GRN}rog-fan${RST}                        ${DIM}→ Terminal wrapper (status / quiet / balanced / performance)${RST}"
    echo -e "    ${GRN}rog-fan-gui${RST}                    ${DIM}→ Graphical control (GTK)${RST}"
    echo -e "    ${GRN}rog-fan-keyd${RST}                   ${DIM}→ Fan hotkey daemon (KEY_PROG4 + OSD)${RST}"
    echo -e "    ${GRN}asusctl profile set Balanced${RST}    ${DIM}→ Direct asusctl call (v6 syntax)${RST}"
    echo -e "    ${GRN}cat /sys/firmware/acpi/platform_profile${RST}  ${DIM}→ Show current${RST}"
    echo -e "    ${GRN}rog-fan-diagnose${RST}                ${DIM}→ Full diagnostic${RST}"
    echo ""
    echo -e "  ${MAG}Tray applet recommendation: Cinnamon Spices → Sensors@claudiux${RST}"
else
    echo -e "  $T_DONE_CMDS"
    echo -e "    ${GRN}rog-fan${RST}                        ${DIM}→ Terminal-Wrapper (status / quiet / balanced / performance)${RST}"
    echo -e "    ${GRN}rog-fan-gui${RST}                    ${DIM}→ Grafische Steuerung (GTK)${RST}"
    echo -e "    ${GRN}rog-fan-keyd${RST}                   ${DIM}→ Fan-Hotkey-Daemon (KEY_PROG4 + OSD)${RST}"
    echo -e "    ${GRN}asusctl profile set Balanced${RST}    ${DIM}→ Direkter asusctl-Aufruf (v6-Syntax)${RST}"
    echo -e "    ${GRN}cat /sys/firmware/acpi/platform_profile${RST}  ${DIM}→ Aktuelles Profil${RST}"
    echo -e "    ${GRN}rog-fan-diagnose${RST}                ${DIM}→ Vollständige Diagnose${RST}"
    echo ""
    echo -e "  ${MAG}Tray-Applet-Empfehlung: Cinnamon Spices → Sensors@claudiux${RST}"
fi

echo ""
echo -e "  ${DIM}Uninstall / Deinstallieren: sudo bash $0 --uninstall${RST}"
echo -e "  ${DIM}$T_DONE_LANG${RST}"
echo ""
