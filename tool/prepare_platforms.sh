#!/usr/bin/env bash
# Crée les dossiers android/ et ios/ (générés par Flutter) avec les réglages
# de l'application. Utilisé par GitHub Actions ; sur ordinateur :
#   bash tool/prepare_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="MCS Factures"

if [ ! -d android ] || [ ! -d ios ] || [ ! -d web ]; then
  flutter create --org com.mcsvision --project-name mcs_facture --platforms=android,ios,web .
fi

# Le test d'exemple généré par Flutter ne correspond pas à cette app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

# ---------- Android ----------
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$NAME\"/" "$MANIFEST"
# Internet (vérification des mises à jour) aussi en version finale.
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
# Ouvrir les liens https (téléchargement des mises à jour).
if ! grep -q 'android:scheme="https"' "$MANIFEST"; then
  sed -i.bak 's#</manifest>#    <queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>\n    </queries>\n</manifest>#' "$MANIFEST"
fi
rm -f "$MANIFEST.bak"

# ---------- iOS ----------
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    PB=/usr/libexec/PlistBuddy
    set_key() { # clé type valeur
      $PB -c "Delete :$1" "$PLIST" >/dev/null 2>&1 || true
      $PB -c "Add :$1 $2 \"$3\"" "$PLIST"
    }
    set_key CFBundleDisplayName string "$NAME"
    set_key NSPhotoLibraryUsageDescription string "Choisir les photos des produits et le logo de l’entreprise."
    set_key NSCameraUsageDescription string "Prendre en photo les produits à ajouter aux factures."
    set_key NSPhotoLibraryAddUsageDescription string "Enregistrer des images dans la photothèque."
    set_key UIFileSharingEnabled bool true
    set_key LSSupportsOpeningDocumentsInPlace bool true
  else
    echo "PlistBuddy absent (pas sur macOS) : réglages iOS non appliqués."
  fi
fi

# ---------- Web (iPhone via Safari) ----------
if [ -f web/index.html ]; then
  python3 - <<'PY'
import json, re
m = json.load(open('web/manifest.json'))
m.update({
    'name': 'MCS Factures',
    'short_name': 'MCS Factures',
    'description': 'Factures et devis MCS VISION',
    'background_color': '#FFFFFF',
    'theme_color': '#0B2A5B',
    'display': 'standalone',
    'orientation': 'portrait',
})
json.dump(m, open('web/manifest.json', 'w'), ensure_ascii=False, indent=2)
h = open('web/index.html', encoding='utf-8').read()
h = re.sub(r'<title>.*?</title>', '<title>MCS Factures</title>', h, flags=re.S)
h = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r'\1MCS Factures', h)
h = re.sub(r'(name="description" content=")[^"]*', r'\1Factures et devis MCS VISION', h)
if 'theme-color' not in h:
    h = h.replace('</head>', '  <meta name="theme-color" content="#0B2A5B">\n</head>')
open('web/index.html', 'w', encoding='utf-8').write(h)
PY
fi

echo "android/, ios/ et web/ prêts."
