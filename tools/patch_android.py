"""Ajoute au projet Android généré par `flutter create` ce que le jeu exige :
micro (reconnaissance vocale), vibrations, nom affiché, orientation portrait."""
import re, sys
from pathlib import Path
root = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
man = root / 'android/app/src/main/AndroidManifest.xml'
s = man.read_text()
perms = ['android.permission.RECORD_AUDIO', 'android.permission.VIBRATE', 'android.permission.INTERNET']
for p in perms:
    if p not in s:
        s = s.replace('<application', f'<uses-permission android:name="{p}"/>\n    <application', 1)
if 'android.speech.RecognitionService' not in s:
    q = ('<queries>\n        <intent>\n            <action android:name="android.speech.RecognitionService" />\n        </intent>\n    </queries>\n')
    if '<queries>' in s:
        s = s.replace('<queries>', q.rstrip('\n').replace('</queries>', ''), 1)
    else:
        s = s.replace('</manifest>', '    ' + q + '</manifest>')
# AdMob : identifiant d'application (TEST public Google, à remplacer avant publication)
if 'com.google.android.gms.ads.APPLICATION_ID' not in s:
    s = s.replace('</application>', '    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
                  '            android:value="ca-app-pub-3940256099942544~3347511713"/>\n    </application>', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="BOOM PARTY"', s, count=1)
if 'android:screenOrientation' not in s:
    s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:screenOrientation="portrait"', 1)
man.write_text(s)
print('AndroidManifest patché')

# minSdk 24 : exigé par la reconnaissance vocale hors ligne (sherpa-onnx, record)
for g in (root / 'android/app/build.gradle.kts', root / 'android/app/build.gradle'):
    if g.exists():
        t = g.read_text()
        t2 = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', t)
        t2 = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', t2)
        if t2 != t:
            g.write_text(t2)
            print('minSdk = 24 :', g.name)

# Règles R8 : en release, R8 supprimait la base Room de WorkManager (tirée par
# AdMob) → plantage au lancement « Failed to create an instance of WorkDatabase ».
pro = root / 'android/app/proguard-rules.pro'
rules = """# BOOM PARTY — classes instanciées par réflexion
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.**
"""
if not pro.exists() or 'WorkDatabase_Impl' not in pro.read_text():
    pro.write_text((pro.read_text() if pro.exists() else '') + rules)
    print('proguard-rules.pro écrit')
for g in (root / 'android/app/build.gradle.kts',):
    if g.exists():
        t = g.read_text()
        if 'proguard-rules.pro' not in t:
            t = t.replace('signingConfig = signingConfigs.getByName("debug")',
                          'signingConfig = signingConfigs.getByName("debug")\n'
                          '            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")', 1)
            g.write_text(t)
            print('proguardFiles ajouté :', g.name)
