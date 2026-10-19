#!/system/bin/sh
# One Force - One UI spoof engine (Magisk / KernelSU / KSU Next / SukiSU / APatch)
BASE=/data/adb/one_force
CONF="$BASE/config.conf"
ORIG="$BASE/originals.conf"
LOG="$BASE/log.txt"
LOCK="$BASE/.lock"

E=$(printf '\033')
C_B="${E}[1;34m"; C_C="${E}[1;36m"; C_G="${E}[1;32m"
C_R="${E}[1;31m"; C_Y="${E}[1;33m"; C_0="${E}[0m"

log(){
  [ -d "$BASE" ] || return 0
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null)" -gt 49152 ]; then
    : > "$LOG"
  fi
  echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null
}

write_default_conf(){
  mkdir -p "$BASE"
  cat > "$CONF" <<'EOF'
ENABLED=true
ONEUI_MAJOR=6
ONEUI_MINOR=0
ANDROID_VER=14
SECURITY_PATCH=2026-06-01
CUSTOM_INCREMENTAL=
SPOOF_SEM=true
SPOOF_RELEASE=true
SPOOF_PATCH=true
SPOOF_FINGERPRINT=false
CUSTOM_FINGERPRINT=samsung/galaxys23/galaxys23:14/UP1A.230808.022/9999999:user/release-keys
SPOOF_MODEL=false
CUSTOM_MODEL=SM-S911B
SPOOF_DEVICE=false
CUSTOM_DEVICE=galaxys23
EOF
}

conf_set(){
  key="$1"
  val="$2"
  t="$CONF.tmp.$$"
  grep -q "^${key}=" "$CONF" 2>/dev/null || return 1
  sed "s/^${key}=.*/${key}=${val}/" "$CONF" > "$t" 2>/dev/null || { rm -f "$t"; return 1; }
  mv -f "$t" "$CONF"
}

load_conf(){
  [ -f "$CONF" ] || write_default_conf
  . "$CONF" 2>/dev/null
  case "$ENABLED" in true) ;; *) ENABLED=false ;; esac
  case "$ONEUI_MAJOR" in ''|*[!0-9]*) ONEUI_MAJOR=6 ;; esac
  case "$ONEUI_MINOR" in ''|*[!0-9]*) ONEUI_MINOR=0 ;; esac
  [ "$ONEUI_MAJOR" -lt 6 ] 2>/dev/null && ONEUI_MAJOR=6
  case "$ANDROID_VER" in 14|15|16|17) ;; *) ANDROID_VER=14 ;; esac
  case "$SECURITY_PATCH" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) SECURITY_PATCH="" ;;
  esac
  case "$SPOOF_SEM" in false) ;; *) SPOOF_SEM=true ;; esac
  case "$SPOOF_RELEASE" in false) ;; *) SPOOF_RELEASE=true ;; esac
  case "$SPOOF_PATCH" in false) ;; *) SPOOF_PATCH=true ;; esac
  case "$CUSTOM_INCREMENTAL" in
    ''|*[!A-Za-z0-9._-]*) CUSTOM_INCREMENTAL="" ;;
  esac
}

lock_get(){
  n=0
  until mkdir "$LOCK" 2>/dev/null; do
    n=$((n + 1))
    if [ "$n" -ge 10 ]; then
      rm -rf "$LOCK"
      mkdir "$LOCK" 2>/dev/null
      break
    fi
    sleep 1
  done
}

lock_put(){
  rm -rf "$LOCK" 2>/dev/null
}

find_rp(){
  for p in resetprop \
           /data/adb/magisk/resetprop \
           /data/adb/ap/bin/resetprop \
           /data/adb/ksu/bin/resetprop \
           /data/adb/suki/bin/resetprop \
           "$BASE/bin/resetprop"; do
    if command -v "$p" >/dev/null 2>&1 || { [ -f "$p" ] && [ -x "$p" ]; }; then
      RP="$p"
      return 0
    fi
  done
  return 1
}

detect_mgr(){
  if [ -d /data/adb/ap ]; then
    echo "APatch"
  elif [ -d /data/adb/suki ] || [ -f /data/adb/ksu/.sukisu ] || [ -x /data/adb/suki/bin/resetprop ]; then
    echo "SukiSU"
  elif [ -d /data/adb/ksu ]; then
    echo "KernelSU"
  elif [ -d /data/adb/magisk ]; then
    echo "Magisk"
  else
    echo "unknown"
  fi
}

