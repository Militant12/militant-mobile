# Publication sur Google Play Store

Guide complet pour publier l'application Militant sur le Google Play Store.

## Prérequis

- Compte développeur Google Play (25$ frais unique)
- Application fonctionnelle et testée
- Captures d'écran de l'app
- Icône haute résolution (512x512px)
- Description de l'app en plusieurs langues

## Étape 1 : Créer un compte développeur

**Lien d'inscription : https://play.google.com/console/signup**

1. Aller sur https://play.google.com/console/signup
2. Payer les 25$ de frais d'inscription (paiement unique, à vie)
3. Accepter les conditions d'utilisation
4. Compléter votre profil développeur

Une fois inscrit, accéder à la console : https://play.google.com/console

## Étape 2 : Générer une clé de signature

### Créer le keystore

```bash
keytool -genkey -v -keystore ~/militant-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias militant-key
```

Répondre aux questions :
- Mot de passe du keystore : **À SAUVEGARDER**
- Nom, organisation, etc.
- Mot de passe de la clé : **À SAUVEGARDER**

### Configurer Gradle

Créer `android/key.properties` :

```properties
storePassword=VOTRE_STORE_PASSWORD
keyPassword=VOTRE_KEY_PASSWORD
keyAlias=militant-key
storeFile=/home/user/militant-release-key.jks
```

**IMPORTANT : Ne jamais commit ce fichier !**

Ajouter à `.gitignore` :
```
android/key.properties
*.jks
```

### Modifier `android/app/build.gradle.kts`

Ajouter avant `android {` :

