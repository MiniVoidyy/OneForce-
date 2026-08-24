#!/system/bin/sh
BASE=/data/adb/one_force

if [ -f "$BASE/scripts/oneforce.sh" ]; then
  sh "$BASE/scripts/oneforce.sh" revert >/dev/null 2>&1
fi

rm -rf "$BASE"
