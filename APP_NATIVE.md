# Militant Flutter - Application Native

## 🎯 Transformation en App Native

L'application Militant Flutter a été transformée d'une simple TWA (Trusted Web Activity) en une **vraie application native** qui utilise l'API REST de Militant.

## 📱 Architecture

### Structure du projet

```
lib/
├── main.dart                 # Point d'entrée, splash screen
├── models/                   # Modèles de données
│   ├── post.dart            # Modèle Post
│   └── user.dart            # Modèle User
├── screens/                  # Écrans de l'application
│   ├── login_screen.dart    # Écran de connexion
│   └── home_screen.dart     # Écran d'accueil (feed)
├── services/                 # Services
│   └── api_service.dart     # Service API REST
└── widgets/                  # Widgets réutilisables
    └── post_card.dart       # Widget d'affichage d'un post
```

### Fonctionnalités implémentées

✅ **Authentification**
- Login avec username/email + password
- Support multi-serveur (choisir son instance Militant)
- Stockage sécurisé du token
- Auto-login si token valide

✅ **Feed de publications**
- Affichage des posts avec pagination
- Pull-to-refresh
- Like/Unlike en temps réel
- Affichage des médias (images)
- Compteurs (likes, commentaires, partages)

✅ **Interface native**
- Design Material sombre (thème Militant)
- Couleur rouge signature (#BE1E1E)
- Navigation bottom bar
- Animations fluides

### API Service

Le service `ApiService` gère toutes les communications avec l'API:

```dart
// Singleton pour accès global
final api = await ApiService.getInstance();

// Authentification
await api.login(username, password);

// Récupérer les posts
final posts = await api.getPosts(page: 1);

// Liker un post
await api.likePost(postId);

// Profil utilisateur
final profile = await api.getProfile();
```

## 🚀 Installation et lancement

### Prérequis

- Flutter SDK 3.9.0+
- Dart 3.0+
- Android Studio / Xcode

### Installation des dépendances

```bash
cd militant_flutter
flutter pub get
```

### Lancer l'application

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Web (pour tests)
flutter run -d chrome
```

### Build production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (pour Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 🔧 Configuration

### Changer le serveur par défaut

Dans `lib/screens/login_screen.dart`:

```dart
final _serverController = TextEditingController(
  text: 'https://votre-instance.com',  // Modifier ici
);
```

### Endpoints API disponibles

Le service API supporte tous les endpoints de l'API Militant:

- ✅ `/api/v1/auth.php` - Authentification
- ✅ `/api/v1/posts.php` - Publications
- ✅ `/api/v1/likes.php` - Likes
- ✅ `/api/v1/users.php` - Utilisateurs
- ✅ `/api/v1/messages.php` - Messages
- ✅ `/api/v1/message_groups.php` - Groupes de messages
- ✅ `/api/v1/notifications.php` - Notifications
- ✅ `/api/v1/groups.php` - Groupes militants
- ✅ `/api/v1/events.php` - Événements

## 📝 TODO - Fonctionnalités à implémenter

### Priorité haute
- [ ] Créer un nouveau post
- [ ] Commentaires sur les posts
- [ ] Partage de posts
- [ ] Profil utilisateur
- [ ] Édition du profil

### Priorité moyenne
- [ ] Messages privés
- [ ] Groupes militants
- [ ] Événements
- [ ] Notifications push
- [ ] Recherche

### Priorité basse
- [ ] Stories
- [ ] Lives
- [ ] Pages organisations
- [ ] Modération
- [ ] Thème clair

## 🌐 Support multi-serveur

L'application supporte nativement plusieurs instances Militant:

1. L'utilisateur peut choisir son serveur au login
2. Le serveur est sauvegardé localement
3. Possibilité de changer de serveur à tout moment
4. Support de plusieurs comptes (à implémenter)

## 🔐 Sécurité

- Token JWT stocké de manière sécurisée avec `shared_preferences`
- HTTPS obligatoire pour les communications
- Validation des certificats SSL
- Pas de stockage de mot de passe en clair

## 📦 Dépendances

```yaml
dependencies:
  flutter: sdk
  http: ^1.2.0                    # Requêtes HTTP
  shared_preferences: ^2.5.4      # Stockage local
  flutter_svg: ^2.2.3             # Support SVG
  cupertino_icons: ^1.0.8         # Icônes iOS
```

## 🎨 Design

- **Couleur principale**: #BE1E1E (rouge Militant)
- **Fond**: #121212 (noir)
- **Cartes**: #1E1E1E (gris foncé)
- **Texte**: #FFFFFF (blanc)
- **Texte secondaire**: #888888 (gris)

## 📱 Compatibilité

- ✅ Android 5.0+ (API 21+)
- ✅ iOS 12.0+
- ✅ Web (PWA)
- ⚠️ Desktop (non testé)

## 🤝 Contribution

Pour contribuer au développement de l'app:

1. Créer une branche feature
2. Implémenter la fonctionnalité
3. Tester sur Android et iOS
4. Créer une merge request

## 📄 Licence

Même licence que le projet Militant principal.
