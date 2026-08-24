#!/system/bin/sh
# One Force - One UI spoof engine (Magisk / KernelSU / KSU Next / SukiSU / APatch)
BASE=/data/adb/one_force
CONF="$BASE/config.conf"
ORIG="$BASE/originals.conf"
LOG="$BASE/log.txt"

E=$(printf '\033')
C_B="${E}[1;34m"; C_C="${E}[1;36m"; C_G="${E}[1;32m"
C_R="${E}[1;31m"; C_Y="${E}[1;33m"; C_0="${E}[0m"

log(){ echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG" 2>/dev/null; }

write_default_conf(){
  mkdir -p "$BASE"
  cat > "$CONF" <<'EOF'
ENABLED=true
ONEUI_MAJOR=6
ONEUI_MINOR=0
ANDROID_VER=14
SPOOF_SEM=true
SPOOF_RELEASE=true
EOF
}

load_conf(){ [ -f "$CONF" ] || write_default_conf; . "$CONF"; }

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
    13) echo 33;;
    14) echo 34;;
    15) echo 35;;
    16) echo 36;;
    17) echo 37;;
    *) echo "";;
  esac
}

save_orig(){
  [ -f "$ORIG" ] && [ "$(grep -c '=' "$ORIG" 2>/dev/null)" -ge 4 ] && return 0
  mkdir -p "$BASE"
  : > "$ORIG"
  for k in ro.build.version.oneui ro.build.version.sem \
           ro.build.version.release ro.build.version.sdk; do
    v=$(getprop "$k")
    [ -z "$v" ] && v="__ABSENT__"
    echo "$k=$v" >> "$ORIG"
  done
  log "originals saved"
}

set_prop(){
  $RP "$1" "$2" >/dev/null 2>&1 || return 1
  [ "$(getprop "$1")" = "$2" ]
}

do_apply(){
  load_conf
  find_rp || {
    log "resetprop not found"
    printf "%s\n" \
      "${C_R}ERROR: no resetprop found.${C_0}" \
      "Your manager does not ship one. Get a static resetprop binary" \
      "(e.g. from Magisk releases) and place it at:" \
      "${C_C}$BASE/bin/resetprop${C_0} (chmod 755), then reboot."
    return 1
  }
  save_orig
  OC=$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  SC=$(sem_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  SK=$(sdk_code "$ANDROID_VER")
  fail=0

  set_prop ro.build.version.oneui "$OC" || { fail=1; log "FAILED oneui -> $OC"; }
  log "oneui -> $OC"

  if [ "$SPOOF_SEM" = "true" ]; then
    set_prop ro.build.version.sem "$SC" || { fail=1; log "FAILED sem -> $SC"; }
    log "sem -> $SC"
  fi

  if [ "$SPOOF_RELEASE" = "true" ] && [ -n "$SK" ]; then
    set_prop ro.build.version.release "$ANDROID_VER" || { fail=1; log "FAILED release"; }
    set_prop ro.build.version.sdk "$SK" || { fail=1; log "FAILED sdk -> $SK"; }
    log "release/sdk -> $ANDROID_VER/$SK"
  fi

  sed -i 's/^ENABLED=.*/ENABLED=true/' "$CONF"
  if [ "$fail" = "1" ]; then
    echo "${C_R}Some props failed to stick - check log.txt${C_0}"
    return 1
  fi
  echo "${C_G}Spoof applied: One UI $ONEUI_MAJOR.$ONEUI_MINOR / Android $ANDROID_VER${C_0}"
}

do_revert(){
  load_conf
  find_rp || {
    log "resetprop not found"
    echo "${C_R}ERROR: no resetprop found. Place it at $BASE/bin/resetprop${C_0}"
    return 1
  }
  if [ ! -f "$ORIG" ]; then
    sed -i 's/^ENABLED=.*/ENABLED=false/' "$CONF"
    echo "${C_Y}Nothing to revert (no originals saved).${C_0}"
    return 0
  fi
  while IFS='=' read -r k v; do
    [ -n "$k" ] || continue
    case "$k" in '#'*) continue;; esac
    if [ "$v" = "__ABSENT__" ]; then
      $RP --delete "$k" >/dev/null 2>&1
    else
      $RP "$k" "$v"
    fi
    log "restored $k"
  done < "$ORIG"
  sed -i 's/^ENABLED=.*/ENABLED=false/' "$CONF"
  echo "${C_G}Reverted to stock props.${C_0}"
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
  echo "OF_CUR_ONEUI=$(getprop ro.build.version.oneui)"
  echo "OF_CUR_SEM=$(getprop ro.build.version.sem)"
  echo "OF_CUR_RELEASE=$(getprop ro.build.version.release)"
  echo "OF_CUR_SDK=$(getprop ro.build.version.sdk)"
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
  sed -i "s/^ONEUI_MAJOR=.*/ONEUI_MAJOR=$ONEUI_MAJOR/" "$CONF"
  sed -i "s/^ONEUI_MINOR=.*/ONEUI_MINOR=$ONEUI_MINOR/" "$CONF"
  echo "${C_C}Target One UI set to $ONEUI_MAJOR.$ONEUI_MINOR. Run 'apply'.${C_0}"
}

