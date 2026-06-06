#!/usr/bin/env bash
# ============================================================
#  rog-fan  —  ROG Fan Control Wrapper (v0.4 / Track 2)
#  ASUS ROG Lüftersteuerung · asusctl v6 Frontend
#
#  Usage / Verwendung:
#    rog-fan status | quiet | balanced | performance | next
#    rog-fan watch [interval]
#    rog-fan curve <fan> <profile> "30c:0%,50c:20%,70c:50%,90c:100%"
#    rog-fan curve-show [profile]   curve-default <profile>
#    rog-fan restore | info | help
#    ROG_LANG=en rog-fan ...   (English output)
#
#  Hinweise:
#    - asusctl v6 will Profil-Namen capitalized (Quiet / Balanced / Performance)
#    - last_profile speichert lowercase (resume-service kompatibel)
#    - Script darf OHNE sudo laufen (DBus über asusd)
# ============================================================
# NOTE: bewusst KEIN `set -euo pipefail` — wir wollen graceful errors,
#       weil hwmon/sysfs/asusctl je nach State unterschiedlich antworten.

# ── Sprache / Language ───────────────────────────────────────
ROG_LANG="${ROG_LANG:-de}"

# ── Farben / Colors ──────────────────────────────────────────
RED='\033[1;31m'
GRN='\033[1;32m'
YLW='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
MAG='\033[1;35m'
WHT='\033[1;37m'
DIM='\033[2m'
RST='\033[0m'

# ── User-Erkennung (auch wenn versehentlich mit sudo gestartet) ─
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6)"
[[ -z "$REAL_HOME" ]] && REAL_HOME="$HOME"
CONFIG_DIR="$REAL_HOME/.config/rog-fan"
LAST_FILE="$CONFIG_DIR/last_profile"

VERSION="0.4"

# ── Bilinguale Texte ─────────────────────────────────────────
if [[ "$ROG_LANG" == "en" ]]; then
    OK="${GRN}[OK]${RST}";     WARN="${YLW}[WARN]${RST}"
    ERR="${RED}[ERR]${RST}";   INFO="${BLU}[INFO]${RST}";   STEP="${MAG}[>>]${RST}"
    T_HEADER1="ROG Fan Control"
    T_HEADER2="ASUS ROG Fan Control"
    T_PROFILE_CUR="Current profile"
    T_PLATFORM_PP="Platform profile (Kernel)"
    T_THROTTLE="throttle_thermal_policy"
    T_POWER="Power source"
    T_AC="AC (mains)"
    T_BAT="Battery"
    T_CPU_TEMP="CPU temperature"
    T_FANS="Fans"
    T_RPM="RPM"
    T_LAST_SAVED="Last saved"
    T_PROFILE_SET="Profile set"
    T_PROFILE_FAIL="Profile could not be set"
    T_PROFILE_INVALID="Invalid profile (allowed: quiet|balanced|performance)"
    T_FAN_INVALID="Invalid fan (allowed: cpu|gpu|mid)"
    T_DATA_INVALID="Invalid data format. Example: \"30c:0%,50c:20%,70c:50%,90c:100%\""
    T_NO_LAST="No saved profile in ~/.config/rog-fan/last_profile"
    T_ASUSCTL_MISS="asusctl is not installed. Install first: sudo bash install-rog-fan.sh"
    T_ASUSD_DOWN="asusd service is not running. Start: sudo systemctl start asusd"
    T_WATCHING="Live view (Ctrl+C to exit)"
    T_INTERVAL="Interval"
    T_CURVE_SET="Fan curve set"
    T_CURVE_FAIL="Failed to set fan curve"
    T_CURVE_RESET="Fan curve reset to default"
    T_CURVE_RESET_FAIL="Failed to reset fan curve"
    T_HELP_TITLE="USAGE"
    T_DIAGNOSE_HINT="If problems: bash rog-fan-diagnose.sh"
    T_NEED_PROFILE="A profile is required (quiet|balanced|performance)"
    T_NEED_FAN="Missing arguments. Usage: rog-fan curve <fan> <profile> \"<data>\""
    T_RESTORING="Restoring last profile"
    T_NO_HWMON="(no hwmon data)"
    T_BOARD="Board"
    T_UNKNOWN="unknown"
