#!/system/bin/sh
SKIPUNZIP=0

E=$(printf '\033')
BLUE="${E}[1;34m"
CYAN="${E}[1;36m"
GREEN="${E}[1;32m"
RST="${E}[0m"

command -v ui_print >/dev/null 2>&1 || ui_print(){ echo "$1"; }

ui_print " "
ui_print "${BLUE}================================${RST}"
ui_print "${BLUE}   ONE FORCE  -  One UI Spoofer ${RST}"
ui_print "${BLUE}   Galaxy Store Update Enabler  ${RST}"
ui_print "${BLUE}================================${RST}"
ui_print " "

# --- Auto-detect root manager ---
MGR="Unknown"
if [ -d "/data/adb/ap" ] || [ -f "/data/adb/ap/bin/resetprop" ]; then
  MGR="APatch"
elif [ -d "/data/adb/suki" ] || [ -f "/data/adb/ksu/.sukisu" ] || [ -d "/data/adb/ksu/sukisu" ]; then
  MGR="SukiSU"
elif [ -d "/data/adb/ksu" ] || [ -n "$KSU" ]; then
  MGR="KernelSU / Next"
elif [ -d "/data/adb/magisk" ] || [ -n "$MAGISK_VER" ]; then
  MGR="Magisk"
fi

ui_print "- Detected Root Manager: ${GREEN}$MGR${RST}"

BASE=/data/adb/one_force
MODDIR=${MODDIR:-$(pwd)}

mkdir -p "$BASE/scripts" "$BASE/bin" "$BASE/backups"

# Self-contained file deployment
if [ -f "$MODDIR/scripts/oneforce.sh" ]; then
  cp -f "$MODDIR/scripts/oneforce.sh" "$BASE/scripts/oneforce.sh"
elif [ -f "scripts/oneforce.sh" ]; then
  cp -f "scripts/oneforce.sh" "$BASE/scripts/oneforce.sh"
else
  ui_print "! Warning: engine script not found in staging root, checking parent..."
  find "$MODDIR" -name "oneforce.sh" -exec cp -f {} "$BASE/scripts/oneforce.sh" \; 2>/dev/null
fi

if [ ! -f "$BASE/scripts/oneforce.sh" ]; then
  ui_print "${E}[1;31m! FATAL: Engine script deployment failed.${RST}"
  exit 1
fi

chmod 755 "$BASE/scripts/oneforce.sh"
for s in service.sh action.sh uninstall.sh; do
  [ -f "$MODDIR/$s" ] && chmod 755 "$MODDIR/$s"
  [ -f "$s" ] && chmod 755 "$s"
done

# Initialize config if missing
if [ ! -f "$BASE/config.conf" ]; then
  cat > "$BASE/config.conf" <<'EOF'
ENABLED=true
ONEUI_MAJOR=6
ONEUI_MINOR=0
ANDROID_VER=14
SECURITY_PATCH=2026-06-01
CUSTOM_INCREMENTAL=
SPOOF_SEM=true
SPOOF_RELEASE=true
SPOOF_PATCH=true
EOF
fi

chmod 644 "$BASE/config.conf"

ui_print "- Spoof targets: One UI 6.0 / Android 14"
ui_print "- Security patch spoof: 2026-06-01"
ui_print "- Management: WebUI, Action button, or CLI:"
ui_print "${CYAN}  su -c sh /data/adb/one_force/scripts/oneforce.sh menu${RST}"
ui_print " "

# Check resetprop availability across all manager paths
RP_FOUND=0
for p in resetprop /data/adb/magisk/resetprop /data/adb/ap/bin/resetprop /data/adb/ksu/bin/resetprop /data/adb/suki/bin/resetprop "$BASE/bin/resetprop"; do
  if command -v "$p" >/dev/null 2>&1 || [ -x "$p" ]; then
    RP_FOUND=1
    break
  fi
done

if [ "$RP_FOUND" = "0" ]; then
  ui_print "${E}[1;33m! Warning: resetprop not detected in standard paths.${RST}"
  ui_print "! If your build lacks it, place a static resetprop binary at:"
  ui_print "! ${CYAN}/data/adb/one_force/bin/resetprop${RST} (chmod 755)."
else
  ui_print "${GREEN}- resetprop engine located successfully.${RST}"
fi

ui_print " "
ui_print "${BLUE}- Installation complete! Reboot to activate.${RST}"
