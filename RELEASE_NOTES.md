# Release Notes - Militant (v1.0.6)

## Lives (v1.0.6)
- **Modération complète** : Nomination de modérateurs révocables sans hiérarchie et blocage d’utilisateurs (consensus communautaire).
- **Gestion des invités** : Système robuste de demande (*Request Guest*), avec approbation et rejet en temps réel.
- **Sécurité & Identité** : Utilisation d’identifiants persistants (`u{id}`) pour une modération efficace, même après changement de pseudo.
- **Signalement** : Ajout d’une option pour signaler les lives inappropriés.
- **Auto-nettoyage** : Fermeture automatique des sessions inactives ou dont le créateur est déconnecté (timeout de 2 minutes).
- **Refonte de l’interface** : Nouvelle ergonomie avec onglets Découvrir / Créer et interface de chat optimisée.

## Groupes
- Correction du bug des demandes d’adhésion privées qui disparaissaient après traitement d’une ancienne demande.
- Réouverture automatique d’une demande lorsque l’utilisateur redemande à rejoindre un groupe privé.
- Vérification empêchant une nouvelle demande si l’utilisateur est déjà membre.
- Ajout des invitations aux groupes.

## Notifications
- Correction du clic sur les notifications d’invitation à un groupe.
- Ajout d’un modal d’invitation avec action **Accepter**.
- Après acceptation, ouverture directe de la page du groupe.

## Posts
- Correction des liens dans les cards embed.

## Vidéos
- Prévisualisation lors de l’upload (posts et stories).
- Optimisation de l’upload et meilleure gestion du format pour vidéos (support FFmpeg sur l'API).
