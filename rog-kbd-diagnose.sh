#!/usr/bin/env bash
# ============================================================
#  ROG Tastatur RGB Diagnose-Tool
#  ASUS ROG / N-KEY Keyboard Backlight Troubleshooter
#  Für: Linux Mint / Ubuntu (Kernel 5.x / 6.x)
# ============================================================

# Farben
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

# ── Language / Sprache: de (Deutsch, default) | en (English) ─
ROG_LANG="${ROG_LANG:-de}"

if [[ "$ROG_LANG" == "en" ]]; then
    OK="${GRN}[OK]${RST}";   WARN="${YLW}[WARNING]${RST}"
    ERR="${RED}[ERROR]${RST}"; INFO="${BLU}[INFO]${RST}"; FIX="${MAG}[FIX]${RST}"
    T_SUBTITLE="RGB Keyboard Diagnostic Tool"
    T_SEC1="1 · System Information"
    T_SEC2="2 · ASUS N-KEY USB Device"
    T_SEC3="3 · Kernel Modules"
    T_SEC4="4 · Keyboard Backlight (sysfs)"
    T_SEC5="5 · HID Raw Interface"
    T_SEC6="6 · asusctl (ASUS Linux Control Daemon)"
    T_SEC7="7 · OpenRGB"
    T_SEC8="8 · Kernel Messages (dmesg)"
    T_SEC9="9 · udev Rules"
    T_SEC10="10 · Suspend/Resume"
    T_SUMMARY="SUMMARY & RECOMMENDED FIXES"
    T_KERNEL_OK="Kernel supports ASUS N-KEY RGB"
    T_KERNEL_OLD="Kernel < 5.11 — limited N-KEY RGB support"
    T_KERNEL_ISSUE="Kernel too old for full N-KEY RGB support (current:"
    T_NKEY_FOUND="N-KEY device detected:"
    T_NKEY_OTHER="ASUS N-KEY device (other PID):"
    T_NKEY_MISS="No ASUS N-KEY device found via USB"
    T_NKEY_ISSUE="N-KEY device not visible in lsusb"
    T_NKEY_FIX="Restart USB controller: echo 0 | sudo tee /sys/bus/usb/devices/usb1/power/control"
    T_ALL_ASUS="All ASUS USB devices:"
    T_MOD_LOADED="Module loaded"
    T_MOD_MISSING="Module NOT loaded"
    T_MOD_ISSUE="Kernel module missing:"
    T_LED_OK="LED interface present:"
    T_BRIGHTNESS="Brightness"
    T_TRIGGER="Active trigger"
    T_BR_ZERO="Brightness is 0 → keyboard is off!"
    T_BR_ZERO_ISSUE="kbd_backlight brightness = 0 (LED off)"
    T_BR_OK="Brightness > 0 (LED interface correct)"
    T_BR_WARN="Brightness set but no RGB effect active"
    T_BR_NOTE="The N-KEY device needs asusctl to set colors"
    T_BR_ISSUE="Brightness is"
    T_BR_ISSUE2="but no color/effect set"
    T_LED_MISS="does not exist!"
    T_LED_ISSUE="No asus::kbd_backlight interface in sysfs"
    T_LED_SIMILAR="Similar LED entries found:"
    T_LED_FIX="sudo modprobe hid_asus && sudo modprobe asus_nb_wmi"
    T_HID_FOUND="hidraw device for N-KEY:"
    T_HID_READ="is readable"
    T_HID_NOREAD="not directly readable (needs sudo/udev rule)"
    T_HID_ISSUE_READ="not readable without root"
    T_HID_ISSUE_FIX="Add udev rule for N-KEY (see summary)"
    T_HID_MISS="No hidraw entry found for 0B05:1866"
    T_HID_NOTE="(Normal if hid_asus has taken over the HID channel)"
    T_HID_ASUS="Possible ASUS hidraw device:"
    T_ASUSCTL_INST="asusctl installed:"
    T_ASUSD_OK="asusd service running"
    T_ASUSD_MISS="asusd service NOT running (Status:"
    T_ASUSD_ISSUE="asusd service not active"
    T_ASUSD_FIX="sudo systemctl enable --now asusd"
    T_AURA_MODE="Current AURA mode:"
    T_AURA_FAIL="(asusctl aura query failed)"
    T_ASUSCTL_MISS="asusctl is NOT installed"
    T_ASUSCTL_NOTE="asusctl is the main tool for ASUS ROG RGB under Linux"
    T_ASUSCTL_ISSUE="asusctl not installed – no RGB color control possible"
    T_ASUSCTL_FIX_NOTE="Install asusctl from the asus-linux PPA (see summary)"
    T_OPENRGB_INST="OpenRGB installed:"
    T_OPENRGB_DEVS="Detected devices (OpenRGB):"
    T_OPENRGB_TIMEOUT="(Timeout or error)"
    T_OPENRGB_MISS="OpenRGB not installed (optional, alternative to asusctl)"
    T_DMESG_INFO="Relevant messages:"
    T_DMESG_NONE="(No relevant messages found)"
    T_DMESG_ISSUE="dmesg error:"
    T_USB_WARN="USB errors found:"
    T_UDEV_OK="ASUS-relevant udev rules found:"
    T_UDEV_MISS="No custom ASUS udev rules"
    T_SUSPEND_INFO="Suspend/resume events found:"
    T_SUSPEND_WARN="Errors detected after resume – backlight goes off after suspend"
    T_SUSPEND_ISSUE="RGB turns off after suspend/resume"
    T_SUSPEND_FIX="asusctl post-resume hook or systemd-resume.service (see summary)"
    T_SUSPEND_OK="No obvious resume problem"
    T_SUSPEND_NONE="(No suspend/resume data in current boot)"
    T_NO_ISSUES="No critical problems found."
    T_MAYBE="Possible causes if backlight is still off:"
    T_MAYBE1="Color is set to black (needs asusctl to change)"
    T_MAYBE2="Effect was not restored after suspend/resume"
    T_MAYBE3="ASUS Armoury Crate profile was not transferred"
    T_FOUND_ISSUES="Issues found"
    T_FIX_ASUSCTL="Install asusctl (recommended):"
    T_FIX_PPA="Add PPA"
    T_FIX_BRIGHTNESS="Quick fix – set brightness:"
    T_FIX_AURA="Set RGB effect via asusctl:"
    T_FIX_RED="Red"
    T_FIX_GREEN_BREATHE="Green breathing"
    T_FIX_RAINBOW="Rainbow"
    T_FIX_UDEV="udev rule for N-KEY (without sudo):"
    T_FIX_SUSPEND="Restore backlight after suspend:"
    T_FIX_SUSPEND_CREATE="Create file:"
    T_FIX_SUSPEND_SVC="ROG keyboard after suspend"
    T_FIX_OPENRGB="OpenRGB as alternative (GUI):"
    T_FIX_OR_FROM="or from openrgb.org/PPA"
    T_FIX_MODE="[--fix mode] Trying to apply brightness fix..."
    T_FIX_BR_OK="Brightness set to 3"
    T_FIX_BR_ERR="Could not set brightness (sudo required)"
