#!/system/bin/sh
MODDIR=${0%/*}
SCRIPT="$MODDIR/scripts/oneforce.sh"

n=0
while [ "$n" -lt 5 ]; do
  if sh "$SCRIPT" boot >/dev/null 2>&1; then
    break
  fi
  n=$((n + 1))
  sleep 2
done

(
  m=0
  while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$m" -lt 120 ]; do
    m=$((m + 1))
    sleep 2
  done
  sleep 20
  sh "$SCRIPT" verify >/dev/null 2>&1
) &

exit 0
