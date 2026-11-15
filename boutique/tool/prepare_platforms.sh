#!/usr/bin/env bash
# Crée android/ et web/ (générés par Flutter) avec les réglages de MCS Boutique.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="MCS Boutique"

if [ ! -d android ] || [ ! -d web ]; then
  flutter create --org com.mcsvision --project-name mcs_boutique --platforms=android,web .
fi
rm -f test/widget_test.dart

# ---------- Android ----------
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$NAME\"/" "$MANIFEST"
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
if ! grep -q 'android:scheme="https"' "$MANIFEST"; then
  sed -i.bak 's#</manifest>#    <queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>\n    </queries>\n</manifest>#' "$MANIFEST"
fi
rm -f "$MANIFEST.bak"

# Firebase demande Android 6 (API 23) au minimum.
for G in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$G" ] || continue
  sed -i.bak -E 's/minSdk = flutter\.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/; s/minSdkVersion flutter\.minSdkVersion/minSdkVersion Math.max(flutter.minSdkVersion, 23)/' "$G"
  rm -f "$G.bak"
done
for GRADLE in android/build.gradle.kts android/build.gradle; do
  if [ -f "$GRADLE" ] && ! grep -q 'lintVital' "$GRADLE"; then
    cat >> "$GRADLE" <<'GR'

subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
}
GR
  fi
done

# ---------- Web (iPhone : « Ajouter à l'écran d'accueil ») ----------
python3 - <<'PY'
import json, re
m = json.load(open('web/manifest.json'))
m.update({
    'name': 'MCS Boutique',
    'short_name': 'MCS Boutique',
    'description': 'Boutique MCS VISION : informatique, caméras, installation',
    'background_color': '#0B2A5B',
    'theme_color': '#0B2A5B',
    'display': 'standalone',
    'orientation': 'portrait',
})
json.dump(m, open('web/manifest.json', 'w'), ensure_ascii=False, indent=2)
h = open('web/index.html', encoding='utf-8').read()
h = re.sub(r'<title>.*?</title>', '<title>MCS Boutique</title>', h, flags=re.S)
h = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r'\1MCS Boutique', h)
h = re.sub(r'(name="description" content=")[^"]*', r'\1Boutique MCS VISION : informatique, caméras, installation', h)
if 'theme-color' not in h:
    h = h.replace('</head>', '  <meta name="theme-color" content="#0B2A5B">\n</head>')
open('web/index.html', 'w', encoding='utf-8').write(h)
PY

echo "android/ et web/ prêts."