oneui_code(){ echo $(( ($1 * 10000) + ($2 * 100) )); }
sem_code(){ echo $(( ($1 * 1000) + ($2 * 100) )); }

sdk_code(){
  case $1 in
    14) echo 34;;
    15) echo 35;;
    16) echo 36;;
    17) echo 37;;
    *) echo "";;
  esac
}

ORIG_KEYS="ro.build.version.oneui ro.build.version.sem ro.build.version.release ro.build.version.sdk ro.build.version.security_patch ro.build.version.incremental"

save_orig(){
  [ -f "$ORIG" ] && [ "$(grep -c '=' "$ORIG" 2>/dev/null)" -ge 6 ] && return 0
  mkdir -p "$BASE"
  : > "$ORIG"
  for k in $ORIG_KEYS; do
    v=$(getprop "$k")
    [ -z "$v" ] && v="__ABSENT__"
    echo "$k=$v" >> "$ORIG"
  done
  log "originals saved"
}

set_prop(){
  n=0
  while [ "$n" -lt 3 ]; do
    $RP "$1" "$2" >/dev/null 2>&1
    [ "$(getprop "$1")" = "$2" ] && return 0
    n=$((n + 1))
    sleep 1
  done
  return 1
}

del_prop(){
  n=0
  $RP --delete "$1" >/dev/null 2>&1
  while [ "$n" -lt 3 ]; do
    [ -z "$(getprop "$1")" ] && return 0
    n=$((n + 1))
    sleep 1
    $RP --delete "$1" >/dev/null 2>&1
  done
  return 0
}

do_apply(){
  load_conf
  find_rp || {
    log "resetprop not found"
    printf "%s\n" \
      "${C_R}ERROR: no resetprop found.${C_0}" \
      "Place a static resetprop binary at:" \
      "${C_C}$BASE/bin/resetprop${C_0} (chmod 755), then reboot."
    return 1
  }
  lock_get
  save_orig
  OC=$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  SC=$(sem_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  SK=$(sdk_code "$ANDROID_VER")
  fail=0

  set_prop ro.build.version.oneui "$OC" || { fail=1; log "FAILED oneui -> $OC"; }
  log "oneui -> $OC"

  if [ "$SPOOF_SEM" = "true" ]; then
    set_prop ro.build.version.sem "$SC" || { fail=1; log "FAILED sem -> $SC"; }
  fi

  if [ "$SPOOF_RELEASE" = "true" ] && [ -n "$SK" ]; then
    set_prop ro.build.version.release "$ANDROID_VER" || { fail=1; log "FAILED release"; }
    set_prop ro.build.version.sdk "$SK" || { fail=1; log "FAILED sdk -> $SK"; }
    if [ -n "$CUSTOM_INCREMENTAL" ]; then
      set_prop ro.build.version.incremental "$CUSTOM_INCREMENTAL" || { fail=1; log "FAILED incremental"; }
    fi
  fi

  if [ "$SPOOF_PATCH" = "true" ] && [ -n "$SECURITY_PATCH" ]; then
    set_prop ro.build.version.security_patch "$SECURITY_PATCH" || { fail=1; log "FAILED patch -> $SECURITY_PATCH"; }
  fi

  conf_set ENABLED true
  lock_put
  if [ "$fail" = "1" ]; then
    echo "${C_R}Some props failed to stick - check log.txt${C_0}"
    return 1
  fi
  echo "${C_G}Spoof applied: One UI $ONEUI_MAJOR.$ONEUI_MINOR / Android $ANDROID_VER / patch ${SECURITY_PATCH:-stock}${C_0}"
}

do_revert(){
  load_conf
  find_rp || {
    log "resetprop not found"
    echo "${C_R}ERROR: no resetprop found. Place it at $BASE/bin/resetprop${C_0}"
    return 1
  }
  lock_get
  if [ ! -f "$ORIG" ]; then
    conf_set ENABLED false
    lock_put
    echo "${C_Y}Nothing to revert (no originals saved).${C_0}"
    return 0
  fi
  while IFS='=' read -r k v; do
    [ -n "$k" ] || continue
    case "$k" in '#'*) continue;; esac
    if [ "$v" = "__ABSENT__" ]; then
      del_prop "$k"
    else
      set_prop "$k" "$v" || log "restore failed: $k"
    fi
    log "restored $k"
  done < "$ORIG"

  bad=0
  while IFS='=' read -r k v; do
    [ -n "$k" ] || continue
    cur=$(getprop "$k")
    if [ "$v" = "__ABSENT__" ]; then
      [ -z "$cur" ] || bad=1
    else
      [ "$cur" = "$v" ] || bad=1
    fi
  done < "$ORIG"
  conf_set ENABLED false
  lock_put
  if [ "$bad" = "1" ]; then
    echo "${C_R}Revert incomplete - some props refused to restore.${C_0}"
    return 1
  fi
  echo "${C_G}Reverted to stock props (verified).${C_0}"
}