else
    OK="${GRN}[OK]${RST}";     WARN="${YLW}[WARNUNG]${RST}"
    ERR="${RED}[FEHLER]${RST}"; INFO="${BLU}[INFO]${RST}";   STEP="${MAG}[>>]${RST}"
    T_HEADER1="ROG Fan Control"
    T_HEADER2="ASUS ROG Lüftersteuerung"
    T_PROFILE_CUR="Aktuelles Profil"
    T_PLATFORM_PP="Plattform-Profil (Kernel)"
    T_THROTTLE="throttle_thermal_policy"
    T_POWER="Stromquelle"
    T_AC="Netz (AC)"
    T_BAT="Akku"
    T_CPU_TEMP="CPU-Temperatur"
    T_FANS="Lüfter"
    T_RPM="U/min"
    T_LAST_SAVED="Zuletzt gespeichert"
    T_PROFILE_SET="Profil gesetzt"
    T_PROFILE_FAIL="Profil konnte nicht gesetzt werden"
    T_PROFILE_INVALID="Ungültiges Profil (erlaubt: quiet|balanced|performance)"
    T_FAN_INVALID="Ungültiger Lüfter (erlaubt: cpu|gpu|mid)"
    T_DATA_INVALID="Ungültiges Daten-Format. Beispiel: \"30c:0%,50c:20%,70c:50%,90c:100%\""
    T_NO_LAST="Keine gespeicherte Profil-Datei in ~/.config/rog-fan/last_profile"
    T_ASUSCTL_MISS="asusctl ist nicht installiert. Installiere zuerst: sudo bash install-rog-fan.sh"
    T_ASUSD_DOWN="asusd Service läuft nicht. Starten: sudo systemctl start asusd"
    T_WATCHING="Live-Anzeige (Strg+C zum Beenden)"
    T_INTERVAL="Intervall"
    T_CURVE_SET="Lüfterkurve gesetzt"
    T_CURVE_FAIL="Lüfterkurve konnte nicht gesetzt werden"
    T_CURVE_RESET="Lüfterkurve auf Default zurückgesetzt"
    T_CURVE_RESET_FAIL="Default-Kurve konnte nicht gesetzt werden"
    T_HELP_TITLE="VERWENDUNG"
    T_DIAGNOSE_HINT="Bei Problemen: bash rog-fan-diagnose.sh"
    T_NEED_PROFILE="Profil fehlt (quiet|balanced|performance)"
    T_NEED_FAN="Argumente fehlen. Verwendung: rog-fan curve <fan> <profile> \"<data>\""
    T_RESTORING="Stelle letztes Profil wieder her"
    T_NO_HWMON="(keine hwmon-Daten)"
    T_BOARD="Board"
    T_UNKNOWN="unbekannt"
fi

# ── Helper: Logging ──────────────────────────────────────────
ok()   { echo -e "${OK} $*"; }
info() { echo -e "${INFO} $*"; }
warn() { echo -e "${WARN} $*"; }
err()  { echo -e "${ERR} $*" >&2; }
step() { echo -e "\n${STEP} ${WHT}$*${RST}"; }
die()  { err "$*"; exit 1; }

# ── Helper: Header ───────────────────────────────────────────
print_header() {
    echo -e "${MAG}"
    echo "  ╔════════════════════════════════════════╗"
    printf "  ║  %-36s  ║\n" "$T_HEADER1"
    printf "  ║  %-36s  ║\n" "$T_HEADER2"
    echo "  ╚════════════════════════════════════════╝"
    echo -e "${RST}"
}

print_header_small() {
    echo -e "${MAG}── ${WHT}$T_HEADER1${MAG} ──────────────────────${RST}"
}

