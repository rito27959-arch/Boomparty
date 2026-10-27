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