do_toggle(){
  load_conf
  if [ "$ENABLED" = "true" ]; then
    do_revert
  else
    do_apply
  fi
}

is_enabled(){
  load_conf
  cur=$(getprop ro.build.version.oneui)
  want=$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  [ "$ENABLED" = "true" ] && [ "$cur" = "$want" ]
}

print_json(){
  load_conf
  find_rp && rpv=true || rpv=false
  echo "OF_MANAGER=$(detect_mgr)"
  echo "OF_RP=$rpv"
  echo "OF_ENABLED=$([ "$(getprop ro.build.version.oneui)" = "$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")" ] && echo true || echo false)"
  echo "OF_CONF_ENABLED=$ENABLED"
  echo "OF_ONEUI=$ONEUI_MAJOR.$ONEUI_MINOR"
  echo "OF_ANDROID=$ANDROID_VER"
  echo "OF_TARGET_PATCH=$SECURITY_PATCH"
  echo "OF_CUR_ONEUI=$(getprop ro.build.version.oneui)"
  echo "OF_CUR_SEM=$(getprop ro.build.version.sem)"
  echo "OF_CUR_RELEASE=$(getprop ro.build.version.release)"
  echo "OF_CUR_SDK=$(getprop ro.build.version.sdk)"
  echo "OF_CUR_PATCH=$(getprop ro.build.version.security_patch)"
  echo "OF_SEM=$SPOOF_SEM"
  echo "OF_REL=$SPOOF_RELEASE"
  echo "OF_PAT=$SPOOF_PATCH"
  echo "OF_ORIG_PRESENT=$([ -f "$ORIG" ] && echo true || echo false)"
}

set_oneui(){
  case "$1" in
    *.*) ONEUI_MAJOR=${1%%.*}; ONEUI_MINOR=${1##*.} ;;
    *)   echo "${C_R}Format: set <major.minor>  e.g. set 6.1${C_0}"; return 1 ;;
  esac
  case "$ONEUI_MAJOR" in ''|*[!0-9]*)
    echo "${C_R}Format: set <major.minor>  e.g. set 6.1${C_0}"; return 1 ;;
  esac
  case "$ONEUI_MINOR" in ''|*[!0-9]*) ONEUI_MINOR=0;; esac
  if [ "$ONEUI_MAJOR" -lt 6 ]; then
    echo "${C_R}One UI 6.0+ only (got $ONEUI_MAJOR.$ONEUI_MINOR)${C_0}"
    return 1
  fi
  conf_set ONEUI_MAJOR "$ONEUI_MAJOR" && conf_set ONEUI_MINOR "$ONEUI_MINOR" ||
    { sed -i "s/^ONEUI_MAJOR=.*/ONEUI_MAJOR=$ONEUI_MAJOR/" "$CONF";
      sed -i "s/^ONEUI_MINOR=.*/ONEUI_MINOR=$ONEUI_MINOR/" "$CONF"; }
  echo "${C_C}Target One UI set to $ONEUI_MAJOR.$ONEUI_MINOR. Run 'apply'.${C_0}"
}

