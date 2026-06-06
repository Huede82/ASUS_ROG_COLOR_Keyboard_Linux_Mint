#!/usr/bin/env bash
# ============================================================
#  ROG Suite Meta-Installer  |  ROG Linux Suite — RGB + Fan
#
#  Usage / Verwendung:
#    bash install-rog-suite.sh                       (install both: RGB → Fan)
#    bash install-rog-suite.sh --uninstall           (uninstall both: Fan → RGB)
#    bash install-rog-suite.sh --rgb-only            (RGB only)
#    bash install-rog-suite.sh --fan-only            (Fan only)
#    bash install-rog-suite.sh --lang en             (English output)
#    bash install-rog-suite.sh --uninstall --fan-only
#
#  Dünner Orchestrator über install-rog-rgb.sh + install-rog-fan.sh.
#  Keine Logik-Duplikation — alle apt/systemd/sudoers-Logik bleibt
#  vollständig in den Sub-Installern. Root einmalig am Anfang;
#  Sub-Installer werden dann direkt via `bash <script>` aufgerufen
#  (KEIN pkexec-in-pkexec, KEIN doppelter Auth-Prompt).
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
    notify-send "ROG Suite Installer" "Kein Terminal gefunden – bitte manuell ausführen:\nsudo bash $SELF" 2>/dev/null || true
    exit 1
fi

# ── CLI defaults ─────────────────────────────────────────────
MODE="install"
ONLY=""              # "" | "rgb" | "fan"
LANG_CLI=""

usage() {
    cat <<'USAGE'
Usage: bash install-rog-suite.sh [OPTIONS]

  (no flags)     Install both modules in order RGB → Fan
  --uninstall    Uninstall both modules in reverse order Fan → RGB
  --rgb-only     Limit operation to RGB module
  --fan-only     Limit operation to Fan module
  --lang de|en   UI language (default: de). Passed through to sub-installers.
  -h, --help     Show this help and exit

  --rgb-only and --fan-only are mutually exclusive.
USAGE
}

# ── Argument parsing ─────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --uninstall)
            MODE="uninstall"; shift ;;
        --rgb-only)
            if [[ "$ONLY" == "fan" ]]; then
                echo "ERROR: --rgb-only and --fan-only are mutually exclusive" >&2
                exit 1
            fi
            ONLY="rgb"; shift ;;
        --fan-only)
            if [[ "$ONLY" == "rgb" ]]; then
                echo "ERROR: --rgb-only and --fan-only are mutually exclusive" >&2
                exit 1
            fi
            ONLY="fan"; shift ;;
        --lang)
            if [[ -z "${2:-}" ]]; then
                echo "ERROR: --lang requires an argument (de|en)" >&2
                exit 1
            fi
            LANG_CLI="$2"; shift 2 ;;
        --lang=*)
            LANG_CLI="${1#--lang=}"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            echo "ERROR: Unknown flag: $1" >&2
            usage >&2
            exit 1 ;;
    esac
done

# ── Language resolution (CLI > env > prompt > default) ───────
if [[ -n "$LANG_CLI" ]]; then
    ROG_LANG="$LANG_CLI"
elif [[ -n "${ROG_LANG:-}" ]]; then
    : # keep inherited ROG_LANG
elif [[ -t 0 && -t 1 ]]; then
    read -rp "  Sprache wählen / Choose language [de/en]: " _lang_in || _lang_in=""
    case "${_lang_in,,}" in
        en|english) ROG_LANG="en" ;;
        *)          ROG_LANG="de" ;;
    esac
else
    ROG_LANG="de"
fi
case "$ROG_LANG" in
    de|en) ;;
    *)
        echo "ERROR: invalid --lang value '$ROG_LANG' (allowed: de|en)" >&2
        exit 1 ;;
esac
export ROG_LANG

# ── Colors ───────────────────────────────────────────────────
RED='\033[1;31m'; GRN='\033[1;32m'; YLW='\033[1;33m'
CYN='\033[1;36m'; MAG='\033[1;35m'; WHT='\033[1;37m'
DIM='\033[2m'; RST='\033[0m'