else
    OK="${GRN}[OK]${RST}";   WARN="${YLW}[WARNUNG]${RST}"
    ERR="${RED}[FEHLER]${RST}"; INFO="${BLU}[INFO]${RST}"; FIX="${MAG}[FIX]${RST}"
    T_SUBTITLE="RGB Tastatur Diagnose-Tool"
    T_SEC1="1 · System-Informationen"
    T_SEC2="2 · ASUS N-KEY USB-Gerät"
    T_SEC3="3 · Kernel-Module"
    T_SEC4="4 · Tastatur-Hintergrundbeleuchtung (sysfs)"
    T_SEC5="5 · HID Raw-Schnittstelle"
    T_SEC6="6 · asusctl (ASUS Linux Steuerungsdienst)"
    T_SEC7="7 · OpenRGB"
    T_SEC8="8 · Kernel-Meldungen (dmesg)"
    T_SEC9="9 · udev-Regeln"
    T_SEC10="10 · Suspend/Resume-Problem"
    T_SUMMARY="ZUSAMMENFASSUNG & LÖSUNGSVORSCHLÄGE"
    T_KERNEL_OK="Kernel-Version unterstützt ASUS N-KEY RGB"
    T_KERNEL_OLD="Kernel < 5.11 — eingeschränkte N-KEY RGB-Unterstützung"
    T_KERNEL_ISSUE="Kernel zu alt für vollständige N-KEY RGB-Unterstützung (aktuell:"
    T_NKEY_FOUND="N-KEY Gerät erkannt:"
    T_NKEY_OTHER="ASUS N-KEY Gerät (andere PID):"
    T_NKEY_MISS="Kein ASUS N-KEY Gerät via USB gefunden"
    T_NKEY_ISSUE="N-KEY Device nicht in lsusb sichtbar"
    T_NKEY_FIX="USB-Controller neustarten: echo 0 | sudo tee /sys/bus/usb/devices/usb1/power/control"
    T_ALL_ASUS="Alle ASUS USB-Geräte:"
    T_MOD_LOADED="Modul geladen"
    T_MOD_MISSING="Modul NICHT geladen"
    T_MOD_ISSUE="Kernel-Modul fehlt:"
    T_LED_OK="LED-Interface vorhanden:"
    T_BRIGHTNESS="Helligkeit"
    T_TRIGGER="Aktiver Trigger"
    T_BR_ZERO="Helligkeit ist 0 → Tastatur ist ausgeschaltet!"
    T_BR_ZERO_ISSUE="kbd_backlight Helligkeit = 0 (LED ausgeschaltet)"
    T_BR_OK="Helligkeit > 0 (LED-Interface korrekt)"
    T_BR_WARN="Helligkeit ist gesetzt, aber kein RGB-Effekt aktiv"
    T_BR_NOTE="Das N-KEY Gerät braucht asusctl um Farben zu setzen"
    T_BR_ISSUE="Helligkeit ist"
    T_BR_ISSUE2="aber keine Farbe/Effekt gesetzt"
    T_LED_MISS="existiert nicht!"
    T_LED_ISSUE="Kein asus::kbd_backlight Interface im sysfs"
    T_LED_SIMILAR="Ähnliche LED-Einträge gefunden:"
    T_LED_FIX="sudo modprobe hid_asus && sudo modprobe asus_nb_wmi"
    T_HID_FOUND="hidraw-Gerät für N-KEY:"
    T_HID_READ="ist lesbar"
    T_HID_NOREAD="nicht direkt lesbar (braucht sudo/udev-Regel)"
    T_HID_ISSUE_READ="nicht ohne root lesbar"
    T_HID_ISSUE_FIX="udev-Regel für N-KEY anlegen (siehe Zusammenfassung)"
    T_HID_MISS="Kein hidraw-Eintrag für 0B05:1866 gefunden"
    T_HID_NOTE="(Kann normal sein, wenn hid_asus den HID-Kanal übernimmt)"
    T_HID_ASUS="ASUS hidraw-Gerät (mögliches Match):"
    T_ASUSCTL_INST="asusctl installiert:"
    T_ASUSD_OK="asusd-Service läuft"
    T_ASUSD_MISS="asusd-Service läuft NICHT (Status:"
    T_ASUSD_ISSUE="asusd-Dienst ist nicht aktiv"
    T_ASUSD_FIX="sudo systemctl enable --now asusd"
    T_AURA_MODE="Aktueller AURA-Modus:"
    T_AURA_FAIL="(asusctl aura Abfrage fehlgeschlagen)"
    T_ASUSCTL_MISS="asusctl ist NICHT installiert"
    T_ASUSCTL_NOTE="asusctl ist das Hauptwerkzeug für ASUS ROG RGB unter Linux"
    T_ASUSCTL_ISSUE="asusctl nicht installiert – keine RGB-Farbsteuerung möglich"
    T_ASUSCTL_FIX_NOTE="asusctl aus dem asus-linux PPA installieren (siehe Zusammenfassung)"
    T_OPENRGB_INST="OpenRGB installiert:"
    T_OPENRGB_DEVS="Erkannte Geräte (OpenRGB):"
    T_OPENRGB_TIMEOUT="(Timeout oder Fehler)"
    T_OPENRGB_MISS="OpenRGB nicht installiert (optional, Alternative zu asusctl)"
    T_DMESG_INFO="Relevante Meldungen:"
    T_DMESG_NONE="(Keine relevanten Meldungen gefunden)"
    T_DMESG_ISSUE="dmesg Fehler:"
    T_USB_WARN="USB-Fehler gefunden:"
    T_UDEV_OK="ASUS-relevante udev-Regeln gefunden:"
    T_UDEV_MISS="Keine benutzerdefinierten ASUS udev-Regeln"
    T_SUSPEND_INFO="Suspend/Resume-Ereignisse gefunden:"
    T_SUSPEND_WARN="Fehler nach Resume erkannt – Beleuchtung geht nach Standby aus"
    T_SUSPEND_ISSUE="RGB geht nach Suspend/Resume aus"
    T_SUSPEND_FIX="asusctl post-resume Hook oder systemd-resume.service (siehe Zusammenfassung)"
    T_SUSPEND_OK="Kein offensichtliches Resume-Problem"
    T_SUSPEND_NONE="(Keine Suspend/Resume-Daten in aktuellem Boot)"
    T_NO_ISSUES="Keine kritischen Probleme gefunden."
    T_MAYBE="Mögliche Ursachen wenn trotzdem keine RGB-Beleuchtung:"
    T_MAYBE1="Farbe ist auf schwarz gesetzt (braucht asusctl zum Ändern)"
    T_MAYBE2="Nach Suspend/Resume wurde Effekt nicht wiederhergestellt"
    T_MAYBE3="ASUS Armoury Crate Profil wurde nicht übertragen"
    T_FOUND_ISSUES="Gefundene Probleme"
    T_FIX_ASUSCTL="asusctl installieren (empfohlen):"
    T_FIX_PPA="PPA hinzufügen"
    T_FIX_BRIGHTNESS="Sofortlösung – Helligkeit setzen:"
    T_FIX_AURA="RGB-Effekt via asusctl setzen:"
    T_FIX_RED="Rot"
    T_FIX_GREEN_BREATHE="Grünes Atmen"
    T_FIX_RAINBOW="Regenbogen"
    T_FIX_UDEV="udev-Regel für N-KEY (ohne sudo):"
    T_FIX_SUSPEND="Beleuchtung nach Standby wiederherstellen:"
    T_FIX_SUSPEND_CREATE="Datei anlegen:"
    T_FIX_SUSPEND_SVC="ROG Tastaturbeleuchtung nach Suspend"
    T_FIX_OPENRGB="OpenRGB als Alternative (GUI):"
    T_FIX_OR_FROM="oder von openrgb.org/PPA"
    T_FIX_MODE="[--fix Modus] Versuche Helligkeits-Fix anzuwenden..."
    T_FIX_BR_OK="Helligkeit auf 3 gesetzt"
    T_FIX_BR_ERR="Konnte Helligkeit nicht setzen (sudo erforderlich)"
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