set_android(){
  SK=$(sdk_code "$1")
  if [ -z "$SK" ]; then
    echo "${C_R}Unsupported Android version: $1 (use 14-17)${C_0}"
    return 1
  fi
  conf_set ANDROID_VER "$1" || sed -i "s/^ANDROID_VER=.*/ANDROID_VER=$1/" "$CONF"
  echo "${C_C}Target Android set to $1 (SDK $SK). Run 'apply'.${C_0}"
}

set_patch(){
  case "$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      conf_set SECURITY_PATCH "$1" || sed -i "s|^SECURITY_PATCH=.*|SECURITY_PATCH=$1|" "$CONF"
      echo "${C_C}Target security patch set to $1. Run 'apply'.${C_0}" ;;
    off|"")
      conf_set SECURITY_PATCH "" || sed -i "s/^SECURITY_PATCH=.*/SECURITY_PATCH=/" "$CONF"
      echo "${C_C}Security patch spoof disabled.${C_0}" ;;
    *)
      echo "${C_R}Format: patch YYYY-MM-DD  (or: patch off)${C_0}"
      return 1 ;;
  esac
}

flags_cmd(){
  f="$2"
  v="$3"
  if [ -z "$f" ]; then
    load_conf
    echo "sem=$SPOOF_SEM release=$SPOOF_RELEASE patch=$SPOOF_PATCH"
    return 0
  fi
  case "$f" in
    sem)     key=SPOOF_SEM ;;
    release) key=SPOOF_RELEASE ;;
    patch)   key=SPOOF_PATCH ;;
    *)       echo "${C_R}Unknown flag: $f (sem|release|patch)${C_0}"; return 1 ;;
  esac
  if [ -z "$v" ]; then
    load_conf
    eval "echo \$$key"
    return 0
  fi
  case "$v" in
    on|true)  conf_set "$key" true  || sed -i "s/^${key}=.*/${key}=true/" "$CONF";;
    off|false) conf_set "$key" false || sed -i "s/^${key}=.*/${key}=false/" "$CONF";;
    *) echo "${C_R}Value: on|off${C_0}"; return 1 ;;
  esac
  echo "${C_C}$f -> ${v}. Run 'apply'.${C_0}"
}

banner(){
  printf "${C_B}"
  cat <<'ART'
 ___  ____   __  ____  _____  ____   ___  ____
/ _ \(  _ \ /  \(  _ \(  _  )(  _ \ / __)(  _ \
( (_| | )   | ) | )(_) ))(_)(  )(_) )\__ \ ) __/
\___/(__/__/(___/ (____/(_____)(____/(____(__)
ART
  printf "${C_0}\n"
}

print_status(){
  load_conf
  banner
  echo " ${C_B}[ One Force status ]${C_0}"
  echo " manager    : $(detect_mgr)"
  echo " target     : One UI $ONEUI_MAJOR.$ONEUI_MINOR / Android $ANDROID_VER"
  echo " patch tgt  : ${SECURITY_PATCH:-off}"
  echo " flags      : $(flags_cmd '' '' | tr -d '\n')"
  echo " live oneui : $(getprop ro.build.version.oneui)   sem: $(getprop ro.build.version.sem)"
  echo " live rel   : Android $(getprop ro.build.version.release)  sdk:$(getprop ro.build.version.sdk)"
  echo " live patch : $(getprop ro.build.version.security_patch)"
  echo " originals  : $([ -f "$ORIG" ] && echo saved || echo none)"
  if is_enabled; then
    st="${C_G}ACTIVE${C_0}"
  elif [ "$ENABLED" = "true" ]; then
    st="${C_Y}PENDING (run apply / reboot)${C_0}"
  else
    st="${C_R}OFF${C_0}"
  fi
  echo " state      : $st"
}

menu(){
  while true; do
    clear 2>/dev/null
    banner
    echo " ${C_B}1)${C_0} toggle spoof on/off"
    echo " ${C_B}2)${C_0} set One UI target   (6.0+, e.g. 6.1)"
    echo " ${C_B}3)${C_0} set Android target  (14-17)"
    echo " ${C_B}4)${C_0} set security patch  (YYYY-MM-DD / off)"
    echo " ${C_B}5)${C_0} apply now"
    echo " ${C_B}6)${C_0} revert to stock props"
    echo " ${C_B}7)${C_0} status"
    echo " ${C_B}0)${C_0} exit"
    printf "${C_B}>${C_0} "
    read -r c || exit 0
    case "$c" in
      1) do_toggle; sleep 1;;
      2) printf "version: "; read -r v; set_oneui "$v"; sleep 1;;
      3) printf "android: "; read -r v; set_android "$v"; sleep 1;;
      4) printf "date/off: "; read -r v; set_patch "$v"; sleep 1;;
      5) do_apply; sleep 1;;
      6) do_revert; sleep 1;;
      7) print_status; printf "enter..."; read -r x || exit 0;;
      0) exit 0;;
    esac
  done
}

