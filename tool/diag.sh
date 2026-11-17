#!/bin/bash
# Uji di emulator: pasang versi lama → update → buka → ketuk menu, rekam log & ANR.
PKG=com.zeon.ingetzeon
D=diag; mkdir -p $D
adb root >/dev/null 2>&1; sleep 3
snap(){ adb exec-out screencap -p > $D/$1.png; }
tap(){
  timeout 25 adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml $D/ui_$2.xml >/dev/null 2>&1
  b=$(python3 tool/find_bounds.py $D/ui_$2.xml "$1" exact)
  [ -z "$b" ] && b=$(python3 tool/find_bounds.py $D/ui_$2.xml "$1")
  echo "TAP '$1' -> $b" | tee -a $D/steps.txt
  if [ -n "$b" ]; then adb shell input tap $b; fi
}
anr(){ adb logcat -d | grep -iE "ANR in|Input dispatching timed out|not responding" | tail -5 | tee -a $D/steps.txt; }

if [ -f old.apk ]; then
  adb install -r old.apk && adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
  adb shell am start -n $PKG/.MainActivity; sleep 25; snap 00_old
  adb shell input keyevent KEYCODE_HOME; sleep 3
fi
adb logcat -c
adb install -r new.apk; adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
echo "pakai versi baru" >> $D/steps.txt
sleep 5
T0=$(date +%s)
adb shell am start -W -n $PKG/.MainActivity | tee -a $D/steps.txt
sleep 20; snap 01_home; anr
adb shell input swipe 540 1900 540 800 400; sleep 2; snap 02_home_scroll
adb shell input swipe 540 800 540 1900 400; sleep 2
tap "ID" lang; sleep 5; snap 03_home_en; anr
tap "Translate" trans; sleep 5; snap 04_trans
adb shell input keyevent KEYCODE_BACK; sleep 2
tap "Profile" prof; sleep 3; snap 05_profile_en
adb shell input swipe 540 1700 540 800 400; sleep 2; snap 06_profile_scroll
PID=$(adb shell pidof $PKG | tr -d '\r')
echo "PID=$PID" >> $D/steps.txt
if [ -n "$PID" ]; then adb shell kill -3 $PID; sleep 4; fi
adb pull /data/anr $D/anr >/dev/null 2>&1
adb logcat -d > $D/logcat.txt
adb logcat -d -b crash > $D/crash.txt
adb shell dumpsys alarm > $D/alarm.txt
adb shell dumpsys activity processes | grep -iE "anr|notResponding" > $D/proc.txt
echo selesai $(( $(date +%s) - T0 ))s >> $D/steps.txt
echo "===== RINGKASAN ====="
cat $D/steps.txt
echo "===== ERROR FLUTTER / ANR ====="
grep -iE "ANR in|Input dispatching|E/flutter|FATAL|Exception|Skipped [0-9]{2,} frames|Davey" $D/logcat.txt | grep -v "AccessibilityNodeInfo" | head -80
echo "===== MAIN THREAD (kill -3) ====="
f=$(ls -t $D/anr/* 2>/dev/null | head -1); [ -n "$f" ] && sed -n '/"main"/,/^$/p' "$f" | head -60
