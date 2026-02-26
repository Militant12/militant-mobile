#!/bin/bash

# Configuration
VERSION=$(grep "version: " pubspec.yaml | sed 's/version: //')
echo "🚀 Préparation de la version $VERSION pour Google Play Store..."

# Resolve Flutter binary
if command -v flutter >/dev/null 2>&1; then
    FLUTTER_CMD="flutter"
elif [ -f "android/local.properties" ]; then
    FLUTTER_SDK=$(grep "^flutter.sdk=" android/local.properties | cut -d'=' -f2-)
    if [ -n "$FLUTTER_SDK" ] && [ -x "$FLUTTER_SDK/bin/flutter" ]; then
        FLUTTER_CMD="$FLUTTER_SDK/bin/flutter"
    else
        echo "❌ Flutter introuvable (PATH + android/local.properties)."
        exit 1
    fi
else
    echo "❌ Flutter introuvable (PATH + android/local.properties)."
    exit 1
fi

# Nettoyage
echo "🧹 Nettoyage du projet..."
"$FLUTTER_CMD" clean
"$FLUTTER_CMD" pub get

# Build App Bundle
echo "📦 Génération de l'App Bundle (AAB)..."
"$FLUTTER_CMD" build appbundle --release

if [ $? -eq 0 ]; then
    AAB_PATH=$(find build/app/outputs/bundle/release -maxdepth 1 -type f -name "*.aab" | head -n 1)
    echo "✅ Build réussi !"
    if [ -n "$AAB_PATH" ]; then
        echo "📍 Fichier généré : $AAB_PATH"
        echo "👉 Prochaine étape : Uploader ce fichier sur la Google Play Console."
    else
        echo "⚠️ Build OK mais fichier .aab introuvable dans build/app/outputs/bundle/release"
    fi
else
    echo "❌ Erreur lors du build."
    exit 1
fi