boot_apply(){
  load_conf
  if [ "$ENABLED" = "true" ]; then
    find_rp && { save_orig; do_apply >/dev/null 2>&1; }
  else
    find_rp && [ -f "$ORIG" ] && do_revert >/dev/null 2>&1
  fi
}

do_verify(){
  load_conf
  [ "$ENABLED" = "true" ] || return 0
  find_rp || return 0
  want=$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  drift=0
  [ "$(getprop ro.build.version.oneui)" != "$want" ] && drift=1
  if [ "$drift" = "0" ]; then
    return 0
  fi
  log "verify: props drifted, re-applying"
  do_apply >/dev/null 2>&1
}

list_apks(){
  for d in /sdcard/Download /data/local/tmp "$BASE/apks"; do
    [ -d "$d" ] || continue
    ls "$d" 2>/dev/null | while read -r f; do
      case "$f" in *.apk|*.APK) ;; *) continue;; esac
      sz=$(wc -c < "$d/$f" 2>/dev/null)
      sz=$(( ${sz:-0} / 1048576 ))
      echo "OFAPK|$d/$f|${sz}MB"
    done
  done
}

do_installapk(){
  p="$2"
  if [ -z "$p" ] || [ ! -f "$p" ]; then
    echo "${C_R}APK not found: $p${C_0}"
    return 1
  fi
  case "$p" in *.apk|*.APK) ;; *)
    echo "${C_R}Not an APK file${C_0}"; return 1 ;;
  esac
  pkg=$(pm dump "$p" 2>/dev/null | grep -m1 '^package=' | sed 's/^package=//;s/ .*//')
  bd=""
  state="NEW"
  if [ -n "$pkg" ]; then
    ap=$(active_apk_path "$pkg")
    if [ -n "$ap" ]; then
      if is_system_path "$ap"; then
        state="STOCK"
      else
        state="UPDATED"
        bd=$(backup_apk "$pkg")
      fi
    fi
  fi
  echo "${C_C}Installing $(basename "$p") ...${C_0}"
  if pm install -r "$p" >/dev/null 2>&1; then
    record_hist INSTALL "${pkg:-unknown}" "$state" "${bd:--}"
    log "installed $p (prev=$state backup=${bd:--})"
    echo "${C_G}Installed successfully.${C_0}"
  else
    [ -n "$bd" ] && rm -rf "$bd"
    echo "${C_R}Install failed:${C_0}"
    pm install -r "$p" 2>&1 | tail -n3
    return 1
  fi
}