```kotlin
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Dans `android {`, ajouter :

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

## Étape 3 : Build de production

```bash
# Nettoyer
flutter clean

# Build App Bundle (recommandé)
flutter build appbundle --release

# Ou build APK
flutter build apk --release
```

Les fichiers générés :
- App Bundle : `build/app/outputs/bundle/release/app-release.aab`
- APK : `build/app/outputs/flutter-apk/app-release.apk`

## Étape 4 : Préparer les assets

### Captures d'écran requises

- **Téléphone** : 2-8 captures (16:9 ou 9:16)
  - Minimum : 320px
  - Maximum : 3840px
  
- **Tablette 7"** : 2-8 captures (optionnel)
- **Tablette 10"** : 2-8 captures (optionnel)

### Icône de l'application

- **512x512px** PNG 32-bit avec transparence
- Déjà disponible : convertir `assets/logo.svg`

```bash
convert -background none assets/logo.svg -resize 512x512 play-store-icon.png
```

### Bannière (Feature Graphic)

- **1024x500px** JPG ou PNG 24-bit
- Pas de transparence

### Description de l'app

**Titre** (max 50 caractères) :
```
Militant - Réseau Social Militant
```

**Description courte** (max 80 caractères) :
```
Réseau social décentralisé pour les mouvements militants et organisations
```

**Description complète** (max 4000 caractères) :
```
Militant est un réseau social décentralisé conçu spécialement pour les mouvements militants, les organisations politiques et les collectifs engagés.

FONCTIONNALITÉS PRINCIPALES

• Connexion multi-instances : Connectez-vous à n'importe quelle instance Militant auto-hébergée
• Décentralisation : Vos données restent sur votre serveur
• Vie privée : Pas de tracking, pas de publicité
• Open Source : Code source disponible sous licence AGPL-3.0

POURQUOI MILITANT ?

Militant offre une alternative éthique aux réseaux sociaux commerciaux. Conçu pour les militants, par des militants.

• Organisez vos actions et événements
• Communiquez en toute sécurité
• Partagez vos idées et contenus
• Créez des groupes et communautés
• Messagerie privée et de groupe
• Stories et publications
• Lives et streaming vidéo

DÉCENTRALISATION

Contrairement aux réseaux sociaux traditionnels, Militant est décentralisé. Vous pouvez :
• Héberger votre propre instance
• Choisir votre serveur de confiance
• Garder le contrôle de vos données

OPEN SOURCE

Le code source est disponible publiquement. Vous pouvez :
• Vérifier le code
• Contribuer au projet
• Créer votre propre version

SUPPORT

Pour toute question ou problème, visitez notre documentation ou contactez-nous.

Instance par défaut : https://militant.revlibertaire.com
```

## Étape 5 : Créer l'application sur Play Console

1. Aller sur https://play.google.com/console
2. Cliquer sur "Créer une application"
3. Remplir :
   - Nom : "Militant"
   - Langue par défaut : Français
   - Type : Application
   - Gratuit/Payant : Gratuit
4. Accepter les déclarations

## Étape 6 : Configurer la fiche du Store

### Fiche du Store

1. Aller dans "Fiche du Store" > "Fiche principale"
2. Uploader :
   - Icône de l'application (512x512)
   - Bannière (1024x500)
   - Captures d'écran (minimum 2)
3. Remplir :
   - Titre
   - Description courte
   - Description complète
4. Catégorie : **Réseaux sociaux**
5. Adresse e-mail de contact
6. Politique de confidentialité (URL)

### Classification du contenu

1. Aller dans "Classification du contenu"
2. Répondre au questionnaire
3. Catégorie : Réseaux sociaux
4. Contenu généré par les utilisateurs : Oui
5. Modération : Oui

### Public cible

1. Aller dans "Public cible"
2. Âge cible : 16 ans et plus
3. Intérêt des enfants : Non

### Tarification et distribution

1. Aller dans "Tarification et distribution"
2. Gratuit : Oui
3. Pays : Sélectionner les pays
4. Contient des publicités : Non
5. Achats intégrés : Non

## Étape 7 : Upload de l'App Bundle

1. Aller dans "Production" > "Créer une version"
2. Uploader `app-release.aab`
3. Remplir les notes de version :

```
Version 1.0.0 - Première version

• Connexion à n'importe quelle instance Militant
• Interface native Flutter
• WebView intégrée
• Sauvegarde des préférences
• Thème sombre
```

4. Cliquer sur "Enregistrer"
5. Cliquer sur "Vérifier la version"

## Étape 8 : Soumettre pour examen

1. Vérifier que tout est complété (icône verte)
2. Cliquer sur "Envoyer pour examen"
3. Attendre l'approbation (1-7 jours généralement)

## Étape 9 : Après publication

### Mises à jour

Pour publier une mise à jour :

1. Incrémenter la version dans `pubspec.yaml` :
```yaml
version: 1.1.0+2  # version+buildNumber
```

2. Build la nouvelle version
3. Aller dans "Production" > "Créer une version"
4. Uploader le nouveau AAB
5. Ajouter les notes de version
6. Soumettre

### Statistiques

Suivre les statistiques dans Play Console :
- Installations
- Désinstallations
- Notes et avis
- Crashs et ANR

## Checklist finale

- [ ] Compte développeur créé et payé
- [ ] Keystore généré et sauvegardé
- [ ] App Bundle signé généré
- [ ] Icône 512x512 créée
- [ ] Bannière 1024x500 créée
- [ ] Captures d'écran prises (minimum 2)
- [ ] Description rédigée
- [ ] Politique de confidentialité publiée
- [ ] Classification du contenu complétée
- [ ] Public cible défini
- [ ] Tarification configurée
- [ ] App Bundle uploadé
- [ ] Notes de version rédigées
- [ ] Version soumise pour examen

## Validation par Google Play

### Chances de validation

Votre app a de **bonnes chances d'être validée** si vous respectez les points suivants :

### ✅ Points positifs

- App fonctionnelle avec un objectif clair
- Permissions minimales (seulement INTERNET)
- Interface propre et professionnelle
- Pas de contenu illégal
- Open Source (transparence)

### ⚠️ Éléments OBLIGATOIRES

#### 1. Politique de confidentialité

**OBLIGATOIRE** : Vous devez avoir une URL publique avec votre politique de confidentialité.

**URL de la politique créée :** https://jointomilitant.org/privacy-app.html

Cette politique est disponible en 3 langues :
- Français : https://jointomilitant.org/privacy-app.html
- English : https://jointomilitant.org/en/privacy-app.html
- Español : https://jointomilitant.org/es/privacy-app.html

Exemple de contenu minimal :

**✅ DÉJÀ CRÉÉ** : Les fichiers de politique de confidentialité sont disponibles dans `jointomilitant/privacy-app.html`

URL à utiliser dans Play Console : **https://jointomilitant.org/privacy-app.html**

```
POLITIQUE DE CONFIDENTIALITÉ - MILITANT

Dernière mise à jour : [DATE]

1. COLLECTE DE DONNÉES
L'application Militant ne collecte aucune donnée personnelle directement.
L'app est un client qui se connecte à des instances Militant auto-hébergées.

2. DONNÉES TRAITÉES PAR LES INSTANCES
Les données que vous partagez (posts, messages, profil) sont stockées
sur l'instance Militant que vous choisissez. Consultez la politique de
confidentialité de votre instance.

3. PERMISSIONS
- INTERNET : Nécessaire pour se connecter aux instances Militant

4. PARTAGE DE DONNÉES
Nous ne partagons aucune donnée avec des tiers.

5. CONTACT
[Votre email]
```

**Note :** Cette politique a déjà été créée pour vous dans les fichiers :
- `jointomilitant/privacy-app.html` (Français)
- `jointomilitant/en/privacy-app.html` (English)
- `jointomilitant/es/privacy-app.html` (Español)

Hébergez cette page sur :
- Votre site web
- GitHub Pages
- GitLab Pages (recommandé)

#### 2. Modération du contenu

Dans le questionnaire "Classification du contenu", vous devrez indiquer :

**Contenu généré par les utilisateurs** : OUI
- L'app affiche du contenu créé par les utilisateurs

**Modération** : OUI
- Chaque instance Militant a ses propres modérateurs
- Les utilisateurs peuvent signaler du contenu
- Les administrateurs d'instance peuvent bannir des utilisateurs

**Dans la description de l'app, ajoutez** :
```
MODÉRATION
Chaque instance Militant dispose de ses propres modérateurs et règles.
Les utilisateurs peuvent signaler du contenu inapproprié directement
sur l'instance. Les administrateurs peuvent supprimer du contenu et
bannir des utilisateurs qui ne respectent pas les règles.
```

#### 3. Public cible

- **Âge minimum** : 16 ans et plus (recommandé pour réseau social)
- **Intérêt des enfants** : NON
- **Contenu mature** : Peut contenir du contenu politique/militant

### 🚫 Risques de rejet

Votre app pourrait être rejetée si :

1. **Pas de politique de confidentialité** → AJOUTER OBLIGATOIREMENT
2. **Contenu illégal affiché** → Assurez-vous que l'instance par défaut est bien modérée
3. **Permissions excessives** → OK, vous n'avez que INTERNET
4. **App qui crash** → Testez bien avant soumission
5. **Contenu trompeur** → Soyez honnête dans la description

### 📋 Checklist avant soumission

- [ ] Politique de confidentialité publiée et URL ajoutée
- [ ] Description mentionne la modération
- [ ] App testée sans crash
- [ ] Instance par défaut bien modérée
- [ ] Captures d'écran ne montrent pas de contenu inapproprié
- [ ] Description claire et honnête
- [ ] Icône et bannière professionnelles
- [ ] Classification du contenu complétée correctement

### ⏱️ Délai de validation

- **Première soumission** : 1 à 7 jours (généralement 2-3 jours)
- **Mises à jour** : 1 à 3 jours

### 🔄 Si rejet

Si votre app est rejetée :

1. Lire attentivement le motif de rejet
2. Corriger le problème
3. Resoumettre (pas de limite de tentatives)
4. Répondre aux questions de Google si nécessaire

Les rejets les plus courants :
- Politique de confidentialité manquante
- Contenu inapproprié dans les captures d'écran
- Description trompeuse
- App qui crash au lancement

## Créer une politique de confidentialité

### Option 1 : GitLab Pages (recommandé)

Créez `privacy.html` dans votre repo :

```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Politique de Confidentialité - Militant</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #BE1E1E; }
        h2 { color: #333; margin-top: 30px; }
    </style>
</head>
<body>
    <h1>Politique de Confidentialité - Militant</h1>
    <p><strong>Dernière mise à jour :</strong> [DATE]</p>
    
    <h2>1. Collecte de données</h2>
    <p>L'application Militant ne collecte aucune donnée personnelle directement. L'application est un client qui se connecte à des instances Militant auto-hébergées.</p>
    
    <h2>2. Données traitées par les instances</h2>
    <p>Les données que vous partagez (publications, messages, profil) sont stockées sur l'instance Militant que vous choisissez. Consultez la politique de confidentialité de votre instance.</p>
    
    <h2>3. Permissions</h2>
    <ul>
        <li><strong>INTERNET</strong> : Nécessaire pour se connecter aux instances Militant</li>
    </ul>
    
    <h2>4. Partage de données</h2>
    <p>Nous ne partageons aucune donnée avec des tiers. L'application ne contient ni publicité ni trackers.</p>
    
    <h2>5. Sécurité</h2>
    <p>Les connexions aux instances Militant utilisent HTTPS pour sécuriser les communications.</p>
    
    <h2>6. Vos droits</h2>
    <p>Pour exercer vos droits (accès, modification, suppression de vos données), contactez l'administrateur de votre instance Militant.</p>
    
    <h2>7. Contact</h2>
    <p>Pour toute question concernant cette politique : [VOTRE EMAIL]</p>
</body>
</html>
```

Activez GitLab Pages dans votre projet, l'URL sera :
`https://votre-username.gitlab.io/militant-flutter/privacy.html`

### Option 2 : Utiliser un générateur

- https://www.privacypolicygenerator.info/
- https://app-privacy-policy-generator.firebaseapp.com/

## Ressources

- [Documentation Play Console](https://support.google.com/googleplay/android-developer)
- [Guide Flutter](https://docs.flutter.dev/deployment/android)
- [Checklist de lancement](https://developer.android.com/distribute/best-practices/launch/launch-checklist)
- [Politique de contenu Google Play](https://support.google.com/googleplay/android-developer/answer/9876937)

## Support

Pour toute question sur la publication, ouvrir une issue sur GitLab.
