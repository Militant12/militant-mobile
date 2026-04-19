# Release Notes - Militant (v1.0.6)

## Fediverse
- **Arrivée du Fediverse sur mobile** : nouvel espace dédié avec onglets **Flux**, **Profils**, **Abonnements** et **Abonnés**.
- **Recherche fédérée** : recherche de profils et d’adresses Fediverse, ouverture des profils distants et affichage des posts récents.
- **Abonnements distants** : abonnement et désabonnement à des comptes Fediverse/Mastodon distants depuis l’application.
- **Flux Fediverse** : affichage des contenus des comptes distants suivis, avec chargement optimisé pour éviter les blocages inutiles.
- **Identité locale Fediverse** : affichage de l’identité Fediverse locale de l’utilisateur et meilleure distinction entre comptes locaux et comptes fédérés.
- **Interface améliorée** : meilleure prise en charge du mode clair sur les écrans Fediverse.

## Corrections Fediverse
- Correction d’un bug où l’état **Suivre / Suivi** revenait à tort après navigation dans les listes Fediverse.
- Correction de l’affichage des abonnés Fediverse pour conserver le bon état de suivi après rechargement.
- Correction de l’affichage des avatars Fediverse dans **Abonnés** sans devoir ouvrir le profil.
- Correction de plusieurs problèmes API SQL liés à la pagination Fediverse sur MariaDB.
- Correction d’un conflit de collation SQL qui empêchait le chargement de certaines listes Fediverse.
- Ajustement du rate limit Fediverse par action pour éviter les erreurs **Rate limit exceeded** en usage classique.
- Meilleure tolérance aux délais de réponse longs pour éviter les erreurs bloquantes sur le flux.

## Pages et Commentaires
- **Commentaires de page** : correction de la modification et suppression des commentaires de page dans l’app mobile.
- **Droits d’administration** : l’auteur du commentaire peut modifier/supprimer, et l’admin de page ou l’auteur du post peut supprimer les commentaires concernés.
- **Réponse rapide** : ajout d’une action **Répondre** avec préremplissage automatique en `@username`.
- **Mentions** : ajout des notifications de mention sur les commentaires de page quand un utilisateur est cité.
- **Réactions emoji** : ajout des réactions emoji sur les commentaires de page.

## Correctifs complémentaires
- Correction de l’ouverture des liens embed dans les posts.
- Correction d’un bug sur certains aperçus de liens où l’icône distante pouvait être mal reconstruite.
- Amélioration de la cohérence entre l’app mobile et l’API sur plusieurs actions sociales récentes.

## Profils et Badges
- **Badge technicien** : ajout d’un badge technicien visible dans les profils, posts, commentaires, résultats de recherche et listes d’utilisateurs.
- **Badges enrichis** : meilleure prise en charge des badges militants et techniciens dans les modèles de données utilisateur, post et commentaire.
- **Lisibilité UI** : amélioration de l’affichage des noms et badges avec gestion des débordements dans plusieurs listes et écrans.

## Lives (v1.0.6)
- **Modération complète** : Nomination de modérateurs révocables sans hiérarchie et blocage d’utilisateurs (consensus communautaire).
- **Gestion des invités** : Système robuste de demande (*Request Guest*), avec approbation et rejet en temps réel.
- **Sécurité & Identité** : Utilisation d’identifiants persistants (`u{id}`) pour une modération efficace, même après changement de pseudo.
- **Signalement** : Ajout d’une option pour signaler les lives inappropriés.
- **Auto-nettoyage** : Fermeture automatique des sessions inactives ou dont le créateur est déconnecté (timeout de 2 minutes).
- **Refonte de l’interface** : Nouvelle ergonomie avec onglets Découvrir / Créer et interface de chat optimisée.
- **Invités plus robustes** : meilleure gestion des demandes d’invitation, de leur acceptation/rejet et de la promotion automatique en speaker.
- **Identités stables** : amélioration de la reconnexion et de la modération grâce à des identités utilisateur plus cohérentes.

## Android
- **Trusted Web Activity** : ajout d’une activité TWA dédiée pour améliorer l’intégration Android.
- **Android 15 / Edge-to-Edge** : adaptation de l’app et de la TWA pour une meilleure compatibilité avec les exigences d’affichage récentes.

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
