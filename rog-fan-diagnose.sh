#!/usr/bin/env bash
# ============================================================
#  ROG Lüfter Diagnose-Tool
#  ASUS ROG Fan / Thermal Policy Troubleshooter
#  Für: Linux Mint / Ubuntu (Kernel 5.x / 6.x)
# ============================================================

RED='\033[1;31m'
GRN='\033[1;32m'
YLW='\033[1;33m'
BLU='\033[1;34m'
CYN='\033[1;36m'
MAG='\033[1;35m'
WHT='\033[1;37m'
DIM='\033[2m'
RST='\033[0m'

ISSUES=()
FIXES=()

FIX_MODE=0
for arg in "$@"; do
    case "$arg" in
        --fix|-f) FIX_MODE=1 ;;
    esac
done

ROG_LANG="${ROG_LANG:-de}"

if [[ "$ROG_LANG" == "en" ]]; then
    OK="${GRN}[OK]${RST}";   WARN="${YLW}[WARNING]${RST}"
    ERR="${RED}[ERROR]${RST}"; INFO="${BLU}[INFO]${RST}"; FIX="${MAG}[FIX]${RST}"
    T_SUBTITLE="ROG Fan & Thermal Diagnostic Tool"
    T_SEC1="1 · System Information"
    T_SEC2="2 · ASUS Kernel Modules"
    T_SEC3="3 · Throttle / Thermal Policy (sysfs)"
    T_SEC4="4 · Platform Profile (ACPI Kernel Interface)"
    T_SEC5="5 · Fan Curves (asus-nb-wmi)"
    T_SEC6="6 · Hardware Monitor (hwmon) – live data"
    T_SEC7="7 · asusctl (ASUS Linux Control Daemon)"
    T_SEC8="8 · Conflicting Tools (Conflict Check)"
    T_SEC9="9 · Kernel Messages (dmesg)"
    T_SEC10="10 · systemd Services & Suspend/Resume"
    T_SUMMARY="SUMMARY & RECOMMENDED FIXES"
    T_KERNEL="Kernel"
    T_DISTRO="Distro"
    T_VENDOR="Vendor"
    T_MODEL="Model"
    T_BOARD="Board"
    T_BIOS="BIOS"
    T_KERNEL_OK="Kernel version supports asus-nb-wmi fan control"
    T_KERNEL_OLD="Kernel < 5.15 — limited fan/thermal support"
    T_KERNEL_ISSUE="Kernel too old for full asus-nb-wmi support (current:"
    T_MOD_LOADED="Module loaded"
    T_MOD_AVAIL="Module available (not loaded)"
    T_MOD_MISSING="Module NOT available"
    T_MOD_ISSUE="Required kernel module missing:"
    T_MOD_FIX_HINT="(required for ASUS fan/thermal control)"
    T_TTP_LABEL="throttle_thermal_policy"
    T_TTP_PATH="Path"
    T_TTP_VALUE="Current value"
    T_TTP_0="0 (Balanced)"
    T_TTP_1="1 (Performance / Turbo)"
    T_TTP_2="2 (Silent / Quiet — fans suppressed!)"
    T_TTP_UNK="unknown"
    T_TTP_MISS="throttle_thermal_policy interface NOT present"
    T_TTP_MISS_NOTE="Without asus-nb-wmi this interface does not exist"
    T_TTP_ISSUE_MISS="throttle_thermal_policy interface missing — no fan control via sysfs"
    T_TTP_ISSUE_QUIET="throttle_thermal_policy = 2 (Quiet) while CPU temperature is high"
    T_TTP_FIX="echo 0 | sudo tee /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy"
    T_TTP_FIX_APPLIED="Set throttle_thermal_policy = 0 (Balanced)"
    T_TTP_FIX_FAIL="Could not set throttle_thermal_policy (sudo required)"
    T_PP_LABEL="platform_profile"
    T_PP_CHOICES="Available profiles"
    T_PP_ISSUE_QUIET="platform_profile = 'quiet' while CPU temperature is high"
    T_PP_FIX="echo balanced | sudo tee /sys/firmware/acpi/platform_profile"
    T_PP_FIX_APPLIED="Set platform_profile = balanced"
    T_PP_FIX_FAIL="Could not set platform_profile (sudo required)"
    T_PP_MISS="platform_profile interface NOT present"
    T_FC_NONE="No asus-nb-wmi hwmon node found"
    T_FC_FOUND="Fan/PWM interfaces found in"
    T_FC_QUIRK="Known quirk in dmesg:"
    T_FC_QUIRK_NOTE="This error is known on G7xx series and harmless — fan control still works via throttle_thermal_policy"
    T_FC_QUIRK_NONE="No fan_curve_get_factory_default quirk in dmesg (good)"
    T_HW_NAME="hwmon name"
    T_HW_TEMP="Temp"
    T_HW_FAN="Fan"
    T_HW_PWM="PWM"
    T_HW_PWM_EN="PWM enable"
    T_HW_RPM="RPM"
    T_HW_NO_HWMON="No hwmon entries found in /sys/class/hwmon/"
    T_HW_FANS_FOUND="Total fan tachometers detected:"
    T_HW_CPU_TEMP="Highest CPU temperature read:"
    T_HW_NO_TEMP="(no CPU temperature could be read)"
    T_HW_ISSUE_STILL="High CPU temperature but ALL fans report 0 RPM!"
    T_HW_ISSUE_STILL_CTX="Fans not spinning despite high temperature!"
    T_HW_FIX_STILL="Try: sudo modprobe -r asus_nb_wmi && sudo modprobe asus_nb_wmi"
    T_HW_ISA_FOUND="ASUS ISA sensor (asus-isa-0000) detected — G7xx series fan source"
    T_ASUSCTL_INST="asusctl installed:"
    T_ASUSCTL_VER="Version"
    T_ASUSD_OK="asusd service running"
    T_ASUSD_MISS="asusd service NOT running (status:"
    T_ASUSD_ISSUE="asusd service not active"
    T_ASUSD_FIX="sudo systemctl enable --now asusd"
    T_PROFILE_CUR="Current asusctl profile:"
    T_PROFILE_FAIL="(asusctl profile query failed)"
    T_ASUSCTL_MISS="asusctl is NOT installed"
    T_ASUSCTL_NOTE_FAN="asusctl is recommended for full fan control (custom curves)"
    T_ASUSCTL_ISSUE_FAN="asusctl not installed — recommended for full fan control"
    T_ASUSCTL_FIX_NOTE="Will be installed automatically via install-rog-fan.sh (coming in a future suite version)"
    T_CONFLICT_NONE="No conflicting fan tools installed"
    T_CONFLICT_FOUND="Conflicting tool found:"
    T_CONFLICT_NOTE="can conflict with asus_wmi"
    T_CONFLICT_ISSUE="Conflicting fan tool installed:"
    T_CONFLICT_FIX="sudo apt purge"
    T_FANCONTROL_ACTIVE="fancontrol.service is ACTIVE — likely conflicting"
    T_FANCONTROL_ISSUE="fancontrol.service active — conflicts with asus_wmi"
    T_FANCONTROL_FIX="sudo systemctl disable --now fancontrol.service"
    T_PPD_ACTIVE="power-profiles-daemon active"
    T_PPD_ASUSD_BOTH="Both power-profiles-daemon AND asusd active — both write platform_profile!"
    T_PPD_ASUSD_NOTE="Recommendation: disable one of them to avoid conflicts"
    T_TLP_ACTIVE="tlp.service active (informational — no conflict expected)"
    T_DMESG_INFO="Relevant kernel messages:"
    T_DMESG_NONE="(no relevant messages found)"
    T_DMESG_FALLBACK="(dmesg not accessible — falling back to journalctl)"
    T_DMESG_ACPI_ERR="ACPI BIOS errors detected (often cosmetic):"
    T_DMESG_THERMAL="Thermal trip events:"
    T_SVC_ASUSD_RUN="asusd running"
    T_SVC_ASUSD_STOP="asusd not running"
    T_SVC_ASUSD_NOPE="asusd not installed (skipping)"
    T_SVC_ROGFAN_NONE="rog-fan services not installed (will arrive in v0.3)"
    T_SVC_ROGFAN_OK="rog-fan services found:"
    T_SVC_RESUME_INFO="Recent suspend/resume events:"
    T_SVC_RESUME_NONE="(no suspend/resume data in current boot)"
    T_SVC_RESUME_RESET="platform_profile may have been reset after resume"
    T_NO_ISSUES="No critical problems found."
    T_MAYBE="Possible causes if fans still don't run correctly:"
    T_MAYBE1="EC profile in BIOS is set to 'Silent' (check ASUS BIOS / MyAsus)"
    T_MAYBE2="Fans run only above thermal threshold (check temperature under load)"
    T_MAYBE3="Custom fan curves require asusctl (not pure sysfs)"
    T_MAYBE4="After suspend, platform_profile / throttle_thermal_policy may revert"
    T_FOUND_ISSUES="Issues found"
    T_FIX_HEADER="Recommended fixes:"
    T_FIX_QUICK="Quick fix – set Balanced profile:"
    T_FIX_PERF="Force Performance / Turbo mode:"
    T_FIX_PP_BAL="Set platform_profile to balanced:"
    T_FIX_ASUSCTL_INST="Install asusctl (recommended):"
    T_FIX_PPA="Add PPA"
    T_FIX_MODE_HEADER="[--fix mode] Trying to apply safe fixes (Balanced profile)..."
    T_FIX_MODE_HINT="Run again with --fix to auto-apply safe Balanced profile (needs sudo)"
    T_FIX_MODE_ROOT_HINT="(--fix needs sudo — you will be prompted for your password)"
    T_TEMP_PROBE_LABEL="Pre-flight CPU temperature probe"
    T_TEMP_PROBE_VAL="Highest temperature reading"