# ── Profil-Normalisierung ────────────────────────────────────
# lowercase → "Quiet" / "Balanced" / "Performance"
normalize_profile_capital() {
    local p
    p="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    case "$p" in
        quiet|q|silent)        echo "Quiet" ;;
        balanced|b|balance)    echo "Balanced" ;;
        performance|p|perf|turbo) echo "Performance" ;;
        *) return 1 ;;
    esac
}

# anything → lowercase canonical
normalize_profile_lower() {
    local p
    p="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    case "$p" in
        quiet|q|silent)        echo "quiet" ;;
        balanced|b|balance)    echo "balanced" ;;
        performance|p|perf|turbo) echo "performance" ;;
        *) return 1 ;;
    esac
}

# Farb-Helper für Profil-Namen
color_profile() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        quiet)       echo -e "${BLU}$1${RST}" ;;
        balanced)    echo -e "${GRN}$1${RST}" ;;
        performance) echo -e "${YLW}$1${RST}" ;;
        *)           echo -e "${DIM}$1${RST}" ;;
    esac
}

color_temp() {
    # arg: temp in °C (int). echo colored "<val>°C"
    local t="$1"
    if   (( t < 60 )); then echo -e "${GRN}${t}°C${RST}"
    elif (( t < 80 )); then echo -e "${YLW}${t}°C${RST}"
    else                    echo -e "${RED}${t}°C${RST}"
    fi
}

color_rpm() {
    local r="$1"
    if   (( r == 0 ));    then echo -e "${DIM}${r} ${T_RPM}${RST}"
    elif (( r < 2500 ));  then echo -e "${CYN}${r} ${T_RPM}${RST}"
    elif (( r < 4500 ));  then echo -e "${GRN}${r} ${T_RPM}${RST}"
    else                       echo -e "${YLW}${r} ${T_RPM}${RST}"
    fi
}

# ── Precheck ─────────────────────────────────────────────────
precheck_or_die() {
    command -v asusctl &>/dev/null || die "$T_ASUSCTL_MISS"
    if [[ "$(systemctl is-active asusd 2>/dev/null)" != "active" ]]; then
        warn "$T_ASUSD_DOWN"
        # nicht abbrechen — status/sysfs funktioniert teilweise auch ohne
    fi
}

# ── last_profile schreiben (mit korrekter Ownership) ─────────
save_last_profile() {
    local lower="$1"
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    echo "$lower" > "$LAST_FILE" 2>/dev/null
    # Falls als root ausgeführt: ownership an REAL_USER zurückgeben
    if [[ $EUID -eq 0 ]] && [[ -n "$REAL_USER" ]] && [[ "$REAL_USER" != "root" ]]; then
        chown -R "$REAL_USER:$REAL_USER" "$CONFIG_DIR" 2>/dev/null || true
    fi
}

save_current_to_last() {
    local cur lower
    cur="$(asusctl profile get 2>/dev/null | awk -F: '/profile/ {print $2; exit} {print $NF; exit}' | tr -d ' \t')"
    [[ -z "$cur" ]] && return 1
    lower="$(normalize_profile_lower "$cur" 2>/dev/null)" || return 1
    save_last_profile "$lower"
}

# ── Aktuelles Profil holen ───────────────────────────────────
get_current_profile() {
    # asusctl profile get → variable Formatierung je nach Version, robust parsen
    local raw
    raw="$(asusctl profile get 2>/dev/null)"
    [[ -z "$raw" ]] && { echo "$T_UNKNOWN"; return 1; }
    # Suche nach Quiet/Balanced/Performance im Output
    local hit
    hit="$(echo "$raw" | grep -oiE 'Quiet|Balanced|Performance' | head -n1)"
    if [[ -n "$hit" ]]; then
        # Normalisiere auf Capitalized
        echo "$hit" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}'
    else
        echo "$raw" | tr -d ' \t\r\n'
    fi
}

