#!/usr/bin/env bash
# Installe et lance BOOM PARTY sur l'appareil adb, puis récupère logcat et captures.
OUT=${1:-out}
mkdir -p "$OUT"
APK=build/app/outputs/flutter-apk/app-x86_64-release.apk
PKG=com.boomparty.boom_party
adb logcat -c
adb install -r -g "$APK" 2>&1 | tee "$OUT/install.txt"
adb shell am start -W -n "$PKG/.MainActivity" 2>&1 | tee "$OUT/start.txt"
for t in 5 15 30; do
  sleep $(( t == 5 ? 5 : 10 ))
  adb exec-out screencap -p > "$OUT/ecran_${t}s.png"
  adb shell pidof "$PKG" > "$OUT/pid_${t}s.txt" || echo "PAS DE PROCESSUS" > "$OUT/pid_${t}s.txt"
done
python3 tools/smoke_play.py "$OUT" || true
adb logcat -d > "$OUT/logcat_complet.txt"
adb logcat -d -b crash > "$OUT/logcat_crash.txt"
grep -E "AndroidRuntime|FATAL|flutter|DEBUG|libc|E/|Exception|boom" "$OUT/logcat_complet.txt" | head -400 > "$OUT/logcat_filtre.txt"
exit 0