else
    OK="${GRN}[OK]${RST}";   WARN="${YLW}[WARNUNG]${RST}"
    ERR="${RED}[FEHLER]${RST}"; INFO="${BLU}[INFO]${RST}"; FIX="${MAG}[FIX]${RST}"
    T_SUBTITLE="ROG Lüfter & Thermal Diagnose-Tool"
    T_SEC1="1 · System-Informationen"
    T_SEC2="2 · ASUS Kernel-Module"
    T_SEC3="3 · Throttle / Thermal Policy (sysfs)"
    T_SEC4="4 · Platform Profile (ACPI Kernel-Interface)"
    T_SEC5="5 · Fan Curves (asus-nb-wmi)"
    T_SEC6="6 · Hardware Monitor (hwmon) – Live-Daten"
    T_SEC7="7 · asusctl (ASUS Linux Steuerungsdienst)"
    T_SEC8="8 · Konkurrierende Tools (Konflikt-Check)"
    T_SEC9="9 · Kernel-Meldungen (dmesg)"
    T_SEC10="10 · systemd-Services & Suspend/Resume"
    T_SUMMARY="ZUSAMMENFASSUNG & LÖSUNGSVORSCHLÄGE"
    T_KERNEL="Kernel"
    T_DISTRO="Distro"
    T_VENDOR="Vendor"
    T_MODEL="Modell"
    T_BOARD="Board"
    T_BIOS="BIOS"
    T_KERNEL_OK="Kernel-Version unterstützt asus-nb-wmi Lüftersteuerung"
    T_KERNEL_OLD="Kernel < 5.15 — eingeschränkte Lüfter-/Thermal-Unterstützung"
    T_KERNEL_ISSUE="Kernel zu alt für vollständige asus-nb-wmi-Unterstützung (aktuell:"
    T_MOD_LOADED="Modul geladen"
    T_MOD_AVAIL="Modul verfügbar (nicht geladen)"
    T_MOD_MISSING="Modul NICHT verfügbar"
    T_MOD_ISSUE="Pflichtmodul fehlt:"
    T_MOD_FIX_HINT="(notwendig für ASUS Lüfter-/Thermalsteuerung)"
    T_TTP_LABEL="throttle_thermal_policy"
    T_TTP_PATH="Pfad"
    T_TTP_VALUE="Aktueller Wert"
    T_TTP_0="0 (Balanced)"
    T_TTP_1="1 (Performance / Turbo)"
    T_TTP_2="2 (Silent / Quiet — Lüfter unterdrückt!)"
    T_TTP_UNK="unbekannt"
    T_TTP_MISS="throttle_thermal_policy Interface NICHT vorhanden"
    T_TTP_MISS_NOTE="Ohne asus-nb-wmi existiert dieses Interface nicht"
    T_TTP_ISSUE_MISS="throttle_thermal_policy Interface fehlt — keine Lüftersteuerung via sysfs"
    T_TTP_ISSUE_QUIET="throttle_thermal_policy = 2 (Quiet) während CPU-Temperatur hoch ist"
    T_TTP_FIX="echo 0 | sudo tee /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy"
    T_TTP_FIX_APPLIED="throttle_thermal_policy = 0 (Balanced) gesetzt"
    T_TTP_FIX_FAIL="Konnte throttle_thermal_policy nicht setzen (sudo erforderlich)"
    T_PP_LABEL="platform_profile"
    T_PP_CHOICES="Verfügbare Profile"
    T_PP_ISSUE_QUIET="platform_profile = 'quiet' während CPU-Temperatur hoch ist"
    T_PP_FIX="echo balanced | sudo tee /sys/firmware/acpi/platform_profile"
    T_PP_FIX_APPLIED="platform_profile = balanced gesetzt"
    T_PP_FIX_FAIL="Konnte platform_profile nicht setzen (sudo erforderlich)"
    T_PP_MISS="platform_profile Interface NICHT vorhanden"
    T_FC_NONE="Kein asus-nb-wmi hwmon-Knoten gefunden"
    T_FC_FOUND="Fan/PWM-Interfaces gefunden in"
    T_FC_QUIRK="Bekannter Quirk in dmesg:"
    T_FC_QUIRK_NOTE="Dieser Fehler ist auf G7xx-Serie bekannt und harmlos — die Lüftersteuerung funktioniert trotzdem über throttle_thermal_policy"
    T_FC_QUIRK_NONE="Kein fan_curve_get_factory_default Quirk in dmesg (gut)"
    T_HW_NAME="hwmon-Name"
    T_HW_TEMP="Temp"
    T_HW_FAN="Lüfter"
    T_HW_PWM="PWM"
    T_HW_PWM_EN="PWM-Modus"
    T_HW_RPM="RPM"
    T_HW_NO_HWMON="Keine hwmon-Einträge in /sys/class/hwmon/ gefunden"
    T_HW_FANS_FOUND="Erkannte Lüfter-Tachos insgesamt:"
    T_HW_CPU_TEMP="Höchste CPU-Temperatur:"
    T_HW_NO_TEMP="(Keine CPU-Temperatur lesbar)"
    T_HW_ISSUE_STILL="Hohe CPU-Temperatur aber ALLE Lüfter melden 0 RPM!"
    T_HW_ISSUE_STILL_CTX="Lüfter drehen nicht trotz hoher Temperatur!"
    T_HW_FIX_STILL="Versuche: sudo modprobe -r asus_nb_wmi && sudo modprobe asus_nb_wmi"
    T_HW_ISA_FOUND="ASUS ISA Sensor (asus-isa-0000) erkannt — G7xx-Serie Lüfterquelle"
    T_ASUSCTL_INST="asusctl installiert:"
    T_ASUSCTL_VER="Version"
    T_ASUSD_OK="asusd-Service läuft"
    T_ASUSD_MISS="asusd-Service läuft NICHT (Status:"
    T_ASUSD_ISSUE="asusd-Dienst ist nicht aktiv"
    T_ASUSD_FIX="sudo systemctl enable --now asusd"
    T_PROFILE_CUR="Aktuelles asusctl Profil:"
    T_PROFILE_FAIL="(asusctl profile Abfrage fehlgeschlagen)"
    T_ASUSCTL_MISS="asusctl ist NICHT installiert"
    T_ASUSCTL_NOTE_FAN="asusctl wird für volle Lüfterkontrolle empfohlen (eigene Kurven)"
    T_ASUSCTL_ISSUE_FAN="asusctl nicht installiert — empfohlen für volle Lüfterkontrolle"
    T_ASUSCTL_FIX_NOTE="Wird automatisch via install-rog-fan.sh installiert (kommt in einer kommenden Suite-Version)"
    T_CONFLICT_NONE="Keine konkurrierenden Lüfter-Tools installiert"
    T_CONFLICT_FOUND="Konkurrierendes Tool gefunden:"
    T_CONFLICT_NOTE="kann mit asus_wmi kollidieren"
    T_CONFLICT_ISSUE="Konkurrierendes Lüfter-Tool installiert:"
    T_CONFLICT_FIX="sudo apt purge"
    T_FANCONTROL_ACTIVE="fancontrol.service ist AKTIV — wahrscheinlich Konflikt"
    T_FANCONTROL_ISSUE="fancontrol.service aktiv — kollidiert mit asus_wmi"
    T_FANCONTROL_FIX="sudo systemctl disable --now fancontrol.service"
    T_PPD_ACTIVE="power-profiles-daemon läuft"
    T_PPD_ASUSD_BOTH="power-profiles-daemon UND asusd beide aktiv — beide schreiben platform_profile!"
    T_PPD_ASUSD_NOTE="Empfehlung: einen der beiden Dienste deaktivieren um Konflikte zu vermeiden"
    T_TLP_ACTIVE="tlp.service aktiv (Info — kein Konflikt erwartet)"
    T_DMESG_INFO="Relevante Kernel-Meldungen:"
    T_DMESG_NONE="(keine relevanten Meldungen gefunden)"
    T_DMESG_FALLBACK="(dmesg nicht zugreifbar — Fallback auf journalctl)"
    T_DMESG_ACPI_ERR="ACPI BIOS Fehler gefunden (oft kosmetisch):"
    T_DMESG_THERMAL="Thermal trip Ereignisse:"
    T_SVC_ASUSD_RUN="asusd läuft"
    T_SVC_ASUSD_STOP="asusd läuft nicht"
    T_SVC_ASUSD_NOPE="asusd nicht installiert (übersprungen)"
    T_SVC_ROGFAN_NONE="rog-fan Services nicht installiert (kommen in v0.3)"
    T_SVC_ROGFAN_OK="rog-fan Services gefunden:"
    T_SVC_RESUME_INFO="Letzte Suspend/Resume-Ereignisse:"
    T_SVC_RESUME_NONE="(keine Suspend/Resume-Daten in aktuellem Boot)"
    T_SVC_RESUME_RESET="platform_profile wurde möglicherweise nach Resume zurückgesetzt"
    T_NO_ISSUES="Keine kritischen Probleme gefunden."
    T_MAYBE="Mögliche Ursachen wenn Lüfter trotzdem nicht richtig laufen:"
    T_MAYBE1="EC-Profil im BIOS steht auf 'Silent' (ASUS BIOS / MyAsus prüfen)"
    T_MAYBE2="Lüfter laufen erst ab Thermal-Schwelle (Temperatur unter Last prüfen)"
    T_MAYBE3="Eigene Lüfterkurven benötigen asusctl (kein reines sysfs)"
    T_MAYBE4="Nach Suspend können platform_profile / throttle_thermal_policy zurückspringen"
    T_FOUND_ISSUES="Gefundene Probleme"
    T_FIX_HEADER="Empfohlene Lösungen:"
    T_FIX_QUICK="Sofortlösung – Balanced-Profil setzen:"
    T_FIX_PERF="Performance / Turbo-Modus erzwingen:"
    T_FIX_PP_BAL="platform_profile auf balanced setzen:"
    T_FIX_ASUSCTL_INST="asusctl installieren (empfohlen):"
    T_FIX_PPA="PPA hinzufügen"
    T_FIX_MODE_HEADER="[--fix Modus] Wende sichere Fixes an (Balanced-Profil)..."
    T_FIX_MODE_HINT="Erneut mit --fix ausführen um Balanced-Profil automatisch anzuwenden (sudo nötig)"
    T_FIX_MODE_ROOT_HINT="(--fix benötigt sudo — du wirst nach deinem Passwort gefragt)"
    T_TEMP_PROBE_LABEL="Vorab-CPU-Temperatur-Messung"
    T_TEMP_PROBE_VAL="Höchste Temperatur"
