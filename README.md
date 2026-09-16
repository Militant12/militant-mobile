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

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.militant.militant_flutter&pcampaignid=web_share">
    <img src="https://img.shields.io/badge/Google%20Play-T%C3%A9l%C3%A9charger-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Télécharger sur Google Play">
  </a>
  <a href="https://apkpure.com/p/com.militant.militant_flutter">
    <img src="assets/apkpure-logo.svg" alt="Disponible sur APKPure" height="40">
  </a>
</p>

---

## Description

Militant est un réseau social décentralisé conçu pour les mouvements militants et les organisations politiques. Cette application mobile permet de se connecter à n'importe quelle instance Militant auto-hébergée.

Version actuelle : **1.0.9+133**


## Nouveautés 1.0.9

- **Fediverse & Profil** :
  - Remplacement de l'adresse email sur le profil par l'identifiant Fediverse complet (ex: `@pseudo@militant.revlibertaire.com`).
  - Clic rapide sur le handle Fediverse pour le copier directement dans le presse-papier avec confirmation.
  - Corrections et améliorations sur l'écran Fediverse et la navigation des profils décentralisés.
  - Ajout du défilement infini fluide (pagination automatique) pour les publications sur les profils.
- **Notifications & Messagerie** :
  - Redirection et ouverture automatique de la conversation (`ChatScreen` et `GroupChatScreen`) lors du clic sur une notification push de message privé ou groupe.
  - Résolution dynamique de l'avatar et du pseudo de l'interlocuteur dans la barre de titre du chat.
  - Décodage JSON sécurisé et résilient dans le client API pour éviter les erreurs de réception serveur.
- **Appels vocaux & vidéo (WebRTC)** :
  - Support complet des appels longue durée : prolongation du relais TURN à 24h sans coupure.
  - Optimisation du chargement et du redimensionnement des avatars d'appel entrant avec Coil 2.7.0 (économie de mémoire RAM).
- **Conformité & Performances Android 15** :
  - Prise en charge native du bord-à-bord Android 15 (`Edge-to-Edge`) et nettoyage des API système dépréciées.
  - Optimisations R8 (fullMode) et réduction de taille des ressources (`resource shrinking`).
  - Version applicative synchronisée sur `1.0.9` (code de version 133).

## Nouveautés 1.0.8

- Optimisation et internationalisation complète de la barre de recherche des groupes (style Facebook) et des messages (Français, Anglais, Espagnol)
- Navigation vers le profil d'un utilisateur en cliquant sur son nom/avatar depuis les messages, invitations et listes de membres.
- Correction du bug d'affichage du changement de compte et de la déconnexion sur les profils tiers (visible uniquement sur son propre profil).
- Réinitialisation du mot de passe depuis l’écran de connexion.
- Changement rapide de compte avec comptes enregistrés localement.
- Ajout d’un autre compte sans déconnexion préalable.
- Protection de la session active pendant l’ajout ou la bascule de compte.
- Correction des cas où un compte local pouvait disparaître après l’ajout d’un autre compte.
- Version affichée dans **À propos** synchronisée avec `1.0.8`.
- Build Android release généré en APK et App Bundle Play Store.

## Fonctionnalités


### Authentification & Comptes
- **Mot de passe oublié** : demande de lien de réinitialisation directement depuis l’écran de connexion.
- **Comptes rapides** : sauvegarde locale des comptes connectés pour basculer rapidement entre plusieurs profils.
- **Ajouter un compte** : connexion à un autre compte sans devoir se déconnecter manuellement du compte courant.
- **Protection de session** : si une session enregistrée est expirée, l’app restaure la session précédente et demande une reconnexion.

### Réseau Social Complet
- **Posts** : Création, modification, suppression de publications avec support multimédia (images, vidéos, audio)
- **Interactions** : Likes, commentaires, partages, réactions
- **Profils** : Personnalisation complète avec avatar, bannière, bio, liens sociaux
- **Badges militants** : Système de badges exclusif à l'app mobile (Militant, Antifa, Anarchiste, CNT-AIT, CNT-F, CNT-SO, FA, OCL, CGA, UCL, FLL, SLM, IWA-AIT, IWW, IAF-IFA, CNT-AIT-E, ULET-AIT)

### Communication
- **Messages privés** : Conversations individuelles et groupes
- **Notifications** : Système de notifications en temps réel
- **Mentions** : Mentionnez d'autres utilisateurs avec @
- **Liens cliquables** : Détection automatique des URLs avec cartes de prévisualisation pour les réseaux sociaux

### Groupes & Événements
- **Groupes** : Créez et rejoignez des groupes militants avec système d’adhésion privée et invitations.
- **Événements** : Organisez et participez à des événements militants locaux ou nationaux.
- **Stories** : Partagez des moments éphémères (24h) avec prévisualisation vidéo.
- **Lives (v1.0.6)** : Diffusions en direct avec modération communautaire et gestion des invités en temps réel.

