#!/usr/bin/env bash

# ============================================================
#  ROG Fan Audit Tool (Read-Only Hardware Detection)
#  Liefert strukturierten Output für die Auswahl des Fan-Stacks
#  (asusctl vs. nbfc-linux vs. asus_wmi platform_profile)
#  Für: Linux Mint / Ubuntu (Kernel 5.x / 6.x)
# ============================================================

set -u

# ─── Farbcodes ──────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
RST='\033[0m'

# ─── Hilfsfunktionen ────────────────────────────────────
section() {
  local title="$1"
  printf "\n${CYN}═══════════════════════════════════════${RST}\n"
  printf "${BLU}${title}${RST}\n"
  printf "${CYN}═══════════════════════════════════════${RST}\n"
}

kv() {
  local key="$1" val="$2"
  printf "  ${GRN}%-25s${RST} %s\n" "${key}:" "${val}"
}

chk_file() {
  local file="$1"
  [ -f "$file" ] && cat "$file" 2>/dev/null || echo "n/a"
}

chk_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 && echo "[OK]" || echo "[n/a]"
}

get_cmd_version() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 && "$cmd" --version 2>&1 | head -1 || echo "n/a"
}

# ─────────────────────────────────────────────────────────
# 1. SYSTEM INFO (System-Informationen)
# ─────────────────────────────────────────────────────────
section "1. SYSTEM INFO (System-Informationen)"

kv "Vendor" "$(chk_file /sys/devices/virtual/dmi/id/sys_vendor)"
kv "Modell" "$(chk_file /sys/devices/virtual/dmi/id/product_name)"
kv "Board" "$(chk_file /sys/devices/virtual/dmi/id/board_name)"
kv "BIOS" "$(chk_file /sys/devices/virtual/dmi/id/bios_version)"
kv "Kernel" "$(uname -r)"
kv "Distro" "$(lsb_release -ds 2>/dev/null || echo 'n/a')"

# ─────────────────────────────────────────────────────────
# 2. CPU/GPU INFO (Prozessor und Grafik)
# ─────────────────────────────────────────────────────────
section "2. CPU/GPU INFO (Prozessor und Grafik)"

printf "\n  ${YLW}CPU:${RST}\n"
lscpu 2>/dev/null | grep -E "Model name|CPU\(s\):" | while read line; do
  printf "    %s\n" "$line"
done || printf "    n/a\n"

printf "\n  ${YLW}GPU:${RST}\n"
lspci 2>/dev/null | grep -iE "vga|3d|display" | while read line; do
  printf "    %s\n" "$line"
done || printf "    n/a\n"

# ─────────────────────────────────────────────────────────
# 3. ASUS KERNEL MODULES (ASUS-Kernel-Module)
# ─────────────────────────────────────────────────────────
section "3. ASUS KERNEL MODULES (ASUS-Kernel-Module)"

printf "  ${YLW}Aktuell geladen:${RST}\n"
lsmod 2>/dev/null | grep -E "^asus|^hid_asus|^faustus|^nbfc" | while read -r module _; do
  printf "    [LOADED] %s\n" "$module"
done || printf "    (keine)\n"

printf "\n  ${YLW}Modulverfügbarkeit:${RST}\n"
for mod in asus_wmi asus_nb_wmi hid_asus faustus ec_sys nbfc; do
  if modinfo "$mod" >/dev/null 2>&1; then
    status="[OK]"
  else
    status="[n/a]"
  fi
  
  if lsmod 2>/dev/null | grep -q "^${mod} "; then
    loaded="(geladen)"
  else
    loaded="(nicht geladen)"
  fi
  
  printf "    %-20s %s %s\n" "$mod" "$status" "$loaded"
done

# ─────────────────────────────────────────────────────────
# 4. ASUS PLATFORM INTERFACE (Platform-Interface)
# ─────────────────────────────────────────────────────────
section "4. ASUS PLATFORM INTERFACE (Platform-Interface)"

if [ -d /sys/devices/platform/asus-nb-wmi ]; then
  printf "  ${GRN}[OK]${RST} /sys/devices/platform/asus-nb-wmi/ gefunden\n"
  
  for file in throttle_thermal_policy fan_boost_mode pwm_* fan_*; do
    filepath="/sys/devices/platform/asus-nb-wmi/$file"
    if [ -e "$filepath" ]; then
      value=$(cat "$filepath" 2>/dev/null || echo "n/a")
      printf "    %-25s = %s\n" "$file" "$value"
    fi
  done
else
  printf "  ${YLW}[INFO]${RST} /sys/devices/platform/asus-nb-wmi/ nicht gefunden\n"
fi