fi

section() {
    echo ""
    echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo -e "${WHT}  $1${RST}"
    echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
}

add_issue() {
    ISSUES+=("$1")
}

add_fix() {
    FIXES+=("$1")
}

read_file_safe() {
    [[ -r "$1" ]] && cat "$1" 2>/dev/null || echo ""
}

probe_max_cpu_temp() {
    local max=0
    local val name
    for hw in /sys/class/hwmon/hwmon*; do
        [[ -d "$hw" ]] || continue
        name=$(read_file_safe "$hw/name")
        if [[ "$name" =~ ^(coretemp|k10temp|zenpower|asus-isa-0000|cpu_thermal|acpitz)$ ]]; then
            for t in "$hw"/temp*_input; do
                [[ -r "$t" ]] || continue
                val=$(cat "$t" 2>/dev/null)
                [[ -z "$val" ]] && continue
                val=$(( val / 1000 ))
                (( val > max )) && max=$val
            done
        fi
    done
    echo "$max"
}

# ─────────────────────────────────────────────────────────────
#  HEADER
# ─────────────────────────────────────────────────────────────
clear
echo -e "${MAG}"
echo "  ██████╗  ██████╗  ██████╗     ███████╗ █████╗ ███╗   ██╗"
echo "  ██╔══██╗██╔═══██╗██╔════╝     ██╔════╝██╔══██╗████╗  ██║"
echo "  ██████╔╝██║   ██║██║  ███╗    █████╗  ███████║██╔██╗ ██║"
echo "  ██╔══██╗██║   ██║██║   ██║    ██╔══╝  ██╔══██║██║╚██╗██║"
echo "  ██║  ██║╚██████╔╝╚██████╔╝    ██║     ██║  ██║██║ ╚████║"
echo "  ╚═╝  ╚═╝ ╚═════╝  ╚═════╝     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝"
echo -e "${RST}"
echo -e "  ${DIM}$T_SUBTITLE  •  $(date '+%d.%m.%Y %H:%M')${RST}"
if [[ $FIX_MODE -eq 1 ]]; then
    echo -e "  ${MAG}[--fix mode active]${RST}  ${DIM}$T_FIX_MODE_ROOT_HINT${RST}"