# ── Sensor-Helper: höchste CPU-Temp ──────────────────────────
read_cpu_temp_max() {
    local max=0 hw name label val temp_c
    for hw in /sys/class/hwmon/hwmon*; do
        [[ -d "$hw" ]] || continue
        name="$(cat "$hw/name" 2>/dev/null)"
        case "$name" in
            k10temp|coretemp|zenpower|asusec|asus_ec|asus-isa-0000) ;;
            *) continue ;;
        esac
        for t in "$hw"/temp*_input; do
            [[ -r "$t" ]] || continue
            label=""
            local labelfile="${t%_input}_label"
            [[ -r "$labelfile" ]] && label="$(cat "$labelfile" 2>/dev/null)"
            # Bevorzuge Tdie/Tctl/Package/CPU
            if [[ "$name" == "k10temp" ]]; then
                [[ "$label" == "Tdie" || "$label" == "Tctl" || -z "$label" ]] || continue
            elif [[ "$name" == "coretemp" ]]; then
                [[ "$label" == Package* || -z "$label" ]] || continue
            fi
            val="$(cat "$t" 2>/dev/null)"
            [[ "$val" =~ ^-?[0-9]+$ ]] || continue
            temp_c=$(( val / 1000 ))
            (( temp_c > max )) && max=$temp_c
        done
    done
    echo "$max"
}

# ── Sensor-Helper: alle Fan-RPMs (Label \t RPM) ──────────────
read_fans() {
    local hw name f label val
    for hw in /sys/class/hwmon/hwmon*; do
        [[ -d "$hw" ]] || continue
        name="$(cat "$hw/name" 2>/dev/null)"
        for f in "$hw"/fan*_input; do
            [[ -r "$f" ]] || continue
            label=""
            local labelfile="${f%_input}_label"
            [[ -r "$labelfile" ]] && label="$(cat "$labelfile" 2>/dev/null)"
            [[ -z "$label" ]] && label="${name}:$(basename "$f" | sed 's/_input//')"
            val="$(cat "$f" 2>/dev/null)"
            [[ "$val" =~ ^[0-9]+$ ]] || val=0
            printf "%s\t%s\n" "$label" "$val"
        done
    done
}

# ── Power-Source Erkennung ───────────────────────────────────
read_power_source() {
    local ac_online=""
    for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        [[ -r "$ac" ]] || continue
        ac_online="$(cat "$ac" 2>/dev/null)"
        break
    done
    if [[ "$ac_online" == "1" ]]; then
        echo "AC"
    elif [[ "$ac_online" == "0" ]]; then
        echo "BAT"
    else
        echo "?"
    fi
}

read_battery_pct() {
    local bat
    for bat in /sys/class/power_supply/BAT*/capacity; do
        [[ -r "$bat" ]] || continue
        cat "$bat" 2>/dev/null
        return
    done
    echo ""
}

