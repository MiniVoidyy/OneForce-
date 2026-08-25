#!/system/bin/sh
SKIPUNZIP=0

E=$(printf '\033')
BLUE="${E}[1;34m"
CYAN="${E}[1;36m"
RST="${E}[0m"

command -v ui_print >/dev/null 2>&1 || ui_print(){ echo "$1"; }

ui_print " "
ui_print "${BLUE}================================${RST}"
ui_print "${BLUE}   ONE FORCE  -  One UI Spoofer ${RST}"
ui_print "${BLUE}   force galaxy store updates   ${RST}"
ui_print "${BLUE}  magisk / ksu / next / suki    ${RST}"
ui_print "${BLUE}================================${RST}"
ui_print " "

BASE=/data/adb/one_force
MODDIR=${MODDIR:-$(pwd)}

mkdir -p $BASE/scripts $BASE/bin

cp -f scripts/oneforce.sh $BASE/scripts/oneforce.sh 2>/dev/null ||
  cp -f "$MODDIR/scripts/oneforce.sh" $BASE/scripts/oneforce.sh

if [ ! -f $BASE/scripts/oneforce.sh ]; then
  ui_print "! FATAL: could not install the engine script."
  abort
fi

chmod 755 $BASE/scripts/oneforce.sh
chmod 755 service.sh action.sh uninstall.sh 2>/dev/null

if [ ! -f $BASE/config.conf ]; then
cat > $BASE/config.conf <<'EOF'
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

chmod 644 $BASE/config.conf

ui_print "- Spoof targets: One UI 6.0 / Android 14"
ui_print "- Security patch spoof: 2026-06-01"
ui_print "- Supported range: One UI 6.0 and above"
ui_print "- Edit anytime from the WebUI or:"
ui_print "${CYAN}  su -c sh /data/adb/one_force/scripts/oneforce.sh menu${RST}"
ui_print " "
ui_print "- Original prop values are saved on first apply,"
ui_print "  so you can fully revert without rebooting."
ui_print " "
if ! command -v resetprop >/dev/null 2>&1 && [ ! -x /data/adb/magisk/resetprop ] &&
   [ ! -x /data/adb/ap/bin/resetprop ] && [ ! -x /data/adb/ksu/bin/resetprop ] &&
   [ ! -x /data/adb/suki/bin/resetprop ]; then
  ui_print "! resetprop not found in your manager."
  ui_print "! Drop a static resetprop binary at:"
  ui_print "! ${CYAN}/data/adb/one_force/bin/resetprop${RST}"
  ui_print "! (chmod 755), then reboot."
else
  ui_print "${BLUE}- Done! Reboot to activate.${RST}"
fi
