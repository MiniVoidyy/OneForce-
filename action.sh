#!/system/bin/sh
MODDIR=${0%/*}

echo "One Force - toggling spoof..."
if [ -f /data/adb/one_force/scripts/oneforce.sh ]; then
  sh /data/adb/one_force/scripts/oneforce.sh toggle
  sh /data/adb/one_force/scripts/oneforce.sh status
else
  sh "$MODDIR/scripts/oneforce.sh" toggle
fi