# ─────────────────────────────────────────────────────────────
#  HEADER
# ─────────────────────────────────────────────────────────────
clear
echo -e "${MAG}"
echo "  ██████╗  ██████╗  ██████╗     ██╗  ██╗██████╗ ██████╗ "
echo "  ██╔══██╗██╔═══██╗██╔════╝     ██║ ██╔╝██╔══██╗██╔══██╗"
echo "  ██████╔╝██║   ██║██║  ███╗    █████╔╝ ██████╔╝██║  ██║"
echo "  ██╔══██╗██║   ██║██║   ██║    ██╔═██╗ ██╔══██╗██║  ██║"
echo "  ██║  ██║╚██████╔╝╚██████╔╝    ██║  ██╗██████╔╝██████╔╝"
echo "  ╚═╝  ╚═╝ ╚═════╝  ╚═════╝     ╚═╝  ╚═╝╚═════╝ ╚═════╝ "
echo -e "${RST}"
echo -e "  ${DIM}$T_SUBTITLE  •  $(date '+%d.%m.%Y %H:%M')${RST}"
echo ""

# ─────────────────────────────────────────────────────────────
#  1. SYSTEM INFO
# ─────────────────────────────────────────────────────────────
section "$T_SEC1"

KERNEL=$(uname -r)
DISTRO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Unbekannt")
echo -e "  ${INFO} Kernel  : ${WHT}$KERNEL${RST}"
echo -e "  ${INFO} Distro  : ${WHT}$DISTRO${RST}"

