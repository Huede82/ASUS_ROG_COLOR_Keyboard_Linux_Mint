#!/usr/bin/env bash
# ============================================================
#  ROG RGB — Install Script  |  Installations-Script
#  ASUS ROG N-KEY Keyboard RGB · Linux Mint / Ubuntu
#
#  Usage / Verwendung:
#    bash install-rog-rgb.sh
#    bash install-rog-rgb.sh --uninstall
#    ROG_LANG=en bash install-rog-rgb.sh   (English output)
#
#  Installs / Installiert:
#    • rogauracore (built from source / aus Quellcode)
#    • rog-rgb       (terminal control / Terminal-Steuerung)
#    • rog-rgb-gui   (GTK3 GUI)
#    • rog-kbd-diagnose
#    • udev rules / udev-Regeln
#    • systemd services / systemd-Services
#    • .desktop entry / .desktop-Eintrag
#
#  Tip: Graphical installer available:
#    python3 install-rog-rgb-gui.py
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
    notify-send "ROG RGB Installer" "Kein Terminal gefunden – bitte manuell ausführen:\nsudo bash $SELF" 2>/dev/null || true
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
    T_HEADER_1="ROG RGB Installation Script"
    T_HEADER_2="ASUS N-KEY Keyboard Backlight for Linux"
    T_TARGET_USER="Target user"
    T_HOME_DIR="Home directory"
    T_CHECK_PREREQ="Checking prerequisites"
    T_APT_OK="apt available"
    T_KERNEL_OK="Kernel supports ASUS N-KEY RGB"
    T_KERNEL_WARN="Kernel < 5.11 — limited N-KEY RGB support"
    T_NKEY_FOUND="N-KEY device found"
    T_NKEY_WARN="WARNING: No known ASUS N-KEY device found via USB"
    T_NKEY_WARN2="(Installation continues anyway)"
    T_STEP_DEPS="Installing dependencies"
    T_DEPS_OK="Dependencies installed (incl. Python GTK3 for GUI)"
    T_STEP_BUILD="Building rogauracore from source"
    T_CLEANUP="Cleaning up old build directory..."
    T_CLONE_FAIL="git clone incomplete — check internet connection"
    T_SOURCE_OK="Source code downloaded"
    T_AUTOCONF="Running autoreconf..."
    T_CONFIGURE="Running configure..."
    T_COMPILE="Compiling rogauracore..."
    T_BUILD_OK="rogauracore built successfully"
    T_INSTALL_OK="rogauracore installed to"
    T_UDEV_OK="udev rules activated"
    T_STEP_SCRIPTS="Installing rog-rgb control script"
    T_SCRIPT_OK="rog-rgb installed to"
    T_STEP_GUI="Installing ROG RGB GUI"
    T_GUI_OK="rog-rgb-gui installed to"
    T_DESKTOP_OK=".desktop entry added to application menu"
    T_GUI_SKIP="rog-rgb-gui.py not found in script directory, skipping GUI"
    T_STEP_DIAG="Installing diagnostic script"
    T_DIAG_OK="rog-kbd-diagnose installed to"
    T_DIAG_SKIP="rog-kbd-diagnose.sh not found, skipping"
    T_STEP_SUDO="Setting up sudo permission for brightness"
    T_SUDO_OK="sudo rule for sysfs brightness created"
    T_STEP_SVC="Creating systemd services"
    T_SVC1_OK="rog-rgb.service (boot autostart) enabled"
    T_SVC2_OK="rog-rgb-resume.service (suspend/resume) enabled"
    T_STEP_CFG="Setting up default configuration"
    T_CFG_DEFAULT="Default color set"
    T_CFG_KEPT="Existing color configuration kept"
    T_STEP_TEST="Functional test"
    T_TEST_OK="rogauracore works — keyboard now lit"
    T_TEST_WARN="WARNING: rogauracore test — device may not be connected"
    T_DONE_TITLE="Installation completed successfully!"
    T_DONE_LANG="Switch language: ROG_LANG=en  or  ROG_LANG=de"
    T_UNINSTALL_TITLE="Uninstalling..."
    T_UNINST_SVC="Disabling and removing systemd services"
    T_UNINST_SVC_OK="systemd services removed"
    T_UNINST_ROGAURA="Removing rogauracore"
    T_UNINST_ROGAURA_OK="rogauracore removed"
    T_UNINST_SCRIPTS="Removing scripts"
    T_UNINST_SCRIPTS_OK="Scripts and .desktop entry removed"
    T_UNINST_UDEV="Removing udev rules"
    T_UNINST_UDEV_OK="udev rules removed"
    T_UNINST_DONE="Uninstallation complete."
    T_UNINST_NOTE1="Configuration in"
    T_UNINST_NOTE2="was NOT deleted."
    T_UNINST_NOTE3="To remove completely:"
    T_ROOT_ERR="This script must be run with sudo:"
    T_APT_ERR="Only Ubuntu/Debian/Linux-Mint-based systems supported (apt missing)."
