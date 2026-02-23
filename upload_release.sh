#!/bin/bash

# Configuration
VERSION=$(grep "version: " pubspec.yaml | sed 's/version: //')
echo "🚀 Préparation de la version $VERSION pour Google Play Store..."

# Nettoyage
echo "🧹 Nettoyage du projet..."
flutter clean
flutter pub get

# Build App Bundle
echo "📦 Génération de l'App Bundle (AAB)..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo "✅ Build réussi !"
    echo "📍 Fichier généré : build/app/outputs/bundle/release/app-release.aab"
    echo "👉 Prochaine étape : Uploader ce fichier sur la Google Play Console."
else
    echo "❌ Erreur lors du build."
    exit 1
fi
