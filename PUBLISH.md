# Publication sur GitLab

## Étapes pour publier le projet

### 1. Créer un projet sur GitLab

1. Aller sur https://gitlab.com
2. Cliquer sur "New project"
3. Choisir "Create blank project"
4. Nom du projet : `militant-flutter`
5. Visibilité : Public ou Private selon vos besoins
6. Décocher "Initialize repository with a README"
7. Cliquer sur "Create project"

### 2. Configurer le remote Git

```bash
# Ajouter le remote GitLab (remplacer USERNAME par votre nom d'utilisateur)
git remote add origin https://gitlab.com/USERNAME/militant-flutter.git

# Ou avec SSH
git remote add origin git@gitlab.com:USERNAME/militant-flutter.git
```

### 3. Pousser le code

```bash
# Renommer la branche en main
git branch -M main

# Pousser le code
git push -u origin main
```

### 4. Créer un tag pour la release

```bash
# Créer un tag v1.0.0
git tag -a v1.0.0 -m "Release v1.0.0 - Application mobile Militant"

# Pousser le tag
git push origin v1.0.0
```

## Configuration GitLab CI/CD

Le fichier `.gitlab-ci.yml` est déjà configuré. La CI/CD se lancera automatiquement à chaque push.

### Variables à configurer dans GitLab

Aller dans Settings > CI/CD > Variables et ajouter :

- `ANDROID_KEYSTORE` : Keystore pour signer l'APK (base64)
- `ANDROID_KEY_ALIAS` : Alias de la clé
- `ANDROID_KEY_PASSWORD` : Mot de passe de la clé
- `ANDROID_STORE_PASSWORD` : Mot de passe du keystore

## Releases

Les releases sont créées automatiquement pour chaque tag. Les artifacts (APK, AAB) sont disponibles dans la section "Releases" du projet GitLab.

## Mise à jour

Pour publier une nouvelle version :

```bash
# Faire les modifications
git add .
git commit -m "Description des changements"

# Mettre à jour le CHANGELOG.md

# Créer un nouveau tag
git tag -a v1.1.0 -m "Release v1.1.0"

# Pousser
git push origin main
git push origin v1.1.0
```
