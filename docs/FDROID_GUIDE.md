# 📱 Guide d'Intégration & Soumission F-Droid pour Militant

Ce document récapitule les prérequis, la structure Fastlane et la procédure pour faire accepter l'application **Militant** sur le dépôt officiel **F-Droid**, tout en conservant une compatibilité totale avec le Google Play Store.

---

## 1. Vue d'Ensemble de l'Architecture Double-Cible

Pour respecter la politique stricte de F-Droid (100% Logiciel Libre, aucune dépendance propriétaire obligatoire, pas de traqueur) tout en conservant les notifications OneSignal pour le Play Store, l'application utilise une compilation conditionnelle via `--dart-define` et Gradle :

| Critère | Version F-Droid | Version Google Play Store |
| :--- | :--- | :--- |
| **Identifiant (`applicationId`)** | `com.militant.militant_flutter.fdroid` | `com.militant.militant_flutter` |
| **Notifications Push** | **ntfy** (auto-hébergé, dégooglisé, WebSocket/HTTP) | **OneSignal** (Google FCM) + ntfy en option |
| **Google Play Services** | ❌ Désactivé (`google-services` non appliqué) | ✅ Activé |
| **SDK OneSignal natif** | ❌ Exclu (`com.onesignal:core` non lié) | ✅ Activé |
| **Format de livraison** | APK Release direct signé par F-Droid | Android App Bundle (`.aab`) signé par Play Signing |
| **Drapeaux de build** | `--dart-define=DEFAULT_PUSH_PROVIDER=ntfy --dart-define=FDROID_BUILD=true` | `--dart-define=DEFAULT_PUSH_PROVIDER=onesignal --dart-define=FDROID_BUILD=false` |
| **Script de build** | `./scripts/build_fdroid.sh` | `./scripts/build_playstore.sh` |

---

## 2. Métadonnées Fastlane Supply (`fastlane/metadata/android/`)

F-Droid utilise automatiquement la structure Fastlane présente dans le dépôt pour afficher la fiche de l'application, les captures d'écran, l'icône et les notes de version :

```
fastlane/metadata/android/
├── fr-FR/
│   ├── title.txt                  # Nom de l'app (Militant)
│   ├── short_description.txt      # Résumé court (<= 80 caractères)
│   ├── full_description.txt       # Description complète (<= 4000 caractères)
│   ├── changelogs/
│   │   └── 138.txt                # Notes de version spécifiques au versionCode
│   └── images/
│       ├── icon.png               # Icône officielle (512x512 sans métadonnées EXIF)
│       ├── featureGraphic.png     # Bannière (1024x500 sans EXIF)
│       └── phoneScreenshots/      # Captures d'écran PNG (1_feed.png, etc.)
├── en-US/
│   └── ... (traductions anglaises)
└── es-ES/
    └── ... (traductions espagnoles)
```

> [!NOTE]
> Toutes les images PNG sont automatiquement nettoyées de leurs métadonnées EXIF pour satisfaire le scanner de F-Droid.

---

## 3. Recette F-Droid (`metadata/com.militant.militant_flutter.yml` et `.fdroid.yml`)

Le fichier de recette prêt pour `fdroiddata` est situé dans :
- `metadata/com.militant.militant_flutter.yml` (fichier à soumettre sur GitLab F-Droid)
- `.fdroid.yml` (fichier miroir à la racine du dépôt)

### Extrait de la recette de build F-Droid :
```yaml
Categories:
  - Internet
  - Social
License: GPL-3.0-or-later
AuthorName: Militant
WebSite: https://joinmilitant.revlibertaire.com
SourceCode: https://gitlab.com/militant1/militant-flutter
IssueTracker: https://gitlab.com/militant1/militant-flutter/-/issues
Changelog: https://gitlab.com/militant1/militant-flutter/-/blob/main/CHANGELOG.md

AutoName: Militant
Summary: Le réseau social militant décentralisé, autonome et sans publicité.

RepoType: git
Repo: https://gitlab.com/militant1/militant-flutter.git

Builds:
  - versionName: 1.0.9
    versionCode: 136
    commit: 546a02824cfc96cf0224b7a1c6a6552bbcf55928
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@stable
    rm:
      - ios
      - linux
      - macos
      - web
      - windows
    prebuild:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - .flutter/bin/flutter config --no-analytics
      - .flutter/bin/flutter pub get
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - .flutter/bin/flutter build apk --release --dart-define=DEFAULT_PUSH_PROVIDER=ntfy --dart-define=FDROID_BUILD=true

  - versionName: 1.0.9
    versionCode: 138
    commit: v1.0.9+138
    output: build/app/outputs/flutter-apk/app-release.apk
    srclibs:
      - flutter@stable
    rm:
      - ios
      - linux
      - macos
      - web
      - windows
    prebuild:
      - cp pubspec_fdroid.yaml pubspec.yaml
      - export PUB_CACHE=$(pwd)/.pub-cache
      - .flutter/bin/flutter config --no-analytics
      - .flutter/bin/flutter pub get
    build:
      - export PUB_CACHE=$(pwd)/.pub-cache
      - .flutter/bin/flutter build apk --release --dart-define=DEFAULT_PUSH_PROVIDER=ntfy --dart-define=FDROID_BUILD=true

AutoUpdateMode: Version
UpdateCheckMode: Tags
UpdateCheckData: pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+
CurrentVersion: 1.0.9
CurrentVersionCode: 138
```

Le fichier `pubspec_fdroid.yaml` est volontairement copié avant la résolution des dépendances : il remplace le plugin Flutter OneSignal par un adaptateur libre. Ainsi, aucun SDK OneSignal n'est embarqué dans l'APK F-Droid.

---

## 4. Procédure de Soumission sur F-Droid (Étape par Étape)

### Étape 1 : Créer un compte sur le GitLab de F-Droid
1. Rendez-vous sur [gitlab.com/fdroid/fdroiddata](https://gitlab.com/fdroid/fdroiddata).
2. Cliquez sur **Fork** en haut à droite pour forker le dépôt sur votre compte GitLab.

### Étape 2 : Ajouter la recette de l'application
1. Dans votre fork de `fdroiddata`, créez une nouvelle branche (ex. `add-militant`).
2. Créez le fichier `metadata/com.militant.militant_flutter.yml` et collez-y le contenu de [`metadata/com.militant.militant_flutter.yml`](../metadata/com.militant.militant_flutter.yml).
3. Committez le fichier : `git commit -m "Add com.militant.militant_flutter"`.
4. Poussez la branche sur votre fork.

### Étape 3 : Ouvrir la Merge Request
1. Rendez-vous sur [gitlab.com/fdroid/fdroiddata/-/merge_requests/new](https://gitlab.com/fdroid/fdroiddata/-/merge_requests/new).
2. Sélectionnez le modèle de Merge Request **New App**.
3. Remplissez la checklist (licence GPLv3, pas de binaires propriétaires dans le build, métadonnées Fastlane présentes).
4. Soumettez la Merge Request.

### Étape 4 : Validation du CI F-Droid
- Le bot F-Droid testera automatiquement le clonage, l'analyse des licences, la compilation Flutter et le scan des binaires.
- Une fois fusionnée, les nouvelles versions seront automatiquement détectées et publiées par F-Droid à chaque nouveau tag Git grâce au mode `AutoUpdateMode: Version`.