# ── i18n ─────────────────────────────────────────────────────
if [[ "$ROG_LANG" == "en" ]]; then
    OK="  ${GRN}[OK]${RST}";    ERR="  ${RED}[ERROR]${RST}"
    INFO="  ${CYN}[INFO]${RST}"; STEP="  ${MAG}[>>]${RST}"
    WARN="  ${YLW}[!]${RST}"
    T_HEADER_1="ROG Suite Meta-Installer"
    T_HEADER_2="ROG Linux Suite — RGB + Fan"
    T_TARGET_USER="Target user"
    T_HOME_DIR="Home directory"
    T_LANG="Language"
    T_MODE_INSTALL="Mode: install"
    T_MODE_UNINSTALL="Mode: uninstall (best-effort)"
    T_MODULE_BANNER="Module %d/%d: %s"
    T_STEP_RGB_INSTALL="Running RGB module installer"
    T_STEP_RGB_UNINSTALL="Running RGB module uninstaller"
    T_STEP_FAN_INSTALL="Running Fan module installer"
    T_STEP_FAN_UNINSTALL="Running Fan module uninstaller"
    T_RGB_OK="RGB module: success"
    T_RGB_FAIL="RGB module: FAILED (exit %d)"
    T_FAN_OK="Fan module: success"
    T_FAN_FAIL="Fan module: FAILED (exit %d)"
    T_MISSING_SCRIPT="Required sub-installer script missing in script directory: %s"
    T_SUMMARY_TITLE="Summary"
    T_SUMMARY_INSTALLED="installed"
    T_SUMMARY_UNINSTALLED="uninstalled"
    T_SUMMARY_FAILED="failed"
    T_SUMMARY_SKIPPED="skipped"
    T_DONE_INSTALL="Suite installation completed successfully."
    T_DONE_UNINSTALL="Suite uninstall pass completed (best-effort)."
    T_DONE_UNINSTALL_HARD="Suite uninstall pass completed with errors — all modules failed."
    T_INSTALL_HARD_FAIL="Module %s failed. Previously installed modules remain active.\n         Manual rollback if needed: bash install-rog-%s.sh --uninstall"
    T_ROOT_ERR="This script must be run with sudo:"
    T_CFG_KEPT_NOTE="User config under ~/.config/rog-rgb/ and ~/.config/rog-fan/ was NOT removed."
else
    OK="  ${GRN}[OK]${RST}";    ERR="  ${RED}[FEHLER]${RST}"
    INFO="  ${CYN}[INFO]${RST}"; STEP="  ${MAG}[>>]${RST}"
    WARN="  ${YLW}[!]${RST}"
    T_HEADER_1="ROG Suite Meta-Installer"
    T_HEADER_2="ROG Linux Suite — RGB + Fan"
    T_TARGET_USER="Ziel-Benutzer"
    T_HOME_DIR="Home-Verzeichnis"
    T_LANG="Sprache"
    T_MODE_INSTALL="Modus: Installation"
    T_MODE_UNINSTALL="Modus: Deinstallation (best-effort)"
    T_MODULE_BANNER="Modul %d/%d: %s"
    T_STEP_RGB_INSTALL="RGB-Modul-Installer starten"
    T_STEP_RGB_UNINSTALL="RGB-Modul-Deinstallation starten"
    T_STEP_FAN_INSTALL="Fan-Modul-Installer starten"
    T_STEP_FAN_UNINSTALL="Fan-Modul-Deinstallation starten"
    T_RGB_OK="RGB-Modul: erfolgreich"
    T_RGB_FAIL="RGB-Modul: FEHLGESCHLAGEN (Exit %d)"
    T_FAN_OK="Fan-Modul: erfolgreich"
    T_FAN_FAIL="Fan-Modul: FEHLGESCHLAGEN (Exit %d)"
    T_MISSING_SCRIPT="Erforderliches Sub-Installer-Skript fehlt im Skript-Verzeichnis: %s"
    T_SUMMARY_TITLE="Zusammenfassung"
    T_SUMMARY_INSTALLED="installiert"
    T_SUMMARY_UNINSTALLED="deinstalliert"
    T_SUMMARY_FAILED="fehlgeschlagen"
    T_SUMMARY_SKIPPED="übersprungen"
    T_DONE_INSTALL="Suite-Installation erfolgreich abgeschlossen."
    T_DONE_UNINSTALL="Suite-Deinstallation abgeschlossen (best-effort)."
    T_DONE_UNINSTALL_HARD="Suite-Deinstallation mit Fehlern beendet — alle Module fehlgeschlagen."
    T_INSTALL_HARD_FAIL="Modul %s ist fehlgeschlagen. Bereits installierte Module bleiben aktiv.\n         Manueller Rollback bei Bedarf: bash install-rog-%s.sh --uninstall"
    T_ROOT_ERR="Dieses Script muss mit sudo ausgeführt werden:"
    T_CFG_KEPT_NOTE="Benutzer-Konfiguration unter ~/.config/rog-rgb/ und ~/.config/rog-fan/ wurde NICHT entfernt."