set_android(){
  SK=$(sdk_code "$1")
  if [ -z "$SK" ]; then
    echo "${C_R}Unsupported Android version: $1 (use 14-17)${C_0}"
    return 1
  fi
  sed -i "s/^ANDROID_VER=.*/ANDROID_VER=$1/" "$CONF"
  echo "${C_C}Target Android set to $1 (SDK $SK). Run 'apply'.${C_0}"
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
  echo " live oneui : $(getprop ro.build.version.oneui)   sem: $(getprop ro.build.version.sem)"
  echo " live rel   : Android $(getprop ro.build.version.release)  sdk:$(getprop ro.build.version.sdk)"
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
    echo " ${C_B}4)${C_0} apply now"
    echo " ${C_B}5)${C_0} revert to stock props"
    echo " ${C_B}6)${C_0} status"
    echo " ${C_B}0)${C_0} exit"
    printf "${C_B}>${C_0} "
    read -r c || exit 0
    case "$c" in
      1) do_toggle; sleep 1;;
      2) printf "version: "; read -r v; set_oneui "$v"; sleep 1;;
      3) printf "android: "; read -r v; set_android "$v"; sleep 1;;
      4) do_apply; sleep 1;;
      5) do_revert; sleep 1;;
      6) print_status; printf "enter..."; read -r x || exit 0;;
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
  cur=$(getprop ro.build.version.oneui)
  want=$(oneui_code "$ONEUI_MAJOR" "$ONEUI_MINOR")
  [ "$cur" = "$want" ] && return 0
  log "verify: props drifted, re-applying"
  find_rp && do_apply >/dev/null 2>&1
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
  echo "${C_C}Installing $(basename "$p") ...${C_0}"
  if pm install -r "$p" >/dev/null 2>&1; then
    echo "${C_G}Installed successfully.${C_0}"
  else
    echo "${C_R}Install failed (see log). Trying verbose:${C_0}"
    pm install -r "$p"
    return 1
  fi
}

is_system_path(){
  case "$1" in
    /system/*|/product/*|/vendor/*|/system_ext/*|/odm/*) return 0;;
    *) return 1;;
  esac
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
    echo "OFAPP|$p|${vn:-?}|$sys"
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
  pp=$(pm path "$p" 2>/dev/null | head -n1 | sed 's/^package://')
  if [ -z "$pp" ]; then
    echo "${C_R}Package not found: $p${C_0}"
    return 1
  fi
  if ! is_system_path "$pp"; then
    echo "${C_Y}$p is not a system app - no factory version to revert to.${C_0}"
    return 1
  fi
  echo "${C_C}Reverting updates for $p ...${C_0}"
  if pm uninstall --user 0 "$p" >/dev/null 2>&1; then
    log "reverted app $p"
    echo "${C_G}$p reverted to its factory (stock) version. App data kept.${C_0}"
  else
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
  boot)       boot_apply;;
  verify)     do_verify;;
  apks)       list_apks;;
  installapk) do_installapk "$2";;
  apps)       list_apps "$2";;
  revertapp)  do_revertapp "$2";;
  *)          echo "usage: oneforce.sh {on|off|toggle|apply|revert|status|menu|set X.Y|android N|json|verify|apks|installapk F|apps Q|revertapp P}";;
esac
