# Militant - Application Mobile

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-AGPL--3.0-red?style=flat)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=flat)]()

Application mobile Flutter pour le réseau social militant décentralisé.

## Description

Militant est un réseau social décentralisé conçu pour les mouvements militants et les organisations politiques. Cette application mobile permet de se connecter à n'importe quelle instance Militant auto-hébergée.

## Fonctionnalités

- **Connexion multi-instances** : Connectez-vous à n'importe quelle instance Militant
- **Interface native** : Écran de bienvenue et sélection de serveur en Flutter natif
- **WebView intégrée** : Navigation fluide dans l'application
- **Sauvegarde des préférences** : L'URL du serveur est mémorisée
- **Thème sombre** : Interface moderne avec couleurs du projet

## Prérequis

- Flutter 3.0 ou supérieur
- Dart 3.0 ou supérieur
- Android Studio / Xcode (pour le développement)
- Un émulateur ou appareil physique

## Installation

### Cloner le projet

```bash
git clone https://gitlab.com/votre-username/militant-flutter.git
cd militant_flutter
```

### Installer les dépendances

```bash
flutter pub get
```

### Lancer l'application

```bash
# Sur émulateur/appareil connecté
flutter run

# Build APK de debug
flutter build apk --debug

# Build APK de release
flutter build apk --release
```

## Configuration

L'application se connecte par défaut à `https://militant.revlibertaire.com`. Vous pouvez modifier cette URL dans le code ou directement depuis l'interface de l'application.

### Modifier l'URL par défaut

Éditez `lib/main.dart` ligne 48 :

```dart
final TextEditingController _urlController = TextEditingController(
  text: 'https://votre-instance.com',
);
```

## Structure du projet

```
militant_flutter/
├── lib/
│   └── main.dart           # Code principal de l'application
├── android/                # Configuration Android
├── ios/                    # Configuration iOS
├── assets/
│   └── logo.svg           # Logo de l'application
└── pubspec.yaml           # Dépendances Flutter
```

## Dépendances

- `webview_flutter` : Affichage du site web dans l'app
- `shared_preferences` : Sauvegarde des préférences utilisateur
- `flutter_svg` : Affichage du logo SVG

## Build de production

### Android

```bash
# Générer un APK signé
flutter build apk --release

# Générer un App Bundle (recommandé pour Play Store)
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Déploiement

### Google Play Store

1. Créer un compte développeur Google Play
2. Générer une clé de signature
3. Build l'App Bundle : `flutter build appbundle --release`
4. Uploader sur Play Console

### Apple App Store

1. Créer un compte développeur Apple
2. Configurer les certificats et profils
3. Build : `flutter build ios --release`
4. Uploader via Xcode ou Transporter

## Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Commit les changements (`git commit -m 'Ajout fonctionnalité'`)
4. Push vers la branche (`git push origin feature/amelioration`)
5. Ouvrir une Merge Request

## Licence

Ce projet est sous licence AGPL-3.0. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## Liens

- [Site web](https://militant.revlibertaire.com)
- [Documentation](https://jointomilitant.org)
- [Instance principale](https://militant.revlibertaire.com)
- [Projet principal](https://gitlab.com/votre-username/militant)

## Support

Pour toute question ou problème :

- Ouvrir une issue sur GitLab
- Contacter l'équipe de développement
- Consulter la documentation

## Changelog

Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique des versions.

---

Développé avec Flutter pour le mouvement militant