if [ -d /sys/devices/platform/faustus ]; then
  printf "\n  ${GRN}[OK]${RST} /sys/devices/platform/faustus/ gefunden\n"
  
  for file in /sys/devices/platform/faustus/*; do
    if [ -e "$file" ]; then
      filename=$(basename "$file")
      value=$(cat "$file" 2>/dev/null || echo "n/a")
      printf "    %-25s = %s\n" "$filename" "$value"
    fi
  done
else
  printf "\n  ${YLW}[INFO]${RST} /sys/devices/platform/faustus/ nicht gefunden\n"
fi

# ─────────────────────────────────────────────────────────
# 5. PLATFORM PROFILE (ACPI/Kernel-Interface)
# ─────────────────────────────────────────────────────────
section "5. PLATFORM PROFILE (ACPI/Kernel-Interface)"

if [ -f /sys/firmware/acpi/platform_profile ]; then
  profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)
  kv "Aktuell" "$profile"
  
  if [ -f /sys/firmware/acpi/platform_profile_choices ]; then
    choices=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null)
    kv "Verfügbare Modi" "$choices"
  fi
else
  printf "  ${YLW}[INFO]${RST} Platform Profile nicht verfügbar\n"
fi

# ─────────────────────────────────────────────────────────
# 6. HARDWARE MONITOR (hwmon)
# ─────────────────────────────────────────────────────────
section "6. HARDWARE MONITOR (Hardware-Sensoren)"

for hwmon in /sys/class/hwmon/hwmon*; do
  if [ -d "$hwmon" ]; then
    hwmon_id=$(basename "$hwmon")
    hwmon_name=$([ -f "$hwmon/name" ] && cat "$hwmon/name" || echo "unknown")
    printf "\n  ${BLU}── %s [%s] ──${RST}\n" "$hwmon_id" "$hwmon_name"
    
    # Temperaturen
    for temp_file in "$hwmon"/temp*_input; do
      if [ -e "$temp_file" ]; then
        temp_base=$(basename "$temp_file" _input)
        label_file="${hwmon}/${temp_base}_label"
        label=$([ -e "$label_file" ] && cat "$label_file" || echo "$temp_base")
        value_raw=$(cat "$temp_file" 2>/dev/null || echo 0)
        value_c=$((value_raw / 1000))
        printf "    %-30s %d°C\n" "${label}:" "$value_c"
      fi
    done
    
    # Lüfter
    for fan_file in "$hwmon"/fan*_input; do
      if [ -e "$fan_file" ]; then
        fan_base=$(basename "$fan_file" _input)
        label_file="${hwmon}/${fan_base}_label"
        label=$([ -e "$label_file" ] && cat "$label_file" || echo "$fan_base")
        value=$(cat "$fan_file" 2>/dev/null || echo "0")
        printf "    %-30s %s RPM\n" "${label}:" "$value"
      fi
    done
    
    # PWM-Steuerung
    for pwm_file in "$hwmon"/pwm[0-9]; do
      if [ -e "$pwm_file" ]; then
        pwm_id=$(basename "$pwm_file")
        pwm_val=$(cat "$pwm_file" 2>/dev/null || echo "n/a")
        enable_file="${hwmon}/${pwm_id}_enable"
        enable_val=$([ -e "$enable_file" ] && cat "$enable_file" || echo "n/a")
        printf "    %-30s %s (enable=%s)\n" "${pwm_id}:" "$pwm_val" "$enable_val"
      fi
    done
  fi
done

# ─────────────────────────────────────────────────────────
# 7. INSTALLED FAN/POWER TOOLS (Installierte Tools)
# ─────────────────────────────────────────────────────────
section "7. INSTALLED FAN/POWER TOOLS (Installierte Tools)"

for tool in asusctl supergfxctl rog-control-center nbfc nbfc-linux \
            fancontrol pwmconfig sensors tlp auto-cpufreq \
            power-profiles-daemon tuned psensor; do
  status=$(chk_cmd "$tool")
  version=$(get_cmd_version "$tool")
  printf "  %-25s %s %s\n" "$tool" "$status" "$version"
done

# ─────────────────────────────────────────────────────────
# 8. RUNNING SERVICES (Laufende Services)
# ─────────────────────────────────────────────────────────
section "8. RUNNING SERVICES (Laufende Services)"

printf "  ${YLW}Systemd-Services (gefiltert):${RST}\n"
systemctl list-units --type=service --state=running 2>/dev/null | \
  grep -iE "asus|fan|nbfc|tlp|power-profiles|tuned|thermald|supergfx" | \
  awk '{print $1}' | while read svc; do
  status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  printf "    %-40s [%s]\n" "$svc" "$status"
done || printf "    n/a\n"

# ─────────────────────────────────────────────────────────
# 9. DMESG & KERNEL MESSAGES (Kernel-Meldungen)
# ─────────────────────────────────────────────────────────
section "9. DMESG & KERNEL MESSAGES (Kernel-Meldungen)"

printf "  ${YLW}Letzte 20 Einträge (ASUS/Fan/Thermal):${RST}\n"
(dmesg 2>/dev/null | grep -iE "asus|fan|thermal|throttle" | tail -20) || \
  (journalctl -k --no-pager 2>/dev/null | grep -iE "asus|fan|thermal|throttle" | tail -20) || \
  printf "    (keine Treffer / keine Berechtigung)\n"

# ─────────────────────────────────────────────────────────
# 10. PPAS / REPOS (Repository-Quellen)
# ─────────────────────────────────────────────────────────
section "10. PPAS / REPOS (Repository-Quellen)"

printf "  ${YLW}PPAs / APT-Quellen (ASUS/Fan):${RST}\n"
ls /etc/apt/sources.list.d/ 2>/dev/null | grep -iE "asus|fan" | while read ppa; do
  printf "    %s\n" "$ppa"
done || printf "    (keine gefunden)\n"

printf "\n  ${YLW}apt-cache policy asusctl:${RST}\n"
apt-cache policy asusctl 2>/dev/null | head -5 || printf "    n/a\n"

# ─────────────────────────────────────────────────────────
# 11. DESKTOP ENVIRONMENT (Desktop-Umgebung)
# ─────────────────────────────────────────────────────────
section "11. DESKTOP ENVIRONMENT (Desktop-Umgebung)"

kv "XDG_CURRENT_DESKTOP" "${XDG_CURRENT_DESKTOP:-n/a}"
kv "DESKTOP_SESSION" "${DESKTOP_SESSION:-n/a}"
kv "XDG_SESSION_TYPE" "${XDG_SESSION_TYPE:-n/a}"

# ─────────────────────────────────────────────────────────
# 12. SUMMARY (Zusammenfassung)
# ─────────────────────────────────────────────────────────
section "12. SUMMARY (Zusammenfassung & Auto-Befund)"

# Throttle/Thermal Policy Check
if [ -d /sys/devices/platform/asus-nb-wmi ] && \
   [ -f /sys/devices/platform/asus-nb-wmi/throttle_thermal_policy ]; then
  printf "  ${GRN}[OK]${RST} Throttle/Thermal Policy verfügbar\n"
else
  printf "  ${YLW}[NEIN]${RST} Throttle/Thermal Policy nicht verfügbar\n"
fi

# Platform Profile Check
if [ -f /sys/firmware/acpi/platform_profile ]; then
  printf "  ${GRN}[OK]${RST} Platform Profile (ACPI) verfügbar\n"
else
  printf "  ${YLW}[NEIN]${RST} Platform Profile (ACPI) nicht verfügbar\n"
fi

# asusctl Check
if command -v asusctl >/dev/null 2>&1; then
  printf "  ${GRN}[OK]${RST} asusctl installiert\n"
else
  printf "  ${YLW}[NEIN]${RST} asusctl nicht installiert\n"
fi

# nbfc Check
if command -v nbfc >/dev/null 2>&1 || command -v nbfc-linux >/dev/null 2>&1; then
  printf "  ${GRN}[OK]${RST} nbfc / nbfc-linux installiert\n"
else
  printf "  ${YLW}[NEIN]${RST} nbfc / nbfc-linux nicht installiert\n"
fi

# Fan-RPM-Sensoren Count
fan_count=$(find /sys/class/hwmon -name "fan*_input" 2>/dev/null | wc -l)
printf "  ${CYN}[INFO]${RST} Fan-RPM-Sensoren gefunden: %d\n" "$fan_count"

# PWM Steuerung Check
pwm_count=$(find /sys/class/hwmon -name "pwm[0-9]" 2>/dev/null | wc -l)
if [ "$pwm_count" -gt 0 ]; then
  printf "  ${GRN}[OK]${RST} PWM-Steuerung verfügbar (%d Kanäle)\n" "$pwm_count"
else
  printf "  ${YLW}[NEIN]${RST} PWM-Steuerung nicht verfügbar\n"
fi

# ─── Abschlussmeldung ───────────────────────────────────
printf "\n${BLU}═══════════════════════════════════════${RST}\n"
printf "${GRN}✓ Audit abgeschlossen${RST}\n"
printf "${BLU}═══════════════════════════════════════${RST}\n\n"
printf "${YLW}Bitte den kompletten Output kopieren und zurück an den AI-Lead pasten.${RST}\n\n"
