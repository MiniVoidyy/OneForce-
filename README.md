# One Force

Blue-themed root module by [Mini_Voidyy](https://github.com/MiniVoidyy) that
spoofs your One UI / Android version so the Galaxy Store serves app updates
to devices it would normally block.

## Download
Grab **`OneForce-V1.zip`** from this repo and flash it in your manager app.
Managers with update support will pick up new versions automatically via
`update.json`.

## Compatibility
Works with **Magisk**, **KernelSU**, **KernelSU Next**, **SukiSU** and
**APatch**:
- Spoof range: **One UI 6.0 and above** (6.0, 6.1, 7.0, 8.0...).
- Installs via the standard `customize.sh` flow each manager supports.
- `resetprop` is auto-located from Magisk, APatch, KSU/KSU-Next/SukiSU paths.
  If your build ships none (some stock KernelSU builds), drop a static
  resetprop binary at `/data/adb/one_force/bin/resetprop` (chmod 755) and
  reboot - the module will pick it up automatically.
- WebUI works in KernelSU-family managers and WebUIX/MMRL; Magisk users get
  copyable terminal commands as fallback inside the page.
- Action button toggles the spoof in Magisk and KSU-family managers alike.

## Install
Flash `OneForce-v1.0.zip` in your manager app and reboot.

## Use it

**WebUI** - two pages:
- *Spoofer*: pick target versions, Apply spoof, Revert to stock props, Reboot.
- *App Tools*: search installed packages and revert system apps to their
  factory version (removes updates, keeps data), and install APK files from
  Download / /data/local/tmp / /data/adb/one_force/apks or any path.

**Action button** - press Action on the module card to toggle on/off.

**Terminal** (Termux or adb shell):
```
su -c sh /data/adb/one_force/scripts/oneforce.sh menu      # interactive menu
su -c sh /data/adb/one_force/scripts/oneforce.sh status    # show state
su -c sh /data/adb/one_force/scripts/oneforce.sh set 6.1   # One UI target (6.0+)
su -c sh /data/adb/one_force/scripts/oneforce.sh android 15
su -c sh /data/adb/one_force/scripts/oneforce.sh on        # apply spoof
su -c sh /data/adb/one_force/scripts/oneforce.sh off       # revert to stock
su -c sh /data/adb/one_force/scripts/oneforce.sh patch 2026-06-01   # security patch target
su -c sh /data/adb/one_force/scripts/oneforce.sh flags patch off    # disable a spoof flag
su -c sh /data/adb/one_force/scripts/oneforce.sh apps gal  # find packages
su -c sh /data/adb/one_force/scripts/oneforce.sh revertapp com.samsung.android.app.spage
su -c sh /data/adb/one_force/scripts/oneforce.sh apks      # list APK files
su -c sh /data/adb/one_force/scripts/oneforce.sh installapk /sdcard/Download/app.apk
```

## Changelog

**V2**
- Security patch spoofing (`ro.build.version.security_patch`) - unlocks more
  Samsung apps that gate on recent patches
- Advanced card in WebUI: live toggles for sem / android / patch props
- App Tools now shows an UPDATED badge on system apps that have updates
  installed, plus their active APK path
- Stability: atomic config writes, validated config loading, operation locks,
  log rotation, prop write verification with retries, post-boot drift check
- Optional custom `ro.build.version.incremental` (edit config.conf)

**V1**
- Initial release.

## How revert works
The first time a spoof is applied, the stock values of
`ro.build.version.oneui`, `ro.build.version.sem`,
`ro.build.version.release` and `ro.build.version.sdk` are saved to
`/data/adb/one_force/originals.conf`. Reverting restores those exact values
immediately (props absent before are deleted again) - no reboot needed.
Uninstalling the module also reverts everything automatically.

## Notes
- Galaxy Store may additionally gate some apps by device model server-side;
  this module spoofs version props only.
- Config lives at `/data/adb/one_force/config.conf`, log at
  `/data/adb/one_force/log.txt`.
