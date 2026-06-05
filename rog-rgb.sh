#!/usr/bin/env bash
# ============================================================
#  ROG RGB Terminal Control  |  ROG Tastatur RGB Steuerung
#  Wrapper für rogauracore
#
#  Language / Sprache: ROG_LANG=en  or  ROG_LANG=de (default)
# ============================================================

# ── Language / Sprache ───────────────────────────────────────
ROG_LANG="${ROG_LANG:-de}"

# Farben für Ausgabe
GRN='\033[1;32m'; RED='\033[1;31m'; YLW='\033[1;33m'
CYN='\033[1;36m'; WHT='\033[1;37m'; DIM='\033[2m'; RST='\033[0m'

if [[ "$ROG_LANG" == "en" ]]; then
    T_NOT_FOUND="Error: rogauracore not found."
    T_INSTALL_HINT="Install: cd /tmp/rogauracore && sudo make install"
    T_TITLE="ROG RGB Control"
    T_STATUS="Keyboard status:"
    T_BRIGHTNESS="Brightness"
    T_HID_NOTE="(HID side-effect, sysfs reset normal)"
    T_LAST_EFFECT="Last effect"
    T_OFF="Keyboard backlight off."
    T_RAINBOW="Rainbow effect active (speed"
    T_BREATHE="Breathing effect with color"
    T_ACTIVE="active."
    T_RESTORE="Restoring"
    T_COLOR_SET="Color"
    T_COLOR_SET2="set."
    T_BAD_HEX="Invalid hex color:"
    T_HEX_FORMAT="Format: #RRGGBB (e.g. #ff0000)"
    T_UNKNOWN="Unknown command:"
    T_PRESET_COLORS="Preset colors:"
    T_HEX_USAGE="Hex color (e.g. #ff0000)"
    T_BREATHE_USAGE="Breathing effect"
    T_RAINBOW_USAGE="Rainbow effect"
    T_OFF_USAGE="Turn off"
    T_STATUS_USAGE="Show current status"
    T_RESTORE_USAGE="Restore last saved setting"
else
    T_NOT_FOUND="Fehler: rogauracore nicht gefunden."
    T_INSTALL_HINT="Installieren: cd /tmp/rogauracore && sudo make install"
    T_TITLE="ROG RGB Steuerung"
    T_STATUS="Tastatur-Status:"
    T_BRIGHTNESS="Helligkeit"
    T_HID_NOTE="(HID-Effekt aktiv, sysfs-Reset normal)"
    T_LAST_EFFECT="Letzter Effekt"
    T_OFF="Tastaturbeleuchtung ausgeschaltet."
    T_RAINBOW="Regenbogen-Effekt aktiv (Geschwindigkeit"
    T_BREATHE="Atmend-Effekt mit Farbe"
    T_ACTIVE="aktiv."
    T_RESTORE="Stelle wieder her:"
    T_COLOR_SET="Farbe"
    T_COLOR_SET2="gesetzt."
    T_BAD_HEX="Ungültige Hex-Farbe:"
    T_HEX_FORMAT="Format: #RRGGBB (z.B. #ff0000)"
    T_UNKNOWN="Unbekannter Befehl:"
    T_PRESET_COLORS="Vordefinierte Farben:"
    T_HEX_USAGE="Hex-Farbe (z.B. #ff0000)"
    T_BREATHE_USAGE="Atmend"
    T_RAINBOW_USAGE="Regenbogen-Effekt"
    T_OFF_USAGE="Ausschalten"
    T_STATUS_USAGE="Aktuellen Status zeigen"
    T_RESTORE_USAGE="Letzte Farbe wiederherstellen"
fi

ROGAURA=$(command -v rogauracore 2>/dev/null)
if [[ -z "$ROGAURA" ]]; then
    echo -e "${RED}$T_NOT_FOUND${RST}"
    echo -e "$T_INSTALL_HINT"
    exit 1
fi

usage() {
    echo -e "${CYN}$T_TITLE${RST}"
    echo ""
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}<Farbe>${RST}"
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}#RRGGBB${RST}     $T_HEX_USAGE"
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}breathe RRGGBB${RST}  $T_BREATHE_USAGE"
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}rainbow${RST}     $T_RAINBOW_USAGE"
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}off${RST}         $T_OFF_USAGE"
    echo -e "  ${WHT}rog-rgb.sh${RST} ${YLW}status${RST}      $T_STATUS_USAGE"
    echo ""
    echo -e "  $T_PRESET_COLORS"
    echo -e "    ${RED}red${RST}  ${GRN}green${RST}  ${CYN}cyan${RST}  ${YLW}yellow${RST}  white  gold  magenta  blue"
    echo ""
}