# Kernel >= 5.11 empfohlen für N-KEY RGB support
KERNEL_MAJOR=$(echo "$KERNEL" | cut -d. -f1)
KERNEL_MINOR=$(echo "$KERNEL" | cut -d. -f2)
if [[ $KERNEL_MAJOR -gt 5 ]] || [[ $KERNEL_MAJOR -eq 5 && $KERNEL_MINOR -ge 11 ]]; then
    echo -e "  ${OK} $T_KERNEL_OK: $KERNEL"
else
    echo -e "  ${WARN} $T_KERNEL_OLD"
    add_issue "$T_KERNEL_ISSUE $KERNEL)"
    add_fix "sudo apt install --install-recommends linux-generic-hwe-22.04"
fi

# ─────────────────────────────────────────────────────────────
#  2. USB GERÄT
# ─────────────────────────────────────────────────────────────
section "$T_SEC2"

USB_LINE=$(lsusb 2>/dev/null | grep -i "0b05:1866")
if [[ -n "$USB_LINE" ]]; then
    echo -e "  ${OK} $T_NKEY_FOUND ${WHT}$USB_LINE${RST}"
else
    # Suche nach anderen bekannten ASUS N-KEY IDs
    OTHER_NKEY=$(lsusb 2>/dev/null | grep -iE "0b05:(19b6|1854|1869|196b|1822)")
    if [[ -n "$OTHER_NKEY" ]]; then
        echo -e "  ${OK} $T_NKEY_OTHER ${WHT}$OTHER_NKEY${RST}"
    else
        echo -e "  ${ERR} $T_NKEY_MISS"
        add_issue "$T_NKEY_ISSUE"
        add_fix "$T_NKEY_FIX"
    fi
