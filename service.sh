#!/system/bin/sh
MODDIR=${0%/*}
SCRIPT="$MODDIR/scripts/oneforce.sh"

n=0
while [ "$n" -lt 5 ]; do
  if sh "$SCRIPT" boot >/dev/null 2>&1; then
    exit 0
  fi
  n=$((n + 1))
  sleep 2
done