save_last() {
    mkdir -p ~/.config/rog-rgb
    echo "$*" > ~/.config/rog-rgb/last_color
}

load_last() {
    if [[ -f ~/.config/rog-rgb/last_color ]]; then
        cat ~/.config/rog-rgb/last_color
    else
        echo "single_static ff5500"  # Standard: Orange
    fi
}

run_cmd() {
    rogauracore "$@" 2>/dev/null
    local rc=$?
    # RC=17 ist Erfolg (17 Bytes übertragen = MESSAGE_LENGTH)
    if [[ $rc -eq 17 || $rc -eq 0 ]]; then
        # rogauracore setzt sysfs-Brightness auf 0 zurück → wiederherstellen
        echo 3 | sudo tee /sys/class/leds/asus::kbd_backlight/brightness > /dev/null 2>&1 || true
        return 0
    fi
    return $rc
}

CMD="${1,,}"  # Kleinbuchstaben

case "$CMD" in
    ""|-h|--help|help)
        usage
        exit 0
        ;;
    status)
        echo -e "${CYN}$T_STATUS${RST}"
        BRIGHTNESS=$(cat /sys/class/leds/asus::kbd_backlight/brightness 2>/dev/null)
        MAX=$(cat /sys/class/leds/asus::kbd_backlight/max_brightness 2>/dev/null)
        # Hinweis: Brightness kann nach HID-Zugriff kurzzeitig 0 zeigen
        if [[ "${BRIGHTNESS}" -eq 0 ]]; then
            echo -e "  $T_BRIGHTNESS: ${YLW}${BRIGHTNESS:-?}/${MAX:-?} $T_HID_NOTE${RST}"
        else
            echo -e "  $T_BRIGHTNESS: ${WHT}${BRIGHTNESS:-?}/${MAX:-?}${RST}"
        fi
        LAST=$(load_last)
        echo -e "  $T_LAST_EFFECT: ${WHT}${LAST}${RST}"
        exit 0
        ;;
    off|black)
        run_cmd single_static 000000
        echo -e "${DIM}$T_OFF${RST}"
        save_last "single_static 000000"
        ;;
    rainbow)
        SPEED="${2:-2}"  # Geschwindigkeit 1-3, Standard 2
        run_cmd rainbow_cycle "$SPEED"
        echo -e "${GRN}$T_RAINBOW ${SPEED}).${RST}"
        save_last "rainbow_cycle $SPEED"
        ;;
    breathe|breathing)
        COLOR="${2:-00aaff}"
        COLOR="${COLOR#\#}"  # # entfernen falls vorhanden
        SPEED="${3:-2}"      # Geschwindigkeit 1-3, Standard 2
        # single_breathing braucht: COLOR1 COLOR2 SPEED (zweite Farbe = schwarz = ausblenden)
        run_cmd single_breathing "$COLOR" "000000" "$SPEED"
        echo -e "${GRN}$T_BREATHE #${COLOR} $T_ACTIVE${RST}"
        save_last "single_breathing $COLOR 000000 $SPEED"
        ;;
    restore)
        LAST=$(load_last)
        echo -e "${DIM}$T_RESTORE ${LAST}${RST}"
        rogauracore $LAST 2>/dev/null
        ;;
    red|green|blue|yellow|gold|cyan|magenta|white)
        run_cmd "$CMD"
        echo -e "${GRN}$T_COLOR_SET '${CMD}' $T_COLOR_SET2${RST}"
        save_last "single_static"
        ;;
    \#*)
        # Hex-Farbe wie #ff0000
        HEX="${CMD#\#}"
        if [[ ${#HEX} -ne 6 || ! "$HEX" =~ ^[0-9a-f]{6}$ ]]; then
            echo -e "${RED}$T_BAD_HEX ${CMD}${RST}"
            echo "$T_HEX_FORMAT"
            exit 1
        fi
        run_cmd single_static "$HEX"
        echo -e "${GRN}$T_COLOR_SET #${HEX} $T_COLOR_SET2${RST}"
        save_last "single_static $HEX"
        ;;
    *)
        # Versuche als Hex-Farbe (ohne #)
        HEX="${CMD#\#}"
        if [[ ${#HEX} -eq 6 && "$HEX" =~ ^[0-9a-f]{6}$ ]]; then
            run_cmd single_static "$HEX"
            echo -e "${GRN}$T_COLOR_SET #${HEX} $T_COLOR_SET2${RST}"
            save_last "single_static $HEX"
        else
            echo -e "${RED}$T_UNKNOWN ${CMD}${RST}"
            usage
            exit 1
        fi
        ;;
esac