fi

# Alle ASUS USB-Geräte anzeigen
echo -e "  ${DIM}  $T_ALL_ASUS${RST}"
lsusb 2>/dev/null | grep -i "0b05" | while read -r line; do
    echo -e "    ${DIM}→ $line${RST}"
done

# ─────────────────────────────────────────────────────────────
#  3. KERNEL MODULE
# ─────────────────────────────────────────────────────────────
section "$T_SEC3"

if [[ "$ROG_LANG" == "en" ]]; then
declare -A REQUIRED_MODULES=(
    ["hid_asus"]="HID driver for ASUS keyboards (required)"
    ["asus_wmi"]="ASUS WMI interface (required)"
    ["asus_nb_wmi"]="ASUS Notebook WMI extension (recommended)"
)
else
declare -A REQUIRED_MODULES=(
    ["hid_asus"]="HID-Treiber für ASUS Tastaturen (Pflicht)"
    ["asus_wmi"]="ASUS WMI Interface (Pflicht)"
    ["asus_nb_wmi"]="ASUS Notebook WMI Erweiterung (Empfohlen)"
)
fi

for mod in "${!REQUIRED_MODULES[@]}"; do
    if lsmod | grep -q "^${mod}\b" 2>/dev/null; then
        echo -e "  ${OK} $T_MOD_LOADED '${WHT}${mod}${RST}'  ${DIM}(${REQUIRED_MODULES[$mod]})${RST}"
    else
        echo -e "  ${ERR} $T_MOD_MISSING '${WHT}${mod}${RST}'  ${DIM}(${REQUIRED_MODULES[$mod]})${RST}"
        add_issue "$T_MOD_ISSUE $mod"
        add_fix "sudo modprobe $mod"
    fi
done

# ─────────────────────────────────────────────────────────────
#  4. SYSFS LED INTERFACE
# ─────────────────────────────────────────────────────────────
section "$T_SEC4"

LED_PATH="/sys/class/leds/asus::kbd_backlight"
if [[ -d "$LED_PATH" ]]; then
    BRIGHTNESS=$(cat "$LED_PATH/brightness" 2>/dev/null)
    MAX_BRIGHTNESS=$(cat "$LED_PATH/max_brightness" 2>/dev/null)
    TRIGGER=$(cat "$LED_PATH/trigger" 2>/dev/null | grep -oP '\[.*?\]' | tr -d '[]')

    echo -e "  ${OK} $T_LED_OK ${WHT}$LED_PATH${RST}"
    echo -e "  ${INFO} $T_BRIGHTNESS       : ${WHT}$BRIGHTNESS${RST} / ${WHT}$MAX_BRIGHTNESS${RST}"
    echo -e "  ${INFO} $T_TRIGGER  : ${WHT}${TRIGGER:-none}${RST}"

    if [[ "$BRIGHTNESS" -eq 0 ]]; then
        echo -e "  ${ERR} $T_BR_ZERO"
        add_issue "$T_BR_ZERO_ISSUE"
        add_fix "echo 3 | sudo tee $LED_PATH/brightness"
    else
        echo -e "  ${OK} $T_BR_OK"
        echo -e "  ${WARN} $T_BR_WARN"
        echo -e "        ${DIM}→ $T_BR_NOTE${RST}"
        add_issue "$T_BR_ISSUE $BRIGHTNESS/$MAX_BRIGHTNESS, $T_BR_ISSUE2"
        add_fix "sudo apt install asusctl"
    fi