fi

# ── Helpers ──────────────────────────────────────────────────
step() { echo -e "\n${STEP} ${WHT}$*${RST}"; }
ok()   { echo -e "${OK} $*"; }
info() { echo -e "${INFO} $*"; }
warn() { echo -e "${WARN} $*"; }
err()  { echo -e "${ERR} $*" >&2; }
die()  { err "$*"; [[ -t 1 ]] && read -rp "  [ Enter ]" _ 2>/dev/null || true; exit 1; }

# ── User detection (analog install-rog-fan.sh) ───────────────
detect_install_user() {
    local u=""
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        echo "$SUDO_USER"; return 0
    fi
    if [[ -n "${PKEXEC_UID:-}" ]]; then
        u=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
        if [[ -n "$u" && "$u" != "root" ]]; then
            echo "$u"; return 0
        fi
    fi
    while IFS=: read -r name _ uid _ _ home _; do
        if [[ "$uid" -ge 1000 && "$uid" -lt 65000 && -d "$home" ]]; then
            echo "$name"; return 0
        fi
    done < /etc/passwd
    echo "${USER:-root}"
}

INSTALL_USER="$(detect_install_user)"
INSTALL_HOME=$(getent passwd "$INSTALL_USER" | cut -d: -f6)
INSTALL_UID="$(id -u "$INSTALL_USER" 2>/dev/null || echo 0)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RGB_SCRIPT="$SCRIPT_DIR/install-rog-rgb.sh"
FAN_SCRIPT="$SCRIPT_DIR/install-rog-fan.sh"

# ── Header / banners ─────────────────────────────────────────
print_header() {
    [[ -t 1 ]] && clear
    echo -e "${MAG}"
    echo "  ╔════════════════════════════════════════════════════╗"
    printf "  ║ %-50s ║\n" "$T_HEADER_1"
    printf "  ║ %-50s ║\n" "$T_HEADER_2"
    echo "  ╚════════════════════════════════════════════════════╝"
    echo -e "${RST}"
    echo -e "${DIM}  $T_TARGET_USER : $INSTALL_USER${RST}"
    echo -e "${DIM}  $T_HOME_DIR: $INSTALL_HOME${RST}"
    echo -e "${DIM}  $T_LANG       : $ROG_LANG${RST}"
    if [[ "$MODE" == "install" ]]; then
        echo -e "${DIM}  $T_MODE_INSTALL${RST}"
    else
        echo -e "${DIM}  $T_MODE_UNINSTALL${RST}"
    fi
    echo ""
}

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

module_banner() {
    local n="$1" total="$2" name="$3"
    local label
    label=$(printf "$T_MODULE_BANNER" "$n" "$total" "$name")
    echo ""
    echo -e "${CYN}  ─── ${WHT}${label}${RST}${CYN} ───${RST}"
    echo ""
}

# ── Sub-installer invocation ─────────────────────────────────
# Already root here — call sub-installers directly via `bash`,
# never through pkexec/sudo again. Pass language + install user
# context as env so sub-installers detect the correct target user
# even though we entered as root.
run_sub() {
    local script="$1"; shift
    local rc=0
    set +e
    env ROG_LANG="$ROG_LANG" \
        SUDO_USER="$INSTALL_USER" \
        PKEXEC_UID="$INSTALL_UID" \
        bash "$script" "$@"
    rc=$?
    set -e
    return $rc
}

# ── Summary collection ───────────────────────────────────────
declare -a SUMMARY_LINES=()

add_summary_ok()      { SUMMARY_LINES+=("${GRN}✓${RST}  $1: $2"); }
add_summary_fail()    { SUMMARY_LINES+=("${RED}✗${RST}  $1: $2"); }
add_summary_skipped() { SUMMARY_LINES+=("${DIM}–  $1: $2${RST}"); }

print_summary() {
    echo ""
    echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo -e "  ${WHT}$T_SUMMARY_TITLE${RST}"
    echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    local line
    for line in "${SUMMARY_LINES[@]}"; do
        echo -e "  $line"
    done
    echo ""
}

# ── Selected modules ─────────────────────────────────────────
WANT_RGB=1
WANT_FAN=1
case "$ONLY" in
    rgb) WANT_FAN=0 ;;
    fan) WANT_RGB=0 ;;
esac
TOTAL=$(( WANT_RGB + WANT_FAN ))

# ── Pre-flight ───────────────────────────────────────────────
print_header
require_root