else
    OK="  ${GRN}[OK]${RST}";   ERR="  ${RED}[FEHLER]${RST}"
    INFO="  ${CYN}[INFO]${RST}"; STEP="  ${MAG}[>>]${RST}"
    T_HEADER_1="ROG RGB Installations-Script"
    T_HEADER_2="ASUS N-KEY Tastatur Beleuchtung für Linux"
    T_TARGET_USER="Ziel-Benutzer"
    T_HOME_DIR="Home-Verzeichnis"
    T_CHECK_PREREQ="Systemvoraussetzungen prüfen"
    T_APT_OK="apt verfügbar"
    T_KERNEL_OK="Kernel unterstützt ASUS N-KEY RGB"
    T_KERNEL_WARN="Kernel < 5.11 — eingeschränkte N-KEY RGB-Unterstützung"
    T_NKEY_FOUND="N-KEY Gerät gefunden"
    T_NKEY_WARN="WARNUNG: Kein bekanntes ASUS N-KEY Gerät via USB gefunden"
    T_NKEY_WARN2="(Installation wird trotzdem fortgesetzt)"
    T_STEP_DEPS="Abhängigkeiten installieren"
    T_DEPS_OK="Abhängigkeiten installiert (inkl. Python GTK3 für GUI)"
    T_STEP_BUILD="rogauracore aus Quellcode bauen"
    T_CLEANUP="Bereinige altes Build-Verzeichnis..."
    T_CLONE_FAIL="git clone unvollständig — prüfe Internetzugang"
    T_SOURCE_OK="Quellcode heruntergeladen"
    T_AUTOCONF="Führe autoreconf aus..."
    T_CONFIGURE="Führe configure aus..."
    T_COMPILE="Kompiliere rogauracore..."
    T_BUILD_OK="rogauracore erfolgreich gebaut"
    T_INSTALL_OK="rogauracore nach installiert"
    T_UDEV_OK="udev-Regeln aktiviert"
    T_STEP_SCRIPTS="rog-rgb Steuerungs-Skript installieren"
    T_SCRIPT_OK="rog-rgb nach installiert"
    T_STEP_GUI="ROG RGB GUI installieren"
    T_GUI_OK="rog-rgb-gui nach installiert"
    T_DESKTOP_OK=".desktop Eintrag im Anwendungsmenü angelegt"
    T_GUI_SKIP="rog-rgb-gui.py nicht im Skript-Verzeichnis gefunden, GUI wird übersprungen"
    T_STEP_DIAG="Diagnose-Script installieren"
    T_DIAG_OK="rog-kbd-diagnose nach installiert"
    T_DIAG_SKIP="rog-kbd-diagnose.sh nicht im Skript-Verzeichnis gefunden, wird übersprungen"
    T_STEP_SUDO="sudo-Berechtigung für Helligkeit einrichten"
    T_SUDO_OK="sudo-Regel für sysfs-Brightness angelegt"
    T_STEP_SVC="systemd-Services anlegen"
    T_SVC1_OK="rog-rgb.service (Boot-Autostart) aktiviert"
    T_SVC2_OK="rog-rgb-resume.service (Suspend/Resume) aktiviert"
    T_STEP_CFG="Standard-Konfiguration anlegen"
    T_CFG_DEFAULT="Standard-Farbe gesetzt"
    T_CFG_KEPT="Vorhandene Farb-Konfiguration beibehalten"
    T_STEP_TEST="Funktionstest"
    T_TEST_OK="rogauracore funktioniert — Tastatur leuchtet jetzt"
    T_TEST_WARN="WARNUNG: rogauracore Test — Gerät möglicherweise nicht verbunden"
    T_DONE_TITLE="Installation erfolgreich abgeschlossen!"
    T_DONE_LANG="Sprache wechseln: ROG_LANG=de  oder  ROG_LANG=en"
    T_UNINSTALL_TITLE="Deinstallation wird durchgeführt..."
    T_UNINST_SVC="systemd-Services deaktivieren und entfernen"
    T_UNINST_SVC_OK="systemd-Services entfernt"
    T_UNINST_ROGAURA="rogauracore entfernen"
    T_UNINST_ROGAURA_OK="rogauracore entfernt"
    T_UNINST_SCRIPTS="rog-rgb Skripte entfernen"
    T_UNINST_SCRIPTS_OK="Skripte und .desktop Eintrag entfernt"
    T_UNINST_UDEV="udev-Regeln entfernen"
    T_UNINST_UDEV_OK="udev-Regeln entfernt"
    T_UNINST_DONE="Deinstallation abgeschlossen."
    T_UNINST_NOTE1="Konfiguration in"
    T_UNINST_NOTE2="wurde NICHT gelöscht."
    T_UNINST_NOTE3="Zum vollständigen Entfernen:"
    T_ROOT_ERR="Dieses Script muss mit sudo ausgeführt werden:"
    T_APT_ERR="Nur Ubuntu/Debian/Linux-Mint-basierte Systeme werden unterstützt (apt fehlt)."