### Fediverse
- **Espace Fediverse mobile** : onglets dédiés **Flux**, **Profils**, **Abonnements** et **Abonnés**.
- **Recherche fédérée** : recherche de profils et d’adresses comme `@user@instance.tld`.
- **Profils distants** : ouverture des profils Fediverse externes avec affichage des posts récents.
- **Abonnements distants** : suivi et désabonnement de comptes ActivityPub/Mastodon depuis l’application.
- **Flux distant** : consultation des contenus publiés par les comptes fédérés suivis.
- **Identité locale** : affichage de l’identité Fediverse locale de l’utilisateur dans l’application.

### Modération & Sécurité
- **Modération Démocratique** : Système révolutionnaire où les modérateurs sont élus par vote (70% consensus)
- **Transparence** : Journal public de toutes les actions de modération
- **Candidature** : Tout utilisateur peut se porter candidat et retirer sa candidature
- **Révocation** : Les modérateurs peuvent être révoqués par vote populaire
- **Actions** : Suppression directe et avertissements pour les élus
- **Signalements** : Signalez les contenus inappropriés
- **Comptes privés** : Contrôlez qui peut vous suivre


### Multilingue
- **3 langues** : Français, Anglais, Espagnol 
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

L'application se connecte par défaut à `https://api.militant.revlibertaire.com`. Vous pouvez changer d'instance directement depuis l'écran de connexion.

### Lives (v1.0.6) - Système Avancé

L’onglet **Live** s’appuie sur [LiveKit](https://livekit.io/) et offre une expérience de diffusion militante sécurisée.

> [!CAUTION]
> **Sécurité** : Ne compilez **jamais** l'application avec vos secrets (`LIVEKIT_API_SECRET`). L'application utilise uniquement l'URL du serveur et l'URL de l'API pour récupérer des jetons sécurisés. Le secret doit rester exclusivement sur votre serveur `militant-api`.

> [!TIP]
> **Format de l'URL** : L'URL du serveur (`LIVEKIT_URL`) doit impérativement commencer par **`wss://`** (ex: `wss://live.votre-instance.org`).

- **Modération démocratique** : Les créateurs peuvent nommer des modérateurs révocables sans hiérarchie. Le blocage des utilisateurs du chat est immédiat.
- **Gestion des invités (Request Guest)** : Système robuste permettant aux spectateurs de demander à "monter" dans le live, avec approbation/rejet en temps réel par le créateur.
- **Sécurité u{id}** : Utilisation d'identifiants persistants pour garantir une modération efficace même si l'utilisateur change de pseudonyme.
- **Auto-nettoyage** : Fermeture automatique des sessions inactives ou suite à une déconnexion prolongée du créateur (timeout 2 min).
- **Consensus de signalement** : Option de signalement communautaire ; si un seuil de votes est atteint, le live est automatiquement suspendu par sécurité.

**Configuration technique (militant-api)** : configurez au minimum `LIVEKIT_URL`, `LIVEKIT_API_KEY` et `LIVEKIT_API_SECRET` pour que l’endpoint `POST …/v1/lives.php?path=token` puisse répondre.

### Fediverse mobile

L’application intègre désormais un espace **Fediverse** permettant de se connecter plus directement à l’écosystème ActivityPub.

- **Recherche de comptes distants** : prise en charge des handles et profils fédérés.
- **Abonnements / abonnés** : listes dédiées pour retrouver les comptes suivis et les abonnés Fediverse.
- **Flux Fediverse** : lecture des contenus distants synchronisés par l’API.
- **Profils distants** : affichage des avatars, bios, handles et posts récents.

**Côté API (`militant-api`)**, cela suppose l’activation des endpoints Fediverse mobiles, notamment pour :
- la recherche distante
- le suivi / désabonnement de comptes externes
- la récupération des listes `followers` / `following`
- l’exposition du `feed` Fediverse
- la résolution des profils distants

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
- IWA-AIT (International Workers' Association)
- IWW (Industrial Workers of the World)
- IAF-IFA (Internationale des Fédérations Anarchistes)
- CNT-AIT-E (Confederación Nacional del Trabajo)
- ULET-AIT

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
│       ├── account_switcher_service.dart
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
│   │   ├── cnt-ait.png
│   │   ├── cnt-f.jpg
│   │   ├── cnt-so.png
│   │   ├── fa.png
│   │   ├── ocl.gif
│   │   ├── cga.svg
│   │   ├── ucl.jpg
│   │   ├── fll.jpg
│   │   ├── slm.png
│   │   ├── iwa-ait.png
│   │   ├── iww.svg
│   │   ├── iaf-ifa.png
│   │   ├── cnt-ait-e.jpg
│   │   ├── ulet-ait.png
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

# Sorties 1.0.9 générées localement
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/militant-1.0.9-playstore.aab
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
- [Google Play](https://play.google.com/store/apps/details?id=com.militant.militant_flutter&pcampaignid=web_share)
- [APKPure](https://apkpure.com/p/com.militant.militant_flutter)
- [Documentation](https://jointomilitant.revliebrtaire.com)
- [Instance principale](https://api.militant.revlibertaire.com)
- [Projet principal](https://gitlab.com/militant1)

## Support

Pour toute question ou problème :

- Ouvrir une issue sur GitLab
- Contacter l'équipe de développement
- Consulter la documentation
