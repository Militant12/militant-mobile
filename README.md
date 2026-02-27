# Militant - Application Mobile

<p align="center">
  <img src="assets/logo.svg" alt="Militant Logo" width="200"/>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.0+-02569B?style=flat&logo=flutter" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat&logo=dart" alt="Dart"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-AGPL--3.0-red?style=flat" alt="License"></a>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=flat&logo=android" alt="Android">
  <img src="https://img.shields.io/badge/iOS-Coming%20Soon-999999?style=flat&logo=apple" alt="iOS">
</p>

<p align="center">
  Application mobile Flutter pour le réseau social militant décentralisé
</p>

---

## Description

Militant est un réseau social décentralisé conçu pour les mouvements militants et les organisations politiques. Cette application mobile permet de se connecter à n'importe quelle instance Militant auto-hébergée.

## Fonctionnalités

### Réseau Social Complet
- **Posts** : Création, modification, suppression de publications avec support multimédia (images, vidéos, audio)
- **Interactions** : Likes, commentaires, partages, réactions
- **Profils** : Personnalisation complète avec avatar, bannière, bio, liens sociaux
- **Badges militants** : Système de badges exclusif à l'app mobile (militant, antifa, anarchiste, CNT-AIT, CNT-F, CNT-SO, FA, OCL, CGA, UCL, FLL, SLM)

### Communication
- **Messages privés** : Conversations individuelles et groupes
- **Notifications** : Système de notifications en temps réel
- **Mentions** : Mentionnez d'autres utilisateurs avec @
- **Liens cliquables** : Détection automatique des URLs avec cartes de prévisualisation pour les réseaux sociaux

### Groupes & Événements
- **Groupes** : Créez et rejoignez des groupes militants
- **Événements** : Organisez et participez à des événements
- **Stories** : Partagez des moments éphémères (24h)
- **Lives** : Diffusions en direct

### Modération & Sécurité
- **Modération Démocratique** : Système révolutionnaire où les modérateurs sont élus par vote (70% consensus)
- **Transparence** : Journal public de toutes les actions de modération
- **Candidature** : Tout utilisateur peut se porter candidat et retirer sa candidature
- **Révocation** : Les modérateurs peuvent être révoqués par vote populaire
- **Actions** : Suppression directe et avertissements pour les élus
- **Signalements** : Signalez les contenus inappropriés
- **Comptes privés** : Contrôlez qui peut vous suivre
- **Blocage** : Bloquez les utilisateurs indésirables

### Multilingue
- **3 langues** : Français, Anglais, Espéranto
- **Traduction automatique** : Traduisez les posts dans votre langue

### Technique
- **Connexion multi-instances** : Connectez-vous à n'importe quelle instance Militant
- **Mode hors ligne** : Consultez le contenu même sans connexion
- **Thème sombre** : Interface moderne avec couleurs du projet
- **Performance** : Optimisé pour supporter des milliers d'utilisateurs simultanés

## Prérequis

- Flutter 3.0 ou supérieur
- Dart 3.0 ou supérieur
- Android Studio (pour le développement Android)
- Un émulateur Android ou appareil physique

**Note :** Android est supporté. 

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

### URL de l'instance

L'application se connecte par défaut à `https://militant.revlibertaire.com`. Vous pouvez changer d'instance directement depuis l'écran de connexion.

### Badges militants (exclusif mobile)

Les badges militants sont une fonctionnalité exclusive à l'application mobile. Ils permettent d'afficher votre appartenance à un mouvement ou une organisation :

- Militant (générique)
- Antifa
- Anarchiste
- CNT-AIT, CNT-F, CNT-SO
- FA (Fédération Anarchiste)
- OCL (Organisation Communiste Libertaire)
- CGA (Coordination des Groupes Anarchistes)
- UCL (Union Communiste Libertaire)
- FLL (Front de Libération Libertaire)
- SLM (Solidarité Libertaire Militante)

Pour choisir votre badge : Profil → Paramètres → Mon badge militant

## Structure du projet

```
militant_flutter/
├── lib/
│   ├── main.dart                    # Point d'entrée de l'application
│   ├── models/                      # Modèles de données
│   │   ├── post.dart
│   │   ├── user.dart
│   │   └── ...
│   ├── screens/                     # Écrans de l'application
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── messages_screen.dart
│   │   ├── groups_screen.dart
│   │   ├── events_screen.dart
│   │   ├── badge_selection_screen.dart
│   │   └── ...
│   ├── widgets/                     # Composants réutilisables
│   │   ├── post_card.dart
│   │   ├── militant_badge.dart
│   │   ├── linkable_text.dart
│   │   └── ...
│   └── services/                    # Services (API, langue)
│       ├── api_service.dart
│       └── language_service.dart
├── android/                         # Configuration Android
├── ios/                            # Configuration iOS
├── assets/
│   ├── logo.svg                    # Logo de l'application
│   ├── badges/                     # Badges militants (exclusif mobile)
│   │   ├── militant.svg
│   │   ├── antifa.svg
│   │   ├── anarchist.svg
│   │   └── ...
│   └── offline.html                # Page hors ligne
└── pubspec.yaml                    # Dépendances Flutter
```

## Dépendances principales

- `http` : Communication avec l'API REST
- `shared_preferences` : Sauvegarde des préférences utilisateur
- `flutter_svg` : Affichage des logos et badges SVG
- `image_picker` : Sélection d'images et vidéos
- `video_player` : Lecture de vidéos
- `audioplayers` : Lecture de fichiers audio
- `file_picker` : Sélection de fichiers
- `url_launcher` : Ouverture de liens externes
- `share_plus` : Partage de contenu
- `intl` : Internationalisation et formatage de dates

## Build de production

### Android

```bash
# Générer un APK signé
flutter build apk --release

# Générer un App Bundle (recommandé pour Play Store)
flutter build appbundle --release
```

## Performance & Scalabilité

L'application et l'API sont optimisées pour supporter un grand nombre d'utilisateurs :

- **Rate limiting généreux** : 1000 requêtes/minute par IP, 500-1000 requêtes/heure par utilisateur
- **Capacité** : Support de 5 000 à 50 000+ utilisateurs actifs simultanés selon le serveur
- **Optimisations** : Pagination, cache, requêtes optimisées
- **Sécurité** : Protection contre les attaques DDoS, brute force, injection SQL, XSS

## Déploiement

### Google Play Store

1. Créer un compte développeur Google Play
2. Générer une clé de signature
3. Build l'App Bundle : `flutter build appbundle --release`
4. Uploader sur Play Console

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
- [Projet principal](https://gitlab.com/miliant1/militant)

## Support

Pour toute question ou problème :

- Ouvrir une issue sur GitLab
- Contacter l'équipe de développement
- Consulter la documentation

## Changelog

Voir [CHANGELOG.md](CHANGELOG.md) pour l'historique des versions.

---

Développé avec Flutter pour le mouvement militant