fi
echo ""

MAX_CPU_TEMP=$(probe_max_cpu_temp)
HIGH_TEMP_THRESHOLD=70
VERY_HIGH_TEMP_THRESHOLD=75

# ─────────────────────────────────────────────────────────────
#  1. SYSTEM INFO
# ─────────────────────────────────────────────────────────────
section "$T_SEC1"

KERNEL=$(uname -r)
DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Unknown")
VENDOR=$(read_file_safe /sys/devices/virtual/dmi/id/sys_vendor)
PRODUCT=$(read_file_safe /sys/devices/virtual/dmi/id/product_name)
BOARD=$(read_file_safe /sys/devices/virtual/dmi/id/board_name)
BIOS_VER=$(read_file_safe /sys/devices/virtual/dmi/id/bios_version)

echo -e "  ${INFO} $T_KERNEL  : ${WHT}$KERNEL${RST}"
echo -e "  ${INFO} $T_DISTRO  : ${WHT}$DISTRO${RST}"
echo -e "  ${INFO} $T_VENDOR  : ${WHT}${VENDOR:-?}${RST}"
echo -e "  ${INFO} $T_MODEL   : ${WHT}${PRODUCT:-?}${RST}"
echo -e "  ${INFO} $T_BOARD   : ${WHT}${BOARD:-?}${RST}"
echo -e "  ${INFO} $T_BIOS    : ${WHT}${BIOS_VER:-?}${RST}"