fi

# ── Konfiguration ────────────────────────────────────────────
INSTALL_USER="${SUDO_USER:-${USER}}"
INSTALL_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
BUILD_DIR="/tmp/rogauracore-build"
ROGAURACORE_REPO="https://github.com/wroberts/rogauracore.git"
DEFAULT_COLOR="ff5500"  # Standard-Farbe: Orange
SERVICE_USER="$INSTALL_USER"

# ── Hilfsfunktionen ──────────────────────────────────────────
print_header() {
    [[ -t 1 ]] && clear
    echo -e "${MAG}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   $T_HEADER_1               ║"
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

# ── Deinstallation ───────────────────────────────────────────
uninstall() {
    print_header
    echo -e "${YLW}  $T_UNINSTALL_TITLE${RST}\n"

    step "$T_UNINST_SVC"
    for svc in rog-rgb rog-rgb-resume; do
        if systemctl is-enabled "$svc.service" &>/dev/null; then
            systemctl disable --now "$svc.service" 2>/dev/null || true
            ok "$svc.service deaktiviert"
        fi
        rm -f "/etc/systemd/system/$svc.service"
    done
    systemctl daemon-reload
    ok "$T_UNINST_SVC_OK"

    step "$T_UNINST_ROGAURA"
    rm -f "$INSTALL_DIR/rogauracore"
    ok "$T_UNINST_ROGAURA_OK"

    step "$T_UNINST_SCRIPTS"
    rm -f "$INSTALL_DIR/rog-rgb" "$INSTALL_DIR/rog-rgb-gui" "$INSTALL_DIR/rog-kbd-diagnose"
    rm -f "$INSTALL_HOME/.local/share/applications/rog-rgb-gui.desktop"
    rm -f /etc/sudoers.d/rog-rgb
    ok "$T_UNINST_SCRIPTS_OK"

    step "$T_UNINST_UDEV"
    rm -f /lib/udev/rules.d/90-rogauracore.rules
    udevadm control --reload-rules && udevadm trigger
    ok "$T_UNINST_UDEV_OK"

    echo ""
    echo -e "${GRN}  $T_UNINST_DONE${RST}"
    echo -e "${DIM}  $T_UNINST_NOTE1 $INSTALL_HOME/.config/rog-rgb/ $T_UNINST_NOTE2${RST}"
    echo -e "${DIM}  $T_UNINST_NOTE3 rm -rf $INSTALL_HOME/.config/rog-rgb${RST}"
    exit 0
}

# ── Argument-Auswertung ──────────────────────────────────────
[[ "${1:-}" == "--uninstall" ]] && { require_root; uninstall; }

# ── Voraussetzungen prüfen ───────────────────────────────────
print_header
require_root

step "$T_CHECK_PREREQ"

# Distro prüfen
if ! command -v apt-get &>/dev/null; then
    die "$T_APT_ERR"
fi
ok "$T_APT_OK"

# Kernel-Version prüfen
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)
if [[ $KERNEL_MAJOR -lt 5 ]] || [[ $KERNEL_MAJOR -eq 5 && $KERNEL_MINOR -lt 11 ]]; then
    echo -e "${YLW}  [!] $T_KERNEL_WARN: $(uname -r)${RST}"