else
    echo -e "  ${ERR} ${WHT}$LED_PATH${RST} $T_LED_MISS"
    add_issue "$T_LED_ISSUE"

    # Suche nach ähnlichen Einträgen
    SIMILAR=$(ls /sys/class/leds/ 2>/dev/null | grep -i "kbd\|backlight\|asus")
    if [[ -n "$SIMILAR" ]]; then
        echo -e "  ${INFO} $T_LED_SIMILAR"
        echo "$SIMILAR" | while read -r entry; do
            echo -e "    ${DIM}→ /sys/class/leds/$entry${RST}"
        done
    fi
    add_fix "$T_LED_FIX"
fi

# ─────────────────────────────────────────────────────────────
#  5. HIDRAW GERÄT
# ─────────────────────────────────────────────────────────────
section "$T_SEC5"

HIDRAW_FOUND=0
for hraw in /sys/class/hidraw/hidraw*/device/uevent; do
    if grep -q "0B05:1866\|0B05.*1866" "$hraw" 2>/dev/null; then
        HIDRAW_NAME=$(echo "$hraw" | grep -oP 'hidraw\d+')
        echo -e "  ${OK} $T_HID_FOUND ${WHT}/dev/$HIDRAW_NAME${RST}"
        # Prüfe Zugriffsrechte
        if [[ -r "/dev/$HIDRAW_NAME" ]]; then
            echo -e "  ${OK} /dev/$HIDRAW_NAME $T_HID_READ"
        else
            echo -e "  ${WARN} /dev/$HIDRAW_NAME $T_HID_NOREAD"
            add_issue "/dev/$HIDRAW_NAME $T_HID_ISSUE_READ"
            add_fix "$T_HID_ISSUE_FIX"
        fi
        HIDRAW_FOUND=1
    fi
done

# Fallback: Suche über uevent-Dateien
if [[ $HIDRAW_FOUND -eq 0 ]]; then
    for hraw in /sys/class/hidraw/hidraw*/device/uevent; do
        if grep -qi "asus\|0b05" "$hraw" 2>/dev/null; then
            HIDRAW_NAME=$(echo "$hraw" | grep -oP 'hidraw\d+')
            echo -e "  ${INFO} $T_HID_ASUS ${WHT}/dev/$HIDRAW_NAME${RST}"
            HIDRAW_FOUND=1
        fi
    done
fi

if [[ $HIDRAW_FOUND -eq 0 ]]; then
    echo -e "  ${WARN} $T_HID_MISS"
    echo -e "        ${DIM}$T_HID_NOTE${RST}"
fi

# ─────────────────────────────────────────────────────────────
#  6. ASUSCTL
# ─────────────────────────────────────────────────────────────
section "$T_SEC6"

if command -v asusctl &>/dev/null; then
    ASUSCTL_VER=$(asusctl --version 2>/dev/null | head -1)
    echo -e "  ${OK} $T_ASUSCTL_INST ${WHT}$ASUSCTL_VER${RST}"

    # Prüfe asusd Service
    if systemctl is-active --quiet asusd 2>/dev/null; then
        echo -e "  ${OK} $T_ASUSD_OK"
    else
        ASUSD_STATUS=$(systemctl is-enabled asusd 2>/dev/null)
        echo -e "  ${ERR} $T_ASUSD_MISS ${WHT}${ASUSD_STATUS:-?}${RST})"
        add_issue "$T_ASUSD_ISSUE"
        add_fix "$T_ASUSD_FIX"
    fi

    # Zeige aktuelle AURA-Einstellungen
    echo -e "  ${INFO} $T_AURA_MODE"
    asusctl aura -g 2>/dev/null | head -5 | while read -r line; do
        echo -e "    ${DIM}$line${RST}"
    done || echo -e "    ${DIM}$T_AURA_FAIL${RST}"

else
    echo -e "  ${ERR} $T_ASUSCTL_MISS"
    echo -e "        ${DIM}$T_ASUSCTL_NOTE${RST}"
    add_issue "$T_ASUSCTL_ISSUE"
    add_fix "$T_ASUSCTL_FIX_NOTE"
fi