if [[ $WANT_RGB -eq 1 && ! -f "$RGB_SCRIPT" ]]; then
    die "$(printf "$T_MISSING_SCRIPT" "$RGB_SCRIPT")"
fi
if [[ $WANT_FAN -eq 1 && ! -f "$FAN_SCRIPT" ]]; then
    die "$(printf "$T_MISSING_SCRIPT" "$FAN_SCRIPT")"
fi

# ── Dispatch ─────────────────────────────────────────────────
IDX=0

if [[ "$MODE" == "install" ]]; then
    # Install order: RGB → Fan
    if [[ $WANT_RGB -eq 1 ]]; then
        IDX=$((IDX + 1))
        module_banner "$IDX" "$TOTAL" "RGB"
        step "$T_STEP_RGB_INSTALL"
        if run_sub "$RGB_SCRIPT"; then
            ok "$T_RGB_OK"
            add_summary_ok "RGB" "$T_SUMMARY_INSTALLED"
        else
            rc=$?
            err "$(printf "$T_RGB_FAIL" "$rc")"
            add_summary_fail "RGB" "$(printf "$T_RGB_FAIL" "$rc")"
            print_summary
            die "$(printf "$T_INSTALL_HARD_FAIL" "RGB" "rgb")"
        fi
    else
        add_summary_skipped "RGB" "$T_SUMMARY_SKIPPED"
    fi

    if [[ $WANT_FAN -eq 1 ]]; then
        IDX=$((IDX + 1))
        module_banner "$IDX" "$TOTAL" "Fan"
        step "$T_STEP_FAN_INSTALL"
        if run_sub "$FAN_SCRIPT"; then
            ok "$T_FAN_OK"
            add_summary_ok "Fan" "$T_SUMMARY_INSTALLED"
        else
            rc=$?
            err "$(printf "$T_FAN_FAIL" "$rc")"
            add_summary_fail "Fan" "$(printf "$T_FAN_FAIL" "$rc")"
            print_summary
            die "$(printf "$T_INSTALL_HARD_FAIL" "Fan" "fan")"
        fi
    else
        add_summary_skipped "Fan" "$T_SUMMARY_SKIPPED"
    fi

    print_summary
    echo -e "${GRN}  $T_DONE_INSTALL${RST}"
    echo ""
    exit 0
else
    # Uninstall order: Fan → RGB ; best-effort, never abort on sub-failure
    FAIL_COUNT=0
    EXEC_COUNT=0

    if [[ $WANT_FAN -eq 1 ]]; then
        IDX=$((IDX + 1))
        module_banner "$IDX" "$TOTAL" "Fan"
        step "$T_STEP_FAN_UNINSTALL"
        EXEC_COUNT=$((EXEC_COUNT + 1))
        if run_sub "$FAN_SCRIPT" --uninstall; then
            ok "$T_FAN_OK"
            add_summary_ok "Fan" "$T_SUMMARY_UNINSTALLED"
        else
            rc=$?
            warn "$(printf "$T_FAN_FAIL" "$rc")"
            add_summary_fail "Fan" "$(printf "$T_FAN_FAIL" "$rc")"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        add_summary_skipped "Fan" "$T_SUMMARY_SKIPPED"
    fi

    if [[ $WANT_RGB -eq 1 ]]; then
        IDX=$((IDX + 1))
        module_banner "$IDX" "$TOTAL" "RGB"
        step "$T_STEP_RGB_UNINSTALL"
        EXEC_COUNT=$((EXEC_COUNT + 1))
        if run_sub "$RGB_SCRIPT" --uninstall; then
            ok "$T_RGB_OK"
            add_summary_ok "RGB" "$T_SUMMARY_UNINSTALLED"
        else
            rc=$?
            warn "$(printf "$T_RGB_FAIL" "$rc")"
            add_summary_fail "RGB" "$(printf "$T_RGB_FAIL" "$rc")"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        add_summary_skipped "RGB" "$T_SUMMARY_SKIPPED"
    fi

    print_summary
    echo -e "${DIM}  $T_CFG_KEPT_NOTE${RST}"
    echo ""

    # Exit 1 only when every executed module failed
    if [[ $EXEC_COUNT -gt 0 && $FAIL_COUNT -eq $EXEC_COUNT ]]; then
        echo -e "${YLW}  $T_DONE_UNINSTALL_HARD${RST}"
        echo ""
        exit 1
    fi

    echo -e "${GRN}  $T_DONE_UNINSTALL${RST}"
    echo ""
    exit 0
fi