else
    ok "$T_KERNEL_OK: $(uname -r)"
fi

# ASUS N-KEY USB prüfen
if lsusb 2>/dev/null | grep -qiE "0b05:(1866|1869|1854|19b6|1a30)"; then
    NKEY_DEVICE=$(lsusb | grep -iE "0b05:(1866|1869|1854|19b6|1a30)" | head -1)
    ok "$T_NKEY_FOUND: ${DIM}$NKEY_DEVICE${RST}"
else
    echo -e "${YLW}  [!] $T_NKEY_WARN${RST}"
    echo -e "${DIM}           $T_NKEY_WARN2${RST}"
fi

# ── Schritt 1: Abhängigkeiten installieren ───────────────────
step "$T_STEP_DEPS"
apt-get update -qq 2>&1 | grep -E 'Fehler|error|Error' || true
apt-get install -y \
    git \
    gcc \
    make \
    autoconf \
    automake \
    libtool \
    libusb-1.0-0-dev \
    libhidapi-dev \
    libhidapi-hidraw0 \
    libusb-1.0-0 \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    2>&1 | grep -vE '^(Lese|Les|Get|Hol|OK|Paket|ok\b|Trigger)' || true
ok "$T_DEPS_OK"

# ── Schritt 2: rogauracore bauen und installieren ────────────
step "$T_STEP_BUILD"

# Altes Build-Verzeichnis aufräumen (sicher auch wenn root-owned)
if [[ -d "$BUILD_DIR" ]]; then
    echo -e "  ${DIM}$T_CLEANUP${RST}"
    rm -rf "$BUILD_DIR" 2>/dev/null || { chmod -R u+w "$BUILD_DIR" 2>/dev/null; rm -rf "$BUILD_DIR"; }
fi

git clone --depth=1 "$ROGAURACORE_REPO" "$BUILD_DIR" 2>&1 | grep -vE '^(remote:|Klone|Cloning|Receive)' || true

# Prüfe ob Clone vollständig war
if [[ ! -f "$BUILD_DIR/configure.ac" || ! -f "$BUILD_DIR/Makefile.am" ]]; then
    echo -e "${ERR} $T_CLONE_FAIL"
    exit 1
fi
ok "$T_SOURCE_OK"

cd "$BUILD_DIR"
echo -e "  ${DIM}$T_AUTOCONF${RST}"
autoreconf -fi 2>&1 | grep -vE '^(configure.ac|Makefile)' | head -20 || true
echo -e "  ${DIM}$T_CONFIGURE${RST}"
./configure --prefix=/usr/local 2>&1 | tail -5
echo -e "  ${DIM}$T_COMPILE${RST}"
make -j"$(nproc)" 2>&1 | tail -10
ok "$T_BUILD_OK"

make install 2>&1 | grep -E 'install|Error|error' | head -10
ok "$T_INSTALL_OK $INSTALL_DIR"

# udev-Regeln aus dem Buildverzeichnis werden von make install gesetzt
# Regeln sofort aktivieren
udevadm control --reload-rules
udevadm trigger
ok "$T_UDEV_OK"

cd /

# ── Schritt 3: rog-rgb.sh installieren ──────────────────────
step "$T_STEP_SCRIPTS"

RGB_SOURCE="$SCRIPT_DIR/rog-rgb.sh"
if [[ -f "$RGB_SOURCE" ]]; then
    cp "$RGB_SOURCE" "$INSTALL_DIR/rog-rgb"
    chmod +x "$INSTALL_DIR/rog-rgb"
    ok "$T_SCRIPT_OK $INSTALL_DIR/rog-rgb"
else
    # Fallback: embedded minimal version
    cat > "$INSTALL_DIR/rog-rgb" << 'RGBSCRIPT'
