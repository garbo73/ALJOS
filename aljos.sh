#!/bin/sh
# ALJOS: a clean home screen for Amazon Fire TV, installed over Wi-Fi with adb.
#
#   ./aljos.sh install   <tv-ip>             build, install, take over the Home button, open it
#   ./aljos.sh wallpaper <tv-ip> photo.jpg   use your own photo
#   ./aljos.sh undo      <tv-ip> [--uninstall] turn everything back on (and remove ALJOS)
#   ./aljos.sh memory    <tv-ip>             free memory right now
#
# Nothing is ever deleted from the TV. Apps are disabled, and undo turns them back on.
set -e
cd "$(dirname "$0")"

CMD=$1; IP=$2
[ -n "$CMD" ] && [ -n "$IP" ] || { sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
case "$IP" in *:*|emulator-*) ;; *) IP=$IP:5555 ;; esac

PKG=com.aljos.launcher
SVC=$PKG/$PKG.HomeService
LOG=disabled.txt # what debloat turned off, so undo can turn it back on (also kept on the TV)
TVLOG=/data/local/tmp/aljos-disabled.txt

ADB=$(command -v adb || true)
for a in /opt/homebrew/share/android-commandlinetools/platform-tools/adb "$HOME/Library/Android/sdk/platform-tools/adb"; do
  [ -n "$ADB" ] || { [ -x "$a" ] && ADB=$a; }
done
[ -n "$ADB" ] || { echo "adb not found. macOS: brew install --cask android-platform-tools" >&2; exit 1; }
tv() { "$ADB" -s "$IP" shell "$@" </dev/null | tr -d '\r'; } # </dev/null: adb would eat read loops

connect() {
  "$ADB" connect "$IP" >/dev/null 2>&1 || true
  state=$("$ADB" -s "$IP" get-state 2>/dev/null || true)
  if [ "$state" != device ]; then
    echo "Look at the TV: choose \"Always allow from this computer\" and press OK."
    i=0
    while [ "$state" != device ] && [ $i -lt 45 ]; do
      sleep 2; i=$((i + 1))
      "$ADB" connect "$IP" >/dev/null 2>&1 || true
      state=$("$ADB" -s "$IP" get-state 2>/dev/null || true)
    done
  fi
  [ "$state" = device ] || { echo "Couldn't connect to $IP. Is ADB debugging on? (Settings > My Fire TV > Developer Options)" >&2; exit 1; }
  os=$(tv getprop ro.build.version.name)
  case "$os" in "Fire OS"*) ;; *) os="Android $(tv getprop ro.build.version.release)" ;; esac
  echo "Connected to $(tv getprop ro.product.model), $os"
}

memory() {
  tv cat /proc/meminfo | awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "Free memory: %d MB of %d MB\n", a/1024, t/1024}'
}

home_on() {
  cur=$(tv settings get secure enabled_accessibility_services)
  case "$cur" in
    *"$SVC"*) ;;
    ""|null) tv settings put secure enabled_accessibility_services "$SVC" ;;
    *) tv settings put secure enabled_accessibility_services "$cur:$SVC" ;;
  esac
  tv settings put secure accessibility_enabled 1
}

home_off() {
  cur=$(tv settings get secure enabled_accessibility_services)
  rest=$(echo "$cur" | tr ':' '\n' | grep -v -x "$SVC" | grep -v -x null | paste -sd: - || true)
  if [ -n "$rest" ]; then tv settings put secure enabled_accessibility_services "$rest"
  else tv settings delete secure enabled_accessibility_services >/dev/null; fi
}

case "$CMD" in
install)
  connect
  [ -f out/ALJOS.apk ] || ./build.sh
  "$ADB" -s "$IP" install -r out/ALJOS.apk
  # On this Fire OS 5 device, ADB cannot reliably grant Accessibility access.
  # Do not write secure settings or disable Amazon packages automatically.
  tv am start -n $PKG/.MainActivity >/dev/null 2>&1
  echo "ALJOS installed and opened. Amazon HOME remains untouched."
  echo "Next: test the app, then enable ALJOS Home button manually only if Fire OS permits it."
  ;;

debloat)
  echo "Debloat is disabled for this AFTT / Fire OS 5.1.1 adaptation." >&2
  echo "This model has refused package-disable commands; no system packages will be changed." >&2
  exit 2
  ;;

wallpaper)
  [ -f "$3" ] || { echo "usage: ./aljos.sh wallpaper <tv-ip> photo.jpg" >&2; exit 1; }
  connect
  tmp=$(mktemp -d)/wallpaper.jpg
  # Fire TV draws at 1920x1080: scale big photos down so they load fast and use little memory.
  if command -v magick >/dev/null; then magick "$3" -resize '1920x1080^' -quality 85 "$tmp"
  elif command -v sips >/dev/null; then cp "$3" "$tmp"; sips -Z 1920 "$tmp" >/dev/null
  else cp "$3" "$tmp"; fi
  # Since Android 11 adb can't write into the app's folder, so the app copies the photo in from here.
  TVTMP=/data/local/tmp/aljos-wallpaper.jpg
  "$ADB" -s "$IP" push "$tmp" $TVTMP >/dev/null
  tv chmod 644 $TVTMP
  tv am start -W -n $PKG/.MainActivity --es from $TVTMP --es wallpaper custom >/dev/null 2>&1
  sleep 1 # -W doesn't wait when the app is already in front
  tv rm -f $TVTMP
  echo "Wallpaper set. The picture button on ALJOS switches between it and the built-in ones."
  ;;

undo)
  connect
  list=$( { [ -f "$LOG" ] && cat "$LOG"; tv cat $TVLOG 2>/dev/null; } | sort -u)
  if [ -n "$list" ]; then
    for pkg in $list; do tv pm enable "$pkg" >/dev/null && echo "turned on  $pkg"; done
    rm -f "$LOG"; tv rm -f $TVLOG
  else
    echo "No record of what was turned off, so turning on everything in debloat.txt."
    grep -v '^[[:space:]]*#' debloat.txt | while read -r tier pkg note; do
      [ -n "$pkg" ] && tv pm enable "$pkg" >/dev/null 2>&1 && echo "turned on  $pkg" || true
    done
  fi
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do tv settings put global $k 1; done
  home_off
  echo "Accessibility setting cleaned if ALJOS had been enabled. Amazon launcher was never disabled."
  if [ "$3" = --uninstall ]; then "$ADB" -s "$IP" uninstall $PKG >/dev/null && echo "ALJOS removed."; fi
  ;;

memory) connect; memory ;;

*) sed -n '3,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