# ── Status (ausführlich) ─────────────────────────────────────
status() {
    print_header_small

    # Profil
    local cur cur_color
    cur="$(get_current_profile)"
    cur_color="$(color_profile "$cur")"
    echo -e "  ${WHT}${T_PROFILE_CUR}:${RST}        $cur_color"

    # platform_profile
    local pp="-"
    [[ -r /sys/firmware/acpi/platform_profile ]] && pp="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)"
    echo -e "  ${WHT}${T_PLATFORM_PP}:${RST}  $(color_profile "$pp")"

    # throttle_thermal_policy
    local ttp="-"
    [[ -r /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]] && \
        ttp="$(cat /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy 2>/dev/null)"
    local ttp_text="$ttp"
    case "$ttp" in
        0) ttp_text="0 (Balanced)" ;;
        1) ttp_text="1 (Performance)" ;;
        2) ttp_text="2 (Quiet)" ;;
    esac
    echo -e "  ${WHT}${T_THROTTLE}:${RST}    ${ttp_text}"

    # Power
    local src pct
    src="$(read_power_source)"
    pct="$(read_battery_pct)"
    case "$src" in
        AC)  echo -e "  ${WHT}${T_POWER}:${RST}            ${GRN}${T_AC}${RST}" ;;
        BAT) if [[ -n "$pct" ]]; then
                 echo -e "  ${WHT}${T_POWER}:${RST}            ${YLW}${T_BAT} (${pct}%)${RST}"
             else
                 echo -e "  ${WHT}${T_POWER}:${RST}            ${YLW}${T_BAT}${RST}"
             fi ;;
        *)   echo -e "  ${WHT}${T_POWER}:${RST}            ${DIM}?${RST}" ;;
    esac

    # Sensoren
    echo ""
    local temp
    temp="$(read_cpu_temp_max)"
    if [[ "$temp" -gt 0 ]]; then
        echo -e "  ${WHT}${T_CPU_TEMP}:${RST}        $(color_temp "$temp")"
    else
        echo -e "  ${WHT}${T_CPU_TEMP}:${RST}        ${DIM}${T_NO_HWMON}${RST}"
    fi

    echo -e "  ${WHT}${T_FANS}:${RST}"
    local fans_out
    fans_out="$(read_fans)"
    if [[ -z "$fans_out" ]]; then
        echo -e "    ${DIM}${T_NO_HWMON}${RST}"
    else
        while IFS=$'\t' read -r lbl val; do
            printf "    %-22s %s\n" "$lbl" "$(color_rpm "$val")"
        done <<< "$fans_out"
    fi

    # Last saved
    echo ""
    if [[ -r "$LAST_FILE" ]]; then
        local last
        last="$(cat "$LAST_FILE" 2>/dev/null)"
        echo -e "  ${DIM}${T_LAST_SAVED}: ${last}  (${LAST_FILE/$REAL_HOME/~})${RST}"
    else
        echo -e "  ${DIM}${T_LAST_SAVED}: — (${LAST_FILE/$REAL_HOME/~})${RST}"
    fi
}

# ── Status kompakt (für set_profile / watch) ────────────────
status_compact() {
    local cur pp temp src pct
    cur="$(get_current_profile)"
    pp="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo -)"
    temp="$(read_cpu_temp_max)"
    src="$(read_power_source)"
    pct="$(read_battery_pct)"

    local src_str="?"
    case "$src" in
        AC)  src_str="${GRN}AC${RST}" ;;
        BAT) src_str="${YLW}BAT${pct:+ ${pct}%}${RST}" ;;
    esac

    local temp_str="—"
    [[ "$temp" -gt 0 ]] && temp_str="$(color_temp "$temp")"

    echo -e "  $(color_profile "$cur")  ${DIM}|${RST}  pp=$(color_profile "$pp")  ${DIM}|${RST}  CPU $temp_str  ${DIM}|${RST}  $src_str"

    # Fans (eine Zeile pro Fan, knapp)
    local fans_out
    fans_out="$(read_fans)"
    if [[ -n "$fans_out" ]]; then
        while IFS=$'\t' read -r lbl val; do
            printf "  ${DIM}↳${RST} %-22s %s\n" "$lbl" "$(color_rpm "$val")"
        done <<< "$fans_out"
    fi
}

# ── Profil setzen ────────────────────────────────────────────
set_profile() {
    local arg="$1" cap lower
    cap="$(normalize_profile_capital "$arg" 2>/dev/null)" || { err "$T_PROFILE_INVALID"; return 2; }
    lower="$(normalize_profile_lower "$arg" 2>/dev/null)"

    if asusctl profile set "$cap" &>/dev/null; then
        save_last_profile "$lower"
        ok "${T_PROFILE_SET}: $(color_profile "$cap")"
        echo ""
        status_compact
        return 0
    else
        err "${T_PROFILE_FAIL}: $cap"
        # Show stderr for diagnosis
        asusctl profile set "$cap" 2>&1 | sed 's/^/    /'
        return 1
    fi
}

# ── Restore ──────────────────────────────────────────────────
restore() {
    if [[ ! -r "$LAST_FILE" ]]; then
        warn "$T_NO_LAST"
        return 1
    fi
    local last
    last="$(cat "$LAST_FILE" 2>/dev/null | tr -d ' \t\r\n')"
    if [[ -z "$last" ]]; then
        warn "$T_NO_LAST"
        return 1
    fi
    info "${T_RESTORING}: $(color_profile "$last")"
    set_profile "$last"
}