is_system_path(){
  case "$1" in
    /system/*|/product/*|/vendor/*|/system_ext/*|/odm/*) return 0;;
    *) return 1;;
  esac
}

HIST="$BASE/applog.tsv"

record_hist(){
  mkdir -p "$BASE"
  printf '%s %s %s %s %s\n' "$(date '+%s')" "$1" "$2" "${3:--}" "${4:--}" >> "$HIST"
}

active_apk_path(){
  pm path "$1" 2>/dev/null | head -n1 | sed 's/^package://'
}

backup_apk(){
  p="$1"
  [ -n "$p" ] || return 0
  bd="$BASE/backups/${p}-$(date '+%s')"
  mkdir -p "$bd" || return 0
  ok=0
  for f in $(pm path "$p" 2>/dev/null | sed 's/^package://'); do
    case "$f" in
      *.apk) ;;
      *) continue ;;
    esac
    sz=$(wc -c < "$f" 2>/dev/null)
    if [ "${sz:-0}" -gt 1048576000 ]; then
      log "backup skipped (too big): $f"
      continue
    fi
    cp -f "$f" "$bd/" 2>/dev/null && ok=$((ok + 1))
  done
  if [ "$(ls "$bd" 2>/dev/null | grep -c '.apk')" -ge 1 ]; then
    echo "$bd"
  else
    rm -rf "$bd"
    echo ""
  fi
}

restore_backup(){
  d="$1"
  base="$d/base.apk"
  [ -f "$base" ] || base=$(ls "$d"/*.apk 2>/dev/null | head -n1)
  [ -n "$base" ] && [ -f "$base" ] || { echo "${C_R}No usable APK in backup.${C_0}"; return 1; }
  splits=$(ls "$d"/*.apk 2>/dev/null | grep -v "^$base\$")
  if [ -z "$splits" ]; then
    if pm install -r -d "$base" >/dev/null 2>&1; then
      echo "${C_G}Restored from backup.${C_0}"
      return 0
    fi
    echo "${C_R}Restore failed.${C_0}"
    return 1
  fi
  sid=$(pm install-create -r 2>/dev/null | grep -o '[0-9]\+' | head -n1)
  if [ -z "$sid" ]; then
    pm install -r -d "$base" >/dev/null 2>&1 || { echo "${C_R}Restore failed.${C_0}"; return 1; }
    echo "${C_G}Restored (base only).${C_0}"
    return 0
  fi
  pm install-write "$sid" base "$base" >/dev/null 2>&1
  for s in $splits; do
    nm=$(basename "$s" .apk)
    pm install-write "$sid" "$nm" "$s" >/dev/null 2>&1
  done
  out=$(pm install-commit "$sid" 2>&1)
  case "$out" in *Success*|*success*)
    echo "${C_G}Restored from backup (with splits).${C_0}"
    return 0 ;;
  esac
  echo "${C_R}Restore failed: $out${C_0}"
  return 1
}

do_undo(){
  idx="${2:-1}"
  case "$idx" in ''|*[!0-9]*) idx=1 ;; esac
  [ -f "$HIST" ] || { echo "${C_Y}No app history yet.${C_0}"; return 1; }
  total=$(grep -c '' "$HIST")
  [ "$total" -ge 1 ] || { echo "${C_Y}No app history yet.${C_0}"; return 1; }
  tgt=$(( total - idx + 1 ))
  [ "$tgt" -ge 1 ] || { echo "${C_R}No such history entry.${C_0}"; return 1; }
  line=$(sed -n "${tgt}p" "$HIST")
  ts=$(echo "$line" | cut -d' ' -f1)
  act=$(echo "$line" | cut -d' ' -f2)
  pkg=$(echo "$line" | cut -d' ' -f3)
  extra=$(echo "$line" | cut -d' ' -f4)
  bd=$(echo "$line" | cut -d' ' -f5)
  log "undo #$idx: $act $pkg"
  case "$act" in
    REVERT)
      if [ -n "$bd" ] && [ "$bd" != "-" ] && [ -d "$bd" ]; then
        echo "${C_C}Re-applying the update we removed from $pkg ...${C_0}"
        restore_backup "$bd"
        record_hist UNDO "$pkg" "$ts" "-"
      else
        echo "${C_Y}No backup stored for this change - cannot re-apply.${C_0}"
        return 1
      fi ;;
    INSTALL)
      if [ -n "$bd" ] && [ "$bd" != "-" ] && [ -d "$bd" ]; then
        echo "${C_C}Rolling $pkg back to the version before your install ...${C_0}"
        restore_backup "$bd"
      elif [ "$extra" = "STOCK" ]; then
        echo "${C_C}$pkg was stock before - removing the update ...${C_0}"
        pm uninstall --user 0 "$pkg" >/dev/null 2>&1 && echo "${C_G}Done.${C_0}"
      else
        echo "${C_C}$pkg was not installed before - removing it ...${C_0}"
        pm uninstall --user 0 "$pkg" >/dev/null 2>&1 && echo "${C_G}Done.${C_0}"
      fi
      record_hist UNDO "$pkg" "$ts" "-" ;;
    *)
      echo "${C_Y}Nothing to undo for this entry.${C_0}"
      return 1 ;;
  esac
}

hist_cmd(){
  [ -f "$HIST" ] && [ "$(grep -c '' "$HIST" 2>/dev/null)" -ge 1 ] || return 0
  total=$(grep -c '' "$HIST")
  n=$total
  while [ "$n" -ge 1 ]; do
    line=$(sed -n "${n}p" "$HIST")
    idx=$(( total - n + 1 ))
    ts=$(echo "$line" | cut -d' ' -f1)
    act=$(echo "$line" | cut -d' ' -f2)
    pkg=$(echo "$line" | cut -d' ' -f3)
    bd=$(echo "$line" | cut -d' ' -f5)
    hb=n
    [ -n "$bd" ] && [ "$bd" != "-" ] && [ -d "$bd" ] && hb=y
    tm=$(date -u -d "@$ts" '+%m-%d %H:%M' 2>/dev/null || echo "$ts")
    echo "OFHIST|$idx|$tm|$act|$pkg|$hb"
    n=$((n - 1))
    [ $(( total - n )) -ge 15 ] && break
  done
}


list_apps(){
  q=$(echo "${1:-}" | tr 'A-Z' 'a-z')
  res=0; scanned=0
  pm list packages 2>/dev/null | sed 's/^package://' | while read -r p; do
    scanned=$((scanned + 1))
    [ "$scanned" -gt 600 ] && break
    if [ -n "$q" ]; then
      case "$(echo "$p" | tr 'A-Z' 'a-z')" in *"$q"*) ;; *) continue;; esac
    fi
    vn=$(dumpsys package "$p" 2>/dev/null | grep -m1 'versionName=' | sed 's/^.*versionName=//;s/[ ,].*//')
    pp=$(pm path "$p" 2>/dev/null | head -n1 | sed 's/^package://')
    if is_system_path "$pp"; then sys=1; else sys=0; fi
    upd=0
    if [ "$sys" = "1" ]; then
      case "$pp" in /data/app/*) upd=1;; esac
    fi
    echo "OFAPP|$p|${vn:-?}|$sys|$upd|$pp"
    res=$((res + 1))
    [ "$res" -ge 50 ] && break
  done
}

do_revertapp(){
  p="$2"
  if [ -z "$p" ]; then
    echo "${C_R}Usage: revertapp <package>${C_0}"
    return 1
  fi
  pp=$(active_apk_path "$p")
  if [ -z "$pp" ]; then
    echo "${C_R}Package not found: $p${C_0}"
    return 1
  fi
  if ! is_system_path "$pp"; then
    echo "${C_Y}$p is not a system app - no factory version to revert to.${C_0}"
    return 1
  fi
  bd=""
  case "$pp" in /data/app/*) bd=$(backup_apk "$p") ;; esac
  echo "${C_C}Reverting updates for $p ...${C_0}"
  if pm uninstall --user 0 "$p" >/dev/null 2>&1; then
    record_hist REVERT "$p" "-" "${bd:--}"
    log "reverted app $p (backup=${bd:--})"
    if [ -n "$bd" ]; then
      echo "${C_G}$p reverted to stock. Update backed up - undoable from App Tools.${C_0}"
    else
      echo "${C_G}$p reverted to its factory (stock) version. App data kept.${C_0}"
    fi
  else
    [ -n "$bd" ] && rm -rf "$bd"
    echo "${C_R}Revert failed for $p (it may have no updates installed).${C_0}"
    return 1
  fi
}

case "$1" in
  on)         do_apply;;
  off)        do_revert;;
  toggle)     do_toggle;;
  apply)      do_apply;;
  revert)     do_revert;;
  status)     print_status;;
  json)       print_json;;
  menu)       menu;;
  set)        set_oneui "$2";;
  android)    set_android "$2";;
  patch)      set_patch "$2";;
  flags)      flags_cmd "$@";;
  boot)       boot_apply;;
  verify)     do_verify;;
  apks)       list_apks;;
  installapk) do_installapk "$2";;
  apps)       list_apps "$2";;
  revertapp)  do_revertapp "$2";;
  hist)       hist_cmd;;
  undo)       do_undo "undo" "$2";;
  *)          echo "usage: oneforce.sh {on|off|toggle|apply|revert|status|menu|json|verify|set X.Y|android N|patch DATE|flags NAME on/off|apks|installapk F|apps Q|revertapp P|hist|undo [N]}";;
esac