# ─────────────────────────────────────────────────────────────
#  7. OPENRGB
# ─────────────────────────────────────────────────────────────
section "$T_SEC7"

if command -v openrgb &>/dev/null; then
    OPENRGB_VER=$(openrgb --version 2>/dev/null | head -1)
    echo -e "  ${OK} $T_OPENRGB_INST ${WHT}$OPENRGB_VER${RST}"
    echo -e "  ${INFO} $T_OPENRGB_DEVS"
    timeout 5 openrgb --list-devices 2>/dev/null | head -20 | while read -r line; do
        echo -e "    ${DIM}$line${RST}"
    done || echo -e "    ${DIM}$T_OPENRGB_TIMEOUT${RST}"
else
    echo -e "  ${INFO} $T_OPENRGB_MISS"
fi

# ─────────────────────────────────────────────────────────────
#  8. DMESG FEHLER
# ─────────────────────────────────────────────────────────────
section "$T_SEC8"

echo -e "  ${INFO} $T_DMESG_INFO"
DMESG_OUT=$(dmesg 2>/dev/null | grep -iE "0b05|1866|aura|n-key|nkey|kbd_backlight|hid_asus|asus_wmi|asus_nb" | tail -20)
if [[ -n "$DMESG_OUT" ]]; then
    while IFS= read -r line; do
        if echo "$line" | grep -qiE "error|fail|warn|unable|timeout"; then
            echo -e "    ${RED}→ $line${RST}"
            add_issue "$T_DMESG_ISSUE $(echo "$line" | sed 's/\[.*\] //')"
        else
            echo -e "    ${DIM}→ $line${RST}"
        fi
    done <<< "$DMESG_OUT"
else
    echo -e "    ${DIM}$T_DMESG_NONE${RST}"
fi

# Prüfe auf USB-Fehler
USB_ERRORS=$(dmesg 2>/dev/null | grep -iE "usb.*error|usb.*fail|unable to.*1-3" | tail -5)
if [[ -n "$USB_ERRORS" ]]; then
    echo -e "  ${WARN} $T_USB_WARN"
    while IFS= read -r line; do
        echo -e "    ${YLW}→ $line${RST}"
    done <<< "$USB_ERRORS"
fi

# ─────────────────────────────────────────────────────────────
#  9. UDEV REGELN
# ─────────────────────────────────────────────────────────────
section "$T_SEC9"

UDEV_ASUS=$(grep -r "0b05\|asus.*nkey\|N-KEY" /etc/udev/rules.d/ /lib/udev/rules.d/ 2>/dev/null | grep -v "Binary" | head -10)
if [[ -n "$UDEV_ASUS" ]]; then
    echo -e "  ${OK} $T_UDEV_OK"
    echo "$UDEV_ASUS" | while read -r line; do
        echo -e "    ${DIM}$line${RST}"
    done
else
    echo -e "  ${INFO} $T_UDEV_MISS"
fi

# ─────────────────────────────────────────────────────────────
#  10. SUSPEND/RESUME PROBLEM
# ─────────────────────────────────────────────────────────────
section "$T_SEC10"

SUSPEND_LOG=$(journalctl -b 0 --no-pager -q -k 2>/dev/null | grep -iE "suspend|resume|wakeup|asus|0b05" | tail -10)
if echo "$SUSPEND_LOG" | grep -qiE "suspend|resume"; then
    echo -e "  ${INFO} $T_SUSPEND_INFO"
    AFTER_RESUME=$(echo "$SUSPEND_LOG" | grep -i -A2 "resume")
    if echo "$AFTER_RESUME" | grep -qiE "error|fail"; then
        echo -e "  ${WARN} $T_SUSPEND_WARN"
        add_issue "$T_SUSPEND_ISSUE"
        add_fix "$T_SUSPEND_FIX"
    else
        echo -e "  ${OK} $T_SUSPEND_OK"
    fi
else
    echo -e "  ${DIM}  $T_SUSPEND_NONE${RST}"
fi

# ─────────────────────────────────────────────────────────────
#  ZUSAMMENFASSUNG
# ─────────────────────────────────────────────────────────────
section "$T_SUMMARY"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GRN}$T_NO_ISSUES${RST}"
    echo ""
    echo -e "  ${INFO} $T_MAYBE"
    echo -e "    ${DIM}• $T_MAYBE1${RST}"
    echo -e "    ${DIM}• $T_MAYBE2${RST}"
    echo -e "    ${DIM}• $T_MAYBE3${RST}"