#!/usr/bin/env bash
# ROG RGB terminal control (minimal fallback)
ROG_LANG="${ROG_LANG:-de}"
CMD="${1,,}"; HEX="${CMD#\#}"
rogauracore single_static "${HEX:-ff5500}" 2>/dev/null
echo 3 | sudo tee /sys/class/leds/asus::kbd_backlight/brightness > /dev/null 2>&1 || true
RGBSCRIPT
    chmod +x "$INSTALL_DIR/rog-rgb"
    ok "$T_SCRIPT_OK $INSTALL_DIR/rog-rgb"
fi

# ── Schritt 4: GUI installieren ─────────────────────────────
step "$T_STEP_GUI"

GUI_SOURCE="$SCRIPT_DIR/rog-rgb-gui.py"
if [[ -f "$GUI_SOURCE" ]]; then
    cp "$GUI_SOURCE" "$INSTALL_DIR/rog-rgb-gui"
    chmod +x "$INSTALL_DIR/rog-rgb-gui"
    ok "$T_GUI_OK $INSTALL_DIR"

    # .desktop Eintrag für Anwendungsmenü
    DESKTOP_DIR="$INSTALL_HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/rog-rgb-gui.desktop" << DESKTOPEOF
[Desktop Entry]
Name=ROG RGB Steuerung
Comment=ASUS ROG N-KEY Tastaturbeleuchtung grafisch steuern
Exec=$INSTALL_DIR/rog-rgb-gui
Icon=preferences-color
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
Keywords=asus;rog;rgb;keyboard;tastatur;beleuchtung;
StartupNotify=true
DESKTOPEOF
    chown "$INSTALL_USER:$INSTALL_USER" "$DESKTOP_DIR/rog-rgb-gui.desktop"
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    ok "$T_DESKTOP_OK"
else
    info "$T_GUI_SKIP"
fi

# ── Schritt 5: Diagnose-Script installieren ──────────────────
step "$T_STEP_DIAG"

# Diagnose-Script aus dem Projekt-Verzeichnis kopieren (falls vorhanden)
DIAG_SOURCE="$SCRIPT_DIR/rog-kbd-diagnose.sh"
if [[ -f "$DIAG_SOURCE" ]]; then
    cp "$DIAG_SOURCE" "$INSTALL_DIR/rog-kbd-diagnose"
    chmod +x "$INSTALL_DIR/rog-kbd-diagnose"
    ok "$T_DIAG_OK $INSTALL_DIR"
else
    info "$T_DIAG_SKIP"
fi

# ── Schritt 6: sudo-Regel für brightness ────────────────────
step "$T_STEP_SUDO"

cat > /etc/sudoers.d/rog-rgb << SUDORULE
# Erlaubt $INSTALL_USER die ROG Tastatur-Helligkeit ohne Passwort zu setzen
$INSTALL_USER ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/leds/asus\:\:kbd_backlight/brightness
SUDORULE

chmod 440 /etc/sudoers.d/rog-rgb
ok "$T_SUDO_OK"

# ── Schritt 7: systemd-Services anlegen ──────────────────────
step "$T_STEP_SVC"

cat > /etc/systemd/system/rog-rgb.service << SVCEOF
[Unit]
Description=ROG Tastatur RGB Beleuchtung wiederherstellen
After=multi-user.target

[Service]
Type=oneshot
User=root
ExecStart=/bin/sh -c 'echo 3 > /sys/class/leds/asus::kbd_backlight/brightness'
ExecStart=/bin/sh -c 'LAST=/home/${SERVICE_USER}/.config/rog-rgb/last_color; if [ -f "\$LAST" ]; then rogauracore \$(cat "\$LAST"); else rogauracore single_static ${DEFAULT_COLOR}; fi'
ExecStart=/bin/sh -c 'sleep 0.3 && echo 3 > /sys/class/leds/asus::kbd_backlight/brightness'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/rog-rgb-resume.service << SVCEOF
[Unit]
Description=ROG Tastatur RGB nach Suspend wiederherstellen
After=suspend.target hibernate.target hybrid-sleep.target
Wants=suspend.target hibernate.target hybrid-sleep.target

[Service]
Type=oneshot
User=root
ExecStart=/bin/sh -c 'echo 3 > /sys/class/leds/asus::kbd_backlight/brightness'
ExecStart=/bin/sh -c 'LAST=/home/${SERVICE_USER}/.config/rog-rgb/last_color; if [ -f "\$LAST" ]; then rogauracore \$(cat "\$LAST"); else rogauracore single_static ${DEFAULT_COLOR}; fi'
ExecStart=/bin/sh -c 'sleep 0.3 && echo 3 > /sys/class/leds/asus::kbd_backlight/brightness'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target
SVCEOF