KERNEL_MAJOR=$(echo "$KERNEL" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL" | cut -d. -f2)
if [[ $KERNEL_MAJOR -gt 5 ]] || [[ $KERNEL_MAJOR -eq 5 && $KERNEL_MINOR -ge 15 ]]; then
    echo -e "  ${OK} $T_KERNEL_OK"
else
    echo -e "  ${WARN} $T_KERNEL_OLD"
    add_issue "$T_KERNEL_ISSUE $KERNEL)"
    add_fix "sudo apt install --install-recommends linux-generic-hwe-22.04"
fi

if [[ "$MAX_CPU_TEMP" -gt 0 ]]; then
    echo -e "  ${DIM}  $T_TEMP_PROBE_LABEL: $T_TEMP_PROBE_VAL ${MAX_CPU_TEMP}°C${RST}"
fi

# ─────────────────────────────────────────────────────────────
#  2. ASUS KERNEL MODULES
# ─────────────────────────────────────────────────────────────
section "$T_SEC2"

if [[ "$ROG_LANG" == "en" ]]; then
declare -A FAN_MODULES=(
    ["asus_wmi"]="ASUS WMI core interface (required)"
    ["asus_nb_wmi"]="ASUS Notebook WMI / fan control (required for laptops)"
    ["hid_asus"]="HID driver for ASUS keyboards"
)
declare -a FAN_MOD_ORDER=("asus_wmi" "asus_nb_wmi" "hid_asus")
else
declare -A FAN_MODULES=(
    ["asus_wmi"]="ASUS WMI Kerninterface (Pflicht)"
    ["asus_nb_wmi"]="ASUS Notebook WMI / Lüfterkontrolle (Pflicht für Laptops)"
    ["hid_asus"]="HID-Treiber für ASUS Tastaturen"
)
declare -a FAN_MOD_ORDER=("asus_wmi" "asus_nb_wmi" "hid_asus")
fi

for mod in "${FAN_MOD_ORDER[@]}"; do
    desc="${FAN_MODULES[$mod]}"
    if lsmod 2>/dev/null | grep -q "^${mod}\b"; then
        echo -e "  ${OK} $T_MOD_LOADED '${WHT}${mod}${RST}'  ${DIM}(${desc})${RST}"
    elif modinfo "$mod" >/dev/null 2>&1; then
        echo -e "  ${WARN} $T_MOD_AVAIL '${WHT}${mod}${RST}'  ${DIM}(${desc})${RST}"
        if [[ "$mod" == "asus_wmi" || "$mod" == "asus_nb_wmi" ]]; then
            add_issue "$T_MOD_ISSUE $mod $T_MOD_FIX_HINT"
            add_fix "sudo modprobe $mod"
        fi
    else
        echo -e "  ${ERR} $T_MOD_MISSING '${WHT}${mod}${RST}'  ${DIM}(${desc})${RST}"
        if [[ "$mod" == "asus_wmi" || "$mod" == "asus_nb_wmi" ]]; then
            add_issue "$T_MOD_ISSUE $mod $T_MOD_FIX_HINT"
            add_fix "sudo modprobe $mod"
        fi
    fi
done

# ─────────────────────────────────────────────────────────────
#  3. THROTTLE THERMAL POLICY
# ─────────────────────────────────────────────────────────────
section "$T_SEC3"

TTP_PATH="/sys/devices/platform/asus-nb-wmi/throttle_thermal_policy"
if [[ -e "$TTP_PATH" ]]; then
    TTP_VAL=$(read_file_safe "$TTP_PATH")
    echo -e "  ${OK} $T_TTP_LABEL"
    echo -e "  ${INFO} $T_TTP_PATH        : ${WHT}$TTP_PATH${RST}"
    case "$TTP_VAL" in
        0) TTP_TXT="$T_TTP_0"; TTP_COLOR="$GRN" ;;
        1) TTP_TXT="$T_TTP_1"; TTP_COLOR="$YLW" ;;
        2) TTP_TXT="$T_TTP_2"; TTP_COLOR="$RED" ;;
        *) TTP_TXT="$T_TTP_UNK ($TTP_VAL)"; TTP_COLOR="$DIM" ;;
    esac
    echo -e "  ${INFO} $T_TTP_VALUE : ${TTP_COLOR}${TTP_TXT}${RST}"

    if [[ "$TTP_VAL" == "2" && "$MAX_CPU_TEMP" -gt "$HIGH_TEMP_THRESHOLD" ]]; then
        echo -e "  ${ERR} $T_TTP_ISSUE_QUIET (${MAX_CPU_TEMP}°C)"
        add_issue "$T_TTP_ISSUE_QUIET (${MAX_CPU_TEMP}°C)"
        add_fix "$T_TTP_FIX"

        if [[ $FIX_MODE -eq 1 ]]; then
            if echo 0 | sudo tee "$TTP_PATH" >/dev/null 2>&1; then
                echo -e "  ${OK} $T_TTP_FIX_APPLIED"
            else
                echo -e "  ${ERR} $T_TTP_FIX_FAIL"
            fi
        fi
    fi
else
    echo -e "  ${ERR} $T_TTP_MISS"
    echo -e "        ${DIM}$T_TTP_MISS_NOTE${RST}"
    add_issue "$T_TTP_ISSUE_MISS"
    add_fix "sudo modprobe asus_nb_wmi"
fi

# ─────────────────────────────────────────────────────────────
#  4. PLATFORM PROFILE
# ─────────────────────────────────────────────────────────────
section "$T_SEC4"

PP_PATH="/sys/firmware/acpi/platform_profile"
PP_CHOICES_PATH="/sys/firmware/acpi/platform_profile_choices"

if [[ -e "$PP_PATH" ]]; then
    PP_VAL=$(read_file_safe "$PP_PATH")
    PP_CHOICES=$(read_file_safe "$PP_CHOICES_PATH")
    echo -e "  ${OK} $T_PP_LABEL"
    case "$PP_VAL" in
        quiet|low-power) PP_COLOR="$RED" ;;
        balanced)        PP_COLOR="$GRN" ;;
        performance)     PP_COLOR="$YLW" ;;
        *)               PP_COLOR="$DIM" ;;
    esac
    echo -e "  ${INFO} $T_TTP_VALUE : ${PP_COLOR}${PP_VAL}${RST}"
    echo -e "  ${INFO} $T_PP_CHOICES : ${WHT}${PP_CHOICES}${RST}"

    if [[ "$PP_VAL" == "quiet" && "$MAX_CPU_TEMP" -gt "$HIGH_TEMP_THRESHOLD" ]]; then
        echo -e "  ${ERR} $T_PP_ISSUE_QUIET (${MAX_CPU_TEMP}°C)"
        add_issue "$T_PP_ISSUE_QUIET (${MAX_CPU_TEMP}°C)"
        add_fix "$T_PP_FIX"

        if [[ $FIX_MODE -eq 1 ]]; then
            if echo balanced | sudo tee "$PP_PATH" >/dev/null 2>&1; then
                echo -e "  ${OK} $T_PP_FIX_APPLIED"
            else
                echo -e "  ${ERR} $T_PP_FIX_FAIL"
            fi
        fi
    fi

    if [[ $FIX_MODE -eq 1 && "$PP_VAL" == "quiet" && "$MAX_CPU_TEMP" -le "$HIGH_TEMP_THRESHOLD" ]]; then
        if echo balanced | sudo tee "$PP_PATH" >/dev/null 2>&1; then
            echo -e "  ${OK} $T_PP_FIX_APPLIED"
        fi
    fi