else
    echo -e "  ${RED}$T_FOUND_ISSUES (${#ISSUES[@]}):${RST}"
    for i in "${!ISSUES[@]}"; do
        echo -e "  ${RED}  $(( i+1 )). ${ISSUES[$i]}${RST}"
    done
fi

echo ""
echo -e "  ${MAG}$([[ $ROG_LANG == en ]] && echo "Recommended fixes:" || echo "Empfohlene Lösungen:")${RST}"
echo ""

# asusctl Installationsanleitung (immer anzeigen wenn nicht installiert)
if ! command -v asusctl &>/dev/null; then
    echo -e "  ${FIX} ${WHT}$T_FIX_ASUSCTL${RST}"
    echo -e "    ${DIM}# $T_FIX_PPA${RST}"
    echo -e "    ${GRN}sudo add-apt-repository ppa:asus-linux/mainline${RST}"
    echo -e "    ${GRN}sudo apt update${RST}"
    echo -e "    ${GRN}sudo apt install asusctl supergfxctl${RST}"
    echo -e "    ${GRN}sudo systemctl enable --now asusd supergfxd${RST}"
    echo ""
fi

# Sofortlösung via sysfs Helligkeit
echo -e "  ${FIX} ${WHT}$T_FIX_BRIGHTNESS${RST}"
echo -e "    ${GRN}echo 3 | sudo tee /sys/class/leds/asus::kbd_backlight/brightness${RST}"
echo ""

# Sofortlösung via asusctl (wenn installiert)
if command -v asusctl &>/dev/null; then
    echo -e "  ${FIX} ${WHT}$T_FIX_AURA${RST}"
    echo -e "    ${GRN}asusctl aura -sn Static -c ff0000    ${DIM}# $T_FIX_RED${RST}"
    echo -e "    ${GRN}asusctl aura -sn Breathe -c 00ff00   ${DIM}# $T_FIX_GREEN_BREATHE${RST}"
    echo -e "    ${GRN}asusctl aura -sn Rainbow             ${DIM}# $T_FIX_RAINBOW${RST}"
    echo ""
fi

# udev Regel für Berechtigungen
echo -e "  ${FIX} ${WHT}$T_FIX_UDEV${RST}"
echo -e "    ${GRN}echo 'SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"0b05\", ATTRS{idProduct}==\"1866\", MODE=\"0666\"' | sudo tee /etc/udev/rules.d/99-asus-nkey.rules${RST}"
echo -e "    ${GRN}sudo udevadm control --reload-rules && sudo udevadm trigger${RST}"
echo ""

# Nach Suspend
echo -e "  ${FIX} ${WHT}$T_FIX_SUSPEND${RST}"
echo -e "    ${DIM}# $T_FIX_SUSPEND_CREATE${RST}"
echo -e "    ${GRN}sudo tee /etc/systemd/system/rog-kbd-resume.service << 'EOF'${RST}"
echo -e "    ${DIM}[Unit]"
echo -e "    Description=$T_FIX_SUSPEND_SVC"
echo -e "    After=suspend.target hibernate.target hybrid-sleep.target"
echo -e "    [Service]"
echo -e "    Type=oneshot"
echo -e "    ExecStart=/bin/sh -c 'echo 3 > /sys/class/leds/asus::kbd_backlight/brightness'"
echo -e "    [Install]"
echo -e "    WantedBy=suspend.target hibernate.target hybrid-sleep.target${RST}"
echo -e "    ${GRN}EOF${RST}"
echo -e "    ${GRN}sudo systemctl enable --now rog-kbd-resume.service${RST}"
echo ""

# OpenRGB als Alternative
echo -e "  ${FIX} ${WHT}$T_FIX_OPENRGB${RST}"
echo -e "    ${GRN}sudo apt install openrgb   ${DIM}# $T_FIX_OR_FROM${RST}"
echo ""

echo -e "${CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo ""

# Optionaler interaktiver Fix
if [[ "$1" == "--fix" ]]; then
    echo -e "${YLW}  $T_FIX_MODE${RST}"
    if echo 3 | sudo tee /sys/class/leds/asus::kbd_backlight/brightness &>/dev/null; then
        echo -e "  ${OK} $T_FIX_BR_OK"
    else
        echo -e "  ${ERR} $T_FIX_BR_ERR"
    fi
fi