# ── Curve: anzeigen ──────────────────────────────────────────
curve_show() {
    local arg="${1:-}" cap
    if [[ -z "$arg" ]]; then
        arg="$(get_current_profile)"
    fi
    cap="$(normalize_profile_capital "$arg" 2>/dev/null)" || { err "$T_PROFILE_INVALID"; return 2; }
    asusctl fan-curve --mod-profile "$cap"
}

# ── Curve: default ───────────────────────────────────────────
curve_default() {
    local arg="${1:-}" cap
    [[ -z "$arg" ]] && { err "$T_NEED_PROFILE"; return 2; }
    cap="$(normalize_profile_capital "$arg" 2>/dev/null)" || { err "$T_PROFILE_INVALID"; return 2; }
    if asusctl fan-curve --mod-profile "$cap" --default &>/dev/null; then
        ok "${T_CURVE_RESET}: $(color_profile "$cap")"
    else
        err "$T_CURVE_RESET_FAIL"
        asusctl fan-curve --mod-profile "$cap" --default 2>&1 | sed 's/^/    /'
        return 1
    fi
}

# ── Curve: setzen ────────────────────────────────────────────
validate_curve_data() {
    # Grobe Plausi: mindestens ein "<num>c:<num>%" Token, komma-getrennt
    local d="$1"
    [[ -z "$d" ]] && return 1
    [[ "$d" != *c:* ]] && return 1
    [[ "$d" != *%* ]]  && return 1
    # mindestens ein Token muss matchen
    echo "$d" | grep -qiE '[0-9]+c:[0-9]+%' || return 1
    return 0
}

curve() {
    local fan="$1" prof="$2" data="${3:-}"

    if [[ -z "$fan" || -z "$prof" ]]; then
        err "$T_NEED_FAN"
        return 2
    fi

    case "$(echo "$fan" | tr '[:upper:]' '[:lower:]')" in
        cpu|gpu|mid) fan="$(echo "$fan" | tr '[:upper:]' '[:lower:]')" ;;
        *) err "$T_FAN_INVALID"; return 2 ;;
    esac

    local cap
    cap="$(normalize_profile_capital "$prof" 2>/dev/null)" || { err "$T_PROFILE_INVALID"; return 2; }

    if [[ -z "$data" ]]; then
        # Kein data → nur anzeigen
        curve_show "$prof"
        return $?
    fi

    if ! validate_curve_data "$data"; then
        err "$T_DATA_INVALID"
        return 2
    fi

    if asusctl fan-curve --mod-profile "$cap" --fan "$fan" --data "$data" --enable-fan-curve true &>/dev/null; then
        ok "${T_CURVE_SET}: $(color_profile "$cap") / ${fan}"
        info "data: $data"
    else
        err "${T_CURVE_FAIL}: $(color_profile "$cap") / ${fan}"
        asusctl fan-curve --mod-profile "$cap" --fan "$fan" --data "$data" --enable-fan-curve true 2>&1 | sed 's/^/    /'
        return 1
    fi
}

# ── Watch ────────────────────────────────────────────────────
watch_loop() {
    local interval="${1:-1}"
    # Validiere Intervall
    [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]] || interval=1

    trap 'echo; exit 0' INT

    while true; do
        [[ -t 1 ]] && clear
        print_header_small
        info "${T_WATCHING}  (${T_INTERVAL}: ${interval}s)"
        echo ""
        status_compact
        echo ""
        echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RST}"
        sleep "$interval"
    done
}

# ── Info ─────────────────────────────────────────────────────
cmd_info() {
    print_header_small
    if command -v asusctl &>/dev/null; then
        asusctl info 2>&1 | sed 's/^/  /'
    else
        warn "$T_ASUSCTL_MISS"
    fi
    echo ""
    echo -e "  ${WHT}rog-fan${RST} v${VERSION}  ${DIM}(Track 2)${RST}"
    echo -e "  ${DIM}${T_DIAGNOSE_HINT}${RST}"
    # Board info als Bonus
    if [[ -r /sys/devices/virtual/dmi/id/product_name ]]; then
        local board
        board="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
        [[ -n "$board" ]] && echo -e "  ${DIM}${T_BOARD}: ${board}${RST}"
    fi
}

