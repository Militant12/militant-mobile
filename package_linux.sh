#!/bin/bash
# Script de création du paquet .deb pour Linux
# Usage: ./package_linux.sh

# Hardcode de la version Linux (séparée de la version web)
VERSION="1.0.5"
BUILD_DIR="build/linux/x64/release/bundle"
PKG_DIR="militant_${VERSION}_amd64"

echo "📦 Préparation du paquet Debian v$VERSION..."

# Vérification du build
if [ ! -d "$BUILD_DIR" ]; then
    echo "❌ Erreur: Le répertoire de build n'existe pas. Lancez 'flutter build linux --release' d'abord."
    exit 1
fi

# Nettoyage
rm -rf "$PKG_DIR"
rm -f "militant-v${VERSION}.deb"

# Création de la structure
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/militant"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/pixmaps"
mkdir -p "$PKG_DIR/DEBIAN"

# Copie des fichiers de build
cp -r "$BUILD_DIR/"* "$PKG_DIR/usr/share/militant/"

# Création du lien symbolique
ln -s "/usr/share/militant/militant" "$PKG_DIR/usr/bin/militant"

# Création du fichier .desktop
cat > "$PKG_DIR/usr/share/applications/militant.desktop" <<EOF
[Desktop Entry]
Name=Militant
Comment=Réseau social militant décentralisé
Exec=militant
Icon=militant
Terminal=false
Type=Application
Categories=Network;Social;
EOF

# Copie de l'icône
if [ -f "assets/icon-512.png" ]; then
    cp "assets/icon-512.png" "$PKG_DIR/usr/share/pixmaps/militant.png"
else
    echo "⚠️ Warning: assets/icon-512.png introuvable."
fi

# Création du fichier control
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: militant
Version: ${VERSION}
Architecture: amd64
Maintainer: Militant Team <contact@revlibertaire.com>
Description: Réseau social militant décentralisé
 Militant est le premier réseau social libertaire autogéré et open-source.
EOF

# Build du .deb
dpkg-deb --build "$PKG_DIR" "militant-v${VERSION}.deb"

echo "✅ Paquet généré : militant-v${VERSION}.deb"

# Copie vers la racine du projet global
echo "📂 Copie vers la racine du projet..."
cp "militant-v${VERSION}.deb" "../militant-v${VERSION}.deb"

# Génération du catalogue APT (pour les mises à jour automatiques)
echo "📦 Génération du catalogue APT dans jointomilitant..."
if command -v dpkg-scanpackages &> /dev/null; then
    # Copier le nouveau .deb dans jointomilitant
    cp "militant-v${VERSION}.deb" "../jointomilitant/militant-v${VERSION}.deb"
    
    # Créer ou mettre à jour le catalogue dans le dossier jointomilitant
    cd ../jointomilitant
    dpkg-scanpackages . /dev/null > Packages
    gzip -9c Packages > Packages.gz
    
    # Générer le fichier Release (nécessaire pour éviter les erreurs de hachage)
    cat > Release <<EOF
Archive: stable
Component: main
Origin: Militant
Label: Militant
Architecture: amd64
Date: $(LANG=C date -Ru)
EOF
    
    echo "✅ Catalogues Packages, Packages.gz et Release mis à jour dans jointomilitant."
    cd ../militant_flutter
else
    echo "⚠️ Warning: dpkg-dev n'est pas installé. Le catalogue APT n'a pas été généré."
fi

# Nettoyage final
rm -rf "$PKG_DIR"

echo "🚀 Terminé !"