systemctl daemon-reload
systemctl enable rog-rgb.service rog-rgb-resume.service 2>/dev/null
ok "$T_SVC1_OK"
ok "$T_SVC2_OK"

# ── Schritt 8: Standard-Konfiguration anlegen ────────────────
step "$T_STEP_CFG"

CONFIG_DIR="$INSTALL_HOME/.config/rog-rgb"
mkdir -p "$CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/last_color" ]]; then
    echo "single_static $DEFAULT_COLOR" > "$CONFIG_DIR/last_color"
    ok "$T_CFG_DEFAULT: #$DEFAULT_COLOR (Orange)"
else
    ok "$T_CFG_KEPT: $(cat "$CONFIG_DIR/last_color")"
fi
chown -R "$INSTALL_USER:$INSTALL_USER" "$CONFIG_DIR"

# ── Schritt 9: Sofort-Test ───────────────────────────────────
step "$T_STEP_TEST"

echo 3 > /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null || true
rogauracore single_static "$DEFAULT_COLOR" 2>&1 || true
RCORE_RC=$?
if [[ $RCORE_RC -eq 17 || $RCORE_RC -eq 0 ]]; then
    ok "$T_TEST_OK ${YLW}Orange (#$DEFAULT_COLOR)${RST}"
    echo 3 > /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null || true
else
    echo -e "${YLW}  [!] $T_TEST_WARN (RC=$RCORE_RC)${RST}"
fi

# ── Aufräumen ────────────────────────────────────────────────
rm -rf "$BUILD_DIR"

# ── Abschluss ────────────────────────────────────────────────
echo ""
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${GRN}  $T_DONE_TITLE${RST}"
echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""
if [[ "$ROG_LANG" == "en" ]]; then
    echo -e "  Available commands:"
    echo -e "    ${GRN}rog-rgb #ff0000${RST}           ${DIM}→ Red${RST}"
    echo -e "    ${GRN}rog-rgb breathe 0066ff${RST}    ${DIM}→ Blue breathing${RST}"
    echo -e "    ${GRN}rog-rgb rainbow${RST}           ${DIM}→ Rainbow${RST}"
    echo -e "    ${GRN}rog-rgb off${RST}               ${DIM}→ Turn off${RST}"
    echo -e "    ${GRN}rog-rgb status${RST}            ${DIM}→ Show status${RST}"
    echo -e "    ${GRN}rog-rgb-gui${RST}               ${DIM}→ Launch graphical GUI${RST}"
    echo -e "    ${GRN}rog-kbd-diagnose${RST}          ${DIM}→ Full diagnostic${RST}"
    echo ""
    echo -e "  ${MAG}GUI also in app menu under 'Settings → ROG RGB Control'${RST}"
else
    echo -e "  Verfügbare Befehle:"
    echo -e "    ${GRN}rog-rgb #ff0000${RST}           ${DIM}→ Rot${RST}"
    echo -e "    ${GRN}rog-rgb breathe 0066ff${RST}    ${DIM}→ Blaues Atmen${RST}"
    echo -e "    ${GRN}rog-rgb rainbow${RST}           ${DIM}→ Regenbogen${RST}"
    echo -e "    ${GRN}rog-rgb off${RST}               ${DIM}→ Ausschalten${RST}"
    echo -e "    ${GRN}rog-rgb status${RST}            ${DIM}→ Status anzeigen${RST}"
    echo -e "    ${GRN}rog-rgb-gui${RST}               ${DIM}→ Grafische Oberfläche starten${RST}"
    echo -e "    ${GRN}rog-kbd-diagnose${RST}          ${DIM}→ Vollständige Diagnose${RST}"
    echo ""
    echo -e "  ${MAG}GUI auch im Anwendungsmenü unter 'Einstellungen → ROG RGB Steuerung'${RST}"
fi
echo ""
echo -e "  ${DIM}Uninstall / Deinstallieren: sudo bash $0 --uninstall${RST}"
echo -e "  ${DIM}$T_DONE_LANG${RST}"
echo ""