else
    echo -e "  ${WARN} $T_PP_MISS"
fi

# ─────────────────────────────────────────────────────────────
#  5. FAN CURVES
# ─────────────────────────────────────────────────────────────
section "$T_SEC5"

ASUS_HWMON_BASE="/sys/devices/platform/asus-nb-wmi"
FOUND_FAN_HWMON=0
if [[ -d "$ASUS_HWMON_BASE" ]]; then
    for hwdir in "$ASUS_HWMON_BASE"/hwmon/hwmon*; do
        [[ -d "$hwdir" ]] || continue
        FOUND_FAN_HWMON=1
        HWNAME=$(read_file_safe "$hwdir/name")
        echo -e "  ${OK} $T_FC_FOUND ${WHT}$hwdir${RST}  ${DIM}(${HWNAME:-?})${RST}"
        for f in "$hwdir"/pwm*_* "$hwdir"/fan*_*; do
            [[ -e "$f" ]] || continue
            base=$(basename "$f")
            val=$(read_file_safe "$f")
            echo -e "    ${DIM}→ ${base} = ${val}${RST}"
        done
    done
fi

if [[ $FOUND_FAN_HWMON -eq 0 ]]; then
    echo -e "  ${WARN} $T_FC_NONE"
fi

QUIRK_LINES=$(dmesg 2>/dev/null | grep -i "fan_curve_get_factory_default" | tail -3)
if [[ -z "$QUIRK_LINES" ]]; then
    QUIRK_LINES=$(journalctl -k --no-pager -q 2>/dev/null | grep -i "fan_curve_get_factory_default" | tail -3)
fi
if [[ -n "$QUIRK_LINES" ]]; then
    echo -e "  ${INFO} $T_FC_QUIRK"
    while IFS= read -r line; do
        echo -e "    ${DIM}→ $line${RST}"
    done <<< "$QUIRK_LINES"
    echo -e "        ${DIM}$T_FC_QUIRK_NOTE${RST}"
else
    echo -e "  ${OK} $T_FC_QUIRK_NONE"
fi

# ─────────────────────────────────────────────────────────────
#  6. HWMON LIVE DATA
# ─────────────────────────────────────────────────────────────
section "$T_SEC6"

FAN_COUNT=0
FAN_NONZERO_COUNT=0
HIGHEST_TEMP=0
FOUND_ASUS_ISA=0
HWMON_ANY=0

for hw in /sys/class/hwmon/hwmon*; do
    [[ -d "$hw" ]] || continue
    HWMON_ANY=1
    HWNAME=$(read_file_safe "$hw/name")
    [[ -z "$HWNAME" ]] && HWNAME="(unknown)"
    echo -e "  ${INFO} $T_HW_NAME : ${WHT}$HWNAME${RST}  ${DIM}($hw)${RST}"

    if [[ "$HWNAME" == "asus-isa-0000" ]]; then
        FOUND_ASUS_ISA=1
    fi

    for t in "$hw"/temp*_input; do
        [[ -r "$t" ]] || continue
        tval=$(cat "$t" 2>/dev/null)
        [[ -z "$tval" ]] && continue
        tlabel_path="${t%_input}_label"
        tlabel=$(read_file_safe "$tlabel_path")
        tname=$(basename "$t" _input)
        tc=$(( tval / 1000 ))
        if [[ "$HWNAME" =~ ^(coretemp|k10temp|zenpower|asus-isa-0000|cpu_thermal|acpitz)$ ]]; then
            (( tc > HIGHEST_TEMP )) && HIGHEST_TEMP=$tc
        fi
        if (( tc >= 80 )); then
            tcolor="$RED"
        elif (( tc >= 70 )); then
            tcolor="$YLW"
        else
            tcolor="$GRN"
        fi
        echo -e "    ${DIM}→${RST} $T_HW_TEMP ${tname}${tlabel:+ ($tlabel)} : ${tcolor}${tc}°C${RST}"
    done

    for fan in "$hw"/fan*_input; do
        [[ -r "$fan" ]] || continue
        fval=$(cat "$fan" 2>/dev/null)
        [[ -z "$fval" ]] && continue
        fname=$(basename "$fan" _input)
        flabel_path="${fan%_input}_label"
        flabel=$(read_file_safe "$flabel_path")
        FAN_COUNT=$(( FAN_COUNT + 1 ))
        if [[ "$fval" -gt 0 ]]; then
            FAN_NONZERO_COUNT=$(( FAN_NONZERO_COUNT + 1 ))
            fcolor="$GRN"
        else
            fcolor="$RED"
        fi
        echo -e "    ${DIM}→${RST} $T_HW_FAN ${fname}${flabel:+ ($flabel)} : ${fcolor}${fval} $T_HW_RPM${RST}"
    done

    for pwm in "$hw"/pwm[0-9]; do
        [[ -r "$pwm" ]] || continue
        pval=$(cat "$pwm" 2>/dev/null)
        [[ -z "$pval" ]] && continue
        pname=$(basename "$pwm")
        en_path="${pwm}_enable"
        en_val=$(read_file_safe "$en_path")
        echo -e "    ${DIM}→${RST} $T_HW_PWM ${pname} = ${WHT}${pval}${RST}  $T_HW_PWM_EN=${WHT}${en_val:-?}${RST}"
    done
done

if [[ $HWMON_ANY -eq 0 ]]; then
    echo -e "  ${ERR} $T_HW_NO_HWMON"
fi

echo ""
echo -e "  ${INFO} $T_HW_FANS_FOUND ${WHT}$FAN_COUNT${RST}  ${DIM}(non-zero: $FAN_NONZERO_COUNT)${RST}"
if [[ $HIGHEST_TEMP -gt 0 ]]; then
    echo -e "  ${INFO} $T_HW_CPU_TEMP ${WHT}${HIGHEST_TEMP}°C${RST}"
    if (( HIGHEST_TEMP > MAX_CPU_TEMP )); then
        MAX_CPU_TEMP=$HIGHEST_TEMP
    fi