# ── Help ─────────────────────────────────────────────────────
print_help() {
    print_header
    cat <<EOF
  ${WHT}${T_HELP_TITLE}${RST}

    ${CYN}rog-fan${RST} <command> [args]

  ${WHT}Profile / Profil:${RST}
    ${GRN}status${RST}              Profil + platform_profile + Temps + Fans + AC/BAT
                        Profile + platform profile + temps + fans + AC/BAT
    ${GRN}quiet${RST}               → ${BLU}Quiet${RST}        (asusctl profile set Quiet)
    ${GRN}balanced${RST}            → ${GRN}Balanced${RST}     (asusctl profile set Balanced)
    ${GRN}performance${RST}         → ${YLW}Performance${RST}  (asusctl profile set Performance)
    ${GRN}next${RST}                Nächstes Profil im Loop / Next profile in loop
    ${GRN}restore${RST}             Letztes gespeichertes Profil aus ~/.config/rog-fan/last_profile
                        Restore last saved profile from above file

  ${WHT}Live:${RST}
    ${GRN}watch${RST} [interval]    Live-Anzeige (default 1s) — Strg+C beendet
                        Live view (default 1s) — Ctrl+C exits

  ${WHT}Curves / Lüfterkurven:${RST}
    ${GRN}curve-show${RST} [profile]
                        Aktuelle Kurve anzeigen (default: aktuelles Profil)
                        Show current curve (default: current profile)

    ${GRN}curve-default${RST} <profile>
                        Default-Kurve für Profil setzen / reset curve to default
                        profile: quiet | balanced | performance

    ${GRN}curve${RST} <fan> <profile> "<data>"
                        Lüfterkurve setzen / set fan curve
                        fan:     cpu | gpu | mid
                        profile: quiet | balanced | performance
                        data:    "30c:0%,50c:20%,70c:50%,90c:100%"

                        Beispiel / Example:
                          rog-fan curve cpu performance "30c:0%,50c:20%,70c:50%,90c:100%"

  ${WHT}Info:${RST}
    ${GRN}info${RST}                asusctl Version + Board + rog-fan Version
    ${GRN}help${RST}, -h, --help    Diese Hilfe / This help

  ${WHT}Sprache / Language:${RST}
    ${DIM}ROG_LANG=en rog-fan ...${RST}      (English output)
    ${DIM}ROG_LANG=de rog-fan ...${RST}      (Deutsche Ausgabe, default)

  ${DIM}${T_DIAGNOSE_HINT}${RST}
EOF
}

# ── Main dispatch ────────────────────────────────────────────
main() {
    local cmd="${1:-status}"
    case "$cmd" in
        help|-h|--help)
            print_help
            ;;
        info)
            cmd_info
            ;;
        status|"")
            precheck_or_die
            status
            ;;
        quiet|balanced|performance|q|b|p|silent|perf|turbo|balance)
            precheck_or_die
            set_profile "$cmd"
            ;;
        next)
            precheck_or_die
            if asusctl profile next &>/dev/null; then
                sleep 0.3
                save_current_to_last || true
                status_compact
            else
                err "$T_PROFILE_FAIL"
                exit 1
            fi
            ;;
        watch)
            precheck_or_die
            watch_loop "${2:-1}"
            ;;
        restore)
            precheck_or_die
            restore
            ;;
        curve-show)
            precheck_or_die
            curve_show "${2:-}"
            ;;
        curve-default)
            precheck_or_die
            curve_default "${2:-}"
            ;;
        curve)
            precheck_or_die
            curve "${2:-}" "${3:-}" "${4:-}"
            ;;
        *)
            err "Unknown command: $cmd"
            echo ""
            print_help
            exit 2
            ;;
    esac
}

main "$@"
