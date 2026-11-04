#!/usr/bin/env bash
# Crée les dossiers android/ et ios/ (générés par Flutter) avec les réglages
# de l'application. Utilisé par GitHub Actions ; sur ordinateur :
#   bash tool/prepare_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="MCS Factures"

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org com.mcsvision --project-name mcs_facture --platforms=android,ios .
fi

# Le test d'exemple généré par Flutter ne correspond pas à cette app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

# ---------- Android ----------
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$NAME\"/" "$MANIFEST"
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

echo "android/ et ios/ prêts."