else
    echo -e "  ${DIM}  $T_HW_NO_TEMP${RST}"
fi

if [[ $FOUND_ASUS_ISA -eq 1 ]]; then
    echo -e "  ${OK} $T_HW_ISA_FOUND"
fi

if [[ $FAN_COUNT -gt 0 && $FAN_NONZERO_COUNT -eq 0 && $HIGHEST_TEMP -gt $VERY_HIGH_TEMP_THRESHOLD ]]; then
    echo -e "  ${ERR} $T_HW_ISSUE_STILL_CTX"
    add_issue "$T_HW_ISSUE_STILL (${HIGHEST_TEMP}°C, $FAN_COUNT fans @ 0 RPM)"
    add_fix "$T_HW_FIX_STILL"
fi

# ─────────────────────────────────────────────────────────────
#  7. ASUSCTL
# ─────────────────────────────────────────────────────────────
section "$T_SEC7"

if command -v asusctl &>/dev/null; then
    ASUSCTL_VER=$(asusctl --version 2>/dev/null | head -1)
    echo -e "  ${OK} $T_ASUSCTL_INST ${WHT}$ASUSCTL_VER${RST}"

    if systemctl is-active --quiet asusd 2>/dev/null; then
        echo -e "  ${OK} $T_ASUSD_OK"
    else
        ASUSD_STATUS=$(systemctl is-enabled asusd 2>/dev/null)
        echo -e "  ${ERR} $T_ASUSD_MISS ${WHT}${ASUSD_STATUS:-?}${RST})"
        add_issue "$T_ASUSD_ISSUE"
        add_fix "$T_ASUSD_FIX"
    fi

    echo -e "  ${INFO} $T_PROFILE_CUR"
    PROFILE_OUT=$(asusctl profile -p 2>/dev/null || asusctl profile --profile-get 2>/dev/null)
    if [[ -n "$PROFILE_OUT" ]]; then
        while IFS= read -r line; do
            echo -e "    ${DIM}$line${RST}"
        done <<< "$PROFILE_OUT"
    else
        echo -e "    ${DIM}$T_PROFILE_FAIL${RST}"
    fi
else
    echo -e "  ${WARN} $T_ASUSCTL_MISS"
    echo -e "        ${DIM}$T_ASUSCTL_NOTE_FAN${RST}"
    add_issue "$T_ASUSCTL_ISSUE_FAN"
    add_fix "$T_ASUSCTL_FIX_NOTE"
fi

# ─────────────────────────────────────────────────────────────
#  8. CONFLICTING TOOLS
# ─────────────────────────────────────────────────────────────
section "$T_SEC8"

CONFLICT_TOOLS=("nbfc" "nbfc-linux" "fancontrol")
CONFLICT_FOUND_COUNT=0

for tool in "${CONFLICT_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null || dpkg -l "$tool" 2>/dev/null | grep -q "^ii"; then
        CONFLICT_FOUND_COUNT=$(( CONFLICT_FOUND_COUNT + 1 ))
        echo -e "  ${WARN} $T_CONFLICT_FOUND ${WHT}$tool${RST}  ${DIM}— $T_CONFLICT_NOTE${RST}"
        add_issue "$T_CONFLICT_ISSUE $tool"
        add_fix "$T_CONFLICT_FIX $tool"
    fi
done

if [[ $CONFLICT_FOUND_COUNT -eq 0 ]]; then
    echo -e "  ${OK} $T_CONFLICT_NONE"
fi

if systemctl is-active --quiet fancontrol.service 2>/dev/null; then
    echo -e "  ${ERR} $T_FANCONTROL_ACTIVE"
    add_issue "$T_FANCONTROL_ISSUE"
    add_fix "$T_FANCONTROL_FIX"
fi

PPD_ACTIVE=0
ASUSD_ACTIVE=0
if systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then
    PPD_ACTIVE=1
    echo -e "  ${INFO} $T_PPD_ACTIVE"
fi
if systemctl is-active --quiet asusd 2>/dev/null; then
    ASUSD_ACTIVE=1
fi
if [[ $PPD_ACTIVE -eq 1 && $ASUSD_ACTIVE -eq 1 ]]; then
    echo -e "  ${WARN} $T_PPD_ASUSD_BOTH"
    echo -e "        ${DIM}$T_PPD_ASUSD_NOTE${RST}"
    add_issue "$T_PPD_ASUSD_BOTH"
    add_fix "sudo systemctl disable --now power-profiles-daemon"
fi

if systemctl is-active --quiet tlp.service 2>/dev/null; then
    echo -e "  ${INFO} $T_TLP_ACTIVE"
fi

# ─────────────────────────────────────────────────────────────
#  9. DMESG MESSAGES
# ─────────────────────────────────────────────────────────────
section "$T_SEC9"

echo -e "  ${INFO} $T_DMESG_INFO"
DMESG_OUT=$(dmesg 2>/dev/null | grep -iE "asus|fan|thermal|throttle|acpi.*power" | tail -30)
DMESG_USED_FALLBACK=0
if [[ -z "$DMESG_OUT" ]]; then
    DMESG_OUT=$(journalctl -k --no-pager -q 2>/dev/null | grep -iE "asus|fan|thermal|throttle|acpi.*power" | tail -30)
    DMESG_USED_FALLBACK=1
fi

if [[ -n "$DMESG_OUT" ]]; then
    if [[ $DMESG_USED_FALLBACK -eq 1 ]]; then
        echo -e "    ${DIM}$T_DMESG_FALLBACK${RST}"
    fi
    while IFS= read -r line; do
        if echo "$line" | grep -qiE "error|fail|unable|timeout"; then
            echo -e "    ${RED}→ $line${RST}"
        elif echo "$line" | grep -qiE "warn"; then
            echo -e "    ${YLW}→ $line${RST}"
        else
            echo -e "    ${DIM}→ $line${RST}"
        fi
    done <<< "$DMESG_OUT"
else
    echo -e "    ${DIM}$T_DMESG_NONE${RST}"
fi

ACPI_ERRS=$(dmesg 2>/dev/null | grep -iE "ACPI BIOS Error|ACPI Error" | tail -5)
if [[ -n "$ACPI_ERRS" ]]; then
    echo ""
    echo -e "  ${INFO} $T_DMESG_ACPI_ERR"
    while IFS= read -r line; do
        echo -e "    ${DIM}→ $line${RST}"
    done <<< "$ACPI_ERRS"
fi

THERMAL_TRIPS=$(dmesg 2>/dev/null | grep -iE "thermal.*trip|critical.*temp" | tail -5)
if [[ -n "$THERMAL_TRIPS" ]]; then
    echo ""
    echo -e "  ${INFO} $T_DMESG_THERMAL"
    while IFS= read -r line; do
        echo -e "    ${YLW}→ $line${RST}"
    done <<< "$THERMAL_TRIPS"
fi

# ─────────────────────────────────────────────────────────────
# 10. SYSTEMD SERVICES & SUSPEND/RESUME
# ─────────────────────────────────────────────────────────────
section "$T_SEC10"

if command -v asusctl &>/dev/null; then
    if systemctl is-active --quiet asusd 2>/dev/null; then
        echo -e "  ${OK} $T_SVC_ASUSD_RUN"
    else
        echo -e "  ${WARN} $T_SVC_ASUSD_STOP"
    fi
else
    echo -e "  ${DIM}  $T_SVC_ASUSD_NOPE${RST}"
fi

ROG_FAN_FOUND=0
for svc in rog-fan.service rog-fan-resume.service; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^$svc"; then
        ROG_FAN_FOUND=1
        STATE=$(systemctl is-enabled "$svc" 2>/dev/null)
        ACT=$(systemctl is-active "$svc" 2>/dev/null)
        echo -e "  ${OK} $T_SVC_ROGFAN_OK $svc  ${DIM}(enabled=$STATE, active=$ACT)${RST}"
    fi
done
if [[ $ROG_FAN_FOUND -eq 0 ]]; then
    echo -e "  ${INFO} $T_SVC_ROGFAN_NONE"
fi

SUSPEND_LOG=$(journalctl -b 0 --no-pager -q 2>/dev/null | grep -iE "suspend|resume|wakeup" | tail -10)
if [[ -n "$SUSPEND_LOG" ]]; then
    echo ""
    echo -e "  ${INFO} $T_SVC_RESUME_INFO"
    while IFS= read -r line; do
        echo -e "    ${DIM}→ $line${RST}"
    done <<< "$SUSPEND_LOG"

    AFTER_RESUME=$(journalctl -b 0 --no-pager -q 2>/dev/null | grep -iE "platform_profile|throttle_thermal" | tail -5)
    if [[ -n "$AFTER_RESUME" ]]; then
        echo ""
        echo -e "  ${WARN} $T_SVC_RESUME_RESET"
        while IFS= read -r line; do
            echo -e "    ${YLW}→ $line${RST}"
        done <<< "$AFTER_RESUME"
    fi
else
    echo -e "  ${DIM}  $T_SVC_RESUME_NONE${RST}"
fi

# ─────────────────────────────────────────────────────────────
#  SUMMARY
# ─────────────────────────────────────────────────────────────
section "$T_SUMMARY"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GRN}$T_NO_ISSUES${RST}"
    echo ""
    echo -e "  ${INFO} $T_MAYBE"
    echo -e "    ${DIM}• $T_MAYBE1${RST}"
    echo -e "    ${DIM}• $T_MAYBE2${RST}"
    echo -e "    ${DIM}• $T_MAYBE3${RST}"
    echo -e "    ${DIM}• $T_MAYBE4${RST}"
else
    echo -e "  ${RED}$T_FOUND_ISSUES (${#ISSUES[@]}):${RST}"
    for i in "${!ISSUES[@]}"; do
        echo -e "  ${RED}  $(( i+1 )). ${ISSUES[$i]}${RST}"
    done
fi

echo ""
echo -e "  ${MAG}$T_FIX_HEADER${RST}"
echo ""

if [[ ${#FIXES[@]} -gt 0 ]]; then
    for i in "${!FIXES[@]}"; do
        echo -e "  ${FIX} ${WHT}$(( i+1 )).${RST} ${GRN}${FIXES[$i]}${RST}"
    done
    echo ""
fi

echo -e "  ${FIX} ${WHT}$T_FIX_QUICK${RST}"
echo -e "    ${GRN}echo 0 | sudo tee /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy${RST}"
echo -e "    ${GRN}echo balanced | sudo tee /sys/firmware/acpi/platform_profile${RST}"
echo ""

echo -e "  ${FIX} ${WHT}$T_FIX_PERF${RST}"
echo -e "    ${GRN}echo 1 | sudo tee /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy${RST}"
echo -e "    ${GRN}echo performance | sudo tee /sys/firmware/acpi/platform_profile${RST}"
echo ""

if ! command -v asusctl &>/dev/null; then
    echo -e "  ${FIX} ${WHT}$T_FIX_ASUSCTL_INST${RST}"
    echo -e "    ${DIM}# $T_FIX_PPA${RST}"
    echo -e "    ${GRN}sudo add-apt-repository ppa:asus-linux/mainline${RST}"
    echo -e "    ${GRN}sudo apt update${RST}"
    echo -e "    ${GRN}sudo apt install asusctl supergfxctl${RST}"
    echo -e "    ${GRN}sudo systemctl enable --now asusd supergfxd${RST}"
    echo ""
fi

echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""

if [[ $FIX_MODE -eq 1 ]]; then
    echo -e "${YLW}  $T_FIX_MODE_HEADER${RST}"
    if [[ -e "$TTP_PATH" ]]; then
        CUR=$(read_file_safe "$TTP_PATH")
        if [[ "$CUR" == "2" ]]; then
            if echo 0 | sudo tee "$TTP_PATH" >/dev/null 2>&1; then
                echo -e "  ${OK} $T_TTP_FIX_APPLIED"
            else
                echo -e "  ${ERR} $T_TTP_FIX_FAIL"
            fi
        fi
    fi
    if [[ -e "$PP_PATH" ]]; then
        CUR=$(read_file_safe "$PP_PATH")
        if [[ "$CUR" == "quiet" ]]; then
            if echo balanced | sudo tee "$PP_PATH" >/dev/null 2>&1; then
                echo -e "  ${OK} $T_PP_FIX_APPLIED"
            else
                echo -e "  ${ERR} $T_PP_FIX_FAIL"
            fi
        fi
    fi
else
    echo -e "  ${DIM}$T_FIX_MODE_HINT${RST}"
    echo ""
fi
