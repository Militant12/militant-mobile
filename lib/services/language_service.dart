import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ValueNotifier<Locale> {
  static final LanguageService instance = LanguageService._();

  LanguageService._() : super(const Locale('fr'));

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language') ?? 'fr';
    value = Locale(langCode);
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    value = Locale(langCode);
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // General
      'app_title': 'Militant',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'error': 'Erreur',
      'loading': 'Chargement...',
      'success': 'Succès',
      'confirm': 'Confirmer',
      'delete': 'Supprimer',
      'report': 'Signaler',
      'share': 'Partager',
      'edit': 'Modifier',
      'close': 'Fermer',

      // Auth
      'login_title': 'Connexion',
      'email_label': 'Email',
      'password_label': 'Mot de passe',
      'login_button': 'Se connecter',
      'register_link': 'Pas encore de compte ? S\'inscrire',
      'register_title': 'Inscription',
      'create_account': 'Créer un compte',
      'join_community': 'Rejoignez la communauté militante',
      'username_label': 'Nom d\'utilisateur',
      'register_button': 'S\'inscrire',
      'login_link': 'Déjà un compte ? Se connecter',
      'password_required': 'Mot de passe requis',
      'email_required': 'Email requis',
      'confirm_password': 'Confirmer le mot de passe',
      'your_main_cause': 'Ta cause principale',
      'choose_cause': 'Choisir une cause',

      // Home & Navigation
      'home_title': 'Accueil',
      'messages_title': 'Messages',
      'profile_title': 'Mon Profil',
      'settings_title': 'Paramètres',
      'groups_title': 'Groupes',
      'events_title': 'Événements',
      'notifications_title': 'Notifications',
      'search_hint': 'Rechercher...',

      // Posts
      'create_post_title': 'Nouveau post',
      'create_post_hint': 'Quoi de neuf ?',
      'publish_button': 'Publier',
      'post_detail_title': 'Post',
      'comments_title': 'Commentaires',
      'comment_hint': 'Ajouter un commentaire...',
      'like_action': 'J\'aime',
      'comment_action': 'Commenter',
      'share_action': 'Partager',
      'delete_post_confirm': 'Voulez-vous vraiment supprimer ce post ?',
      'report_post_title': 'Signaler le post',
      'report_reason_hint': 'Raison du signalement',
      'report_submit': 'Envoyer',

      // Profile
      'edit_profile_title': 'Modifier le profil',
      'saved_posts_title': 'Posts sauvegardés',
      'posts': 'Posts',
      'media': 'Médias',
      'followers': 'Abonnés',
      'following': 'Abonnements',
      'no_posts': 'Aucun post',
      'no_media': 'Aucun média',
      'logout': 'Déconnexion',

      // Settings
      'security_title': 'Sécurité',
      'privacy_title': 'Confidentialité',
      'language_title': 'Langue',
      'theme_title': 'Thème',
      'about_title': 'À propos',
      'theme_dark': 'Sombre',
      'theme_light': 'Clair',
      'choose_language': 'Choisir la langue',
      'choose_theme': 'Choisir le thème',
      'subtitle_notifications': 'Gérer les notifications',
      'subtitle_security': 'Changer de mot de passe',
      'subtitle_privacy': 'Paramètres de confidentialité',
      'version': 'Version 1.0.0',

      // Notifications Settings
      'notifications_push': 'Notifications push',
      'notifications_push_subtitle': 'Sur cet appareil',
      'notifications_email': 'E-mails',
      'notifications_email_subtitle': 'Recevoir des résumés par mail',
      'notifications_likes': 'J\'aime',
      'notifications_likes_subtitle': 'Quand quelqu\'un aime vos posts',
      'notifications_comments': 'Commentaires',
      'notifications_comments_subtitle': 'Quand quelqu\'un commente',
      'notifications_follows': 'Abonnements',
      'notifications_follows_subtitle': 'Nouveaux abonnés',
      'notifications_mentions': 'Mentions',
      'notifications_mentions_subtitle': 'Quand on vous mentionne',
      'notifications_channels_title': 'CANAUX',
      'notifications_interactions_title': 'INTERACTIONS',

      // Privacy Settings
      'privacy_private_account': 'Compte privé',
      'privacy_private_subtitle':
          'Seuls vos abonnés peuvent voir vos posts et médias',
      'privacy_allow_messages': 'Messages privés',
      'privacy_allow_messages_subtitle':
          'Autoriser tout le monde à vous envoyer des messages',
      'privacy_online_status': 'Statut en ligne',
      'privacy_online_subtitle': 'Afficher quand vous êtes actif',
      'privacy_read_receipts': 'Confirmations de lecture',
      'privacy_read_receipts_subtitle': 'Voir quand vos messages sont lus',

      // Change Password
      'change_password_title': 'Changer de mot de passe',
      'current_password': 'Mot de passe actuel',
      'new_password': 'Nouveau mot de passe',
      'confirm_password': 'Confirmer le mot de passe',
      'password_match_error': 'Les mots de passe ne correspondent pas',
      'password_min_length': 'Minimum 8 caractères',
      'update_button': 'Mettre à jour',
      'password_updated': 'Mot de passe modifié avec succès',

      // Chat
      'message_hint': 'Message...',
      'online': 'En ligne',
      'private_account_title': 'Ce compte est privé',
      'private_account_subtitle': 'Abonnez-vous pour voir ses publications.',
      'follow': 'Suivre',
      'following_status': 'Suivi',

      // Stories
      'stories_add': 'Ajouter',
      'stories_created': 'Story créée',
      'stories_error': 'Erreur',

      // Badge Selection
      'my_militant_badge': 'Mon badge militant',
      'no_badge': 'Aucun badge',
      'select_badge_text': 'Choisir votre affiliation politique',
      'export_data_title': 'Exporter mes données',
      'export_data_subtitle': 'Télécharger une copie de vos données (JSON)',
    },
    'en': {
      // General
      'app_title': 'Militant',
      'cancel': 'Cancel',
      'save': 'Save',
      'error': 'Error',
      'loading': 'Loading...',
      'success': 'Success',
      'confirm': 'Confirm',
      'delete': 'Delete',
      'report': 'Report',
      'share': 'Share',
      'edit': 'Edit',
      'close': 'Close',

      // Auth
      'login_title': 'Login',
      'email_label': 'Email',
      'password_label': 'Password',
      'login_button': 'Login',
      'register_link': 'No account? Register',
      'register_title': 'Register',
      'create_account': 'Create an account',
      'join_community': 'Join the militant community',
      'username_label': 'Username',
      'register_button': 'Register',
      'login_link': 'Already have an account? Login',
      'password_required': 'Password required',
      'email_required': 'Email required',
      'confirm_password': 'Confirm password',
      'your_main_cause': 'Your main cause',
      'choose_cause': 'Choose a cause',

      // Home & Navigation
      'home_title': 'Home',
      'messages_title': 'Messages',
      'profile_title': 'My Profile',
      'settings_title': 'Settings',
      'groups_title': 'Groups',
      'events_title': 'Events',
      'notifications_title': 'Notifications',
      'search_hint': 'Search...',

      // Posts
      'create_post_title': 'New Post',
      'create_post_hint': 'What\'s on your mind?',
      'publish_button': 'Publish',
      'post_detail_title': 'Post',
      'comments_title': 'Comments',
      'comment_hint': 'Add a comment...',
      'like_action': 'Like',
      'comment_action': 'Comment',
      'share_action': 'Share',
      'delete_post_confirm': 'Do you really want to delete this post?',
      'report_post_title': 'Report Post',
      'report_reason_hint': 'Reason for reporting',
      'report_submit': 'Submit',

      // Profile
      'edit_profile_title': 'Edit Profile',
      'saved_posts_title': 'Saved Posts',
      'posts': 'Posts',
      'media': 'Media',
      'followers': 'Followers',
      'following': 'Following',
      'no_posts': 'No posts',
      'no_media': 'No media',
      'logout': 'Logout',

      // Settings
      'security_title': 'Security',
      'privacy_title': 'Privacy',
      'language_title': 'Language',
      'theme_title': 'Theme',
      'about_title': 'About',
      'theme_dark': 'Dark',
      'theme_light': 'Light',
      'choose_language': 'Choose language',
      'choose_theme': 'Choose theme',
      'subtitle_notifications': 'Manage notifications',
      'subtitle_security': 'Change password',
      'subtitle_privacy': 'Privacy settings',
      'version': 'Version 1.0.0',

      // Notifications Settings
      'notifications_push': 'Push notifications',
      'notifications_push_subtitle': 'On this device',
      'notifications_email': 'Emails',
      'notifications_email_subtitle': 'Receive email summaries',
      'notifications_likes': 'Likes',
      'notifications_likes_subtitle': 'When someone likes your posts',
      'notifications_comments': 'Comments',
      'notifications_comments_subtitle': 'When someone comments',
      'notifications_follows': 'Follows',
      'notifications_follows_subtitle': 'New followers',
      'notifications_mentions': 'Mentions',
      'notifications_mentions_subtitle': 'When you are mentioned',
      'notifications_channels_title': 'CHANNELS',
      'notifications_interactions_title': 'INTERACTIONS',

      // Privacy Settings
      'privacy_private_account': 'Private account',
      'privacy_private_subtitle': 'Only followers can see your posts and media',
      'privacy_allow_messages': 'Direct messages',
      'privacy_allow_messages_subtitle': 'Allow everyone to send you messages',
      'privacy_online_status': 'Online status',
      'privacy_online_subtitle': 'Show when you are active',
      'privacy_read_receipts': 'Read receipts',
      'privacy_read_receipts_subtitle': 'See when messages are read',

      // Change Password
      'change_password_title': 'Change password',
      'current_password': 'Current password',
      'new_password': 'New password',
      'confirm_password': 'Confirm password',
      'password_match_error': 'Passwords do not match',
      'password_min_length': 'Minimum 8 characters',
      'update_button': 'Update',
      'password_updated': 'Password updated successfully',

      // Chat
      'message_hint': 'Message...',
      'online': 'Online',
      'private_account_title': 'This account is private',
      'private_account_subtitle': 'Follow this account to see their posts.',
      'follow': 'Follow',
      'following_status': 'Following',

      // Stories
      'stories_add': 'Add',
      'stories_created': 'Story created',
      'stories_error': 'Error',

      // Badge Selection
      'my_militant_badge': 'My militant badge',
      'no_badge': 'No badge',
      'select_badge_text': 'Choose your political affiliation',
      'export_data_title': 'Export my data',
      'export_data_subtitle': 'Download a copy of your data (JSON)',
    },
    'es': {
      // General
      'app_title': 'Militante',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'error': 'Error',
      'loading': 'Cargando...',
      'success': 'Éxito',
      'confirm': 'Confirmar',
      'delete': 'Eliminar',
      'report': 'Reportar',
      'share': 'Compartir',
      'edit': 'Editar',
      'close': 'Cerrar',

      // Auth
      'login_title': 'Iniciar sesión',
      'email_label': 'Correo electrónico',
      'password_label': 'Contraseña',
      'login_button': 'Iniciar sesión',
      'register_link': '¿No tienes cuenta? Regístrate',
      'register_title': 'Registro',
      'create_account': 'Crear una cuenta',
      'join_community': 'Únete a la comunidad militante',
      'username_label': 'Nombre de usuario',
      'register_button': 'Registrarse',
      'login_link': '¿Ya tienes cuenta? Inicia sesión',
      'password_required': 'Contraseña requerida',
      'email_required': 'Correo requerido',
      'confirm_password': 'Confirmar contraseña',
      'your_main_cause': 'Tu causa principal',
      'choose_cause': 'Elegir una causa',

      // Home & Navigation
      'home_title': 'Inicio',
      'messages_title': 'Mensajes',
      'profile_title': 'Mi Perfil',
      'settings_title': 'Ajustes',
      'groups_title': 'Grupos',
      'events_title': 'Eventos',
      'notifications_title': 'Notificaciones',
      'search_hint': 'Buscar...',

      // Posts
      'create_post_title': 'Nueva publicación',
      'create_post_hint': '¿Qué estás pensando?',
      'publish_button': 'Publicar',
      'post_detail_title': 'Publicación',
      'comments_title': 'Comentarios',
      'comment_hint': 'Añadir un comentario...',
      'like_action': 'Me gusta',
      'comment_action': 'Comentar',
      'share_action': 'Compartir',
      'delete_post_confirm': '¿Realmente quieres eliminar esta publicación?',
      'report_post_title': 'Reportar publicación',
      'report_reason_hint': 'Razón del reporte',
      'report_submit': 'Enviar',

      // Profile
      'edit_profile_title': 'Editar perfil',
      'saved_posts_title': 'Publicaciones guardadas',
      'posts': 'Publicaciones',
      'media': 'Multimedia',
      'followers': 'Seguidores',
      'following': 'Siguiendo',
      'no_posts': 'No hay publicaciones',
      'no_media': 'No hay multimedia',
      'logout': 'Cerrar sesión',

      // Settings
      'security_title': 'Seguridad',
      'privacy_title': 'Privacidad',
      'language_title': 'Idioma',
      'theme_title': 'Tema',
      'about_title': 'Acerca de',
      'theme_dark': 'Oscuro',
      'theme_light': 'Claro',
      'choose_language': 'Elegir idioma',
      'choose_theme': 'Elegir tema',
      'subtitle_notifications': 'Gestionar notificaciones',
      'subtitle_security': 'Cambiar contraseña',
      'subtitle_privacy': 'Configuración de privacidad',
      'version': 'Versión 1.0.0',

      // Notifications Settings
      'notifications_push': 'Notificaciones push',
      'notifications_push_subtitle': 'En este dispositivo',
      'notifications_email': 'Correos electrónicos',
      'notifications_email_subtitle': 'Recibir resúmenes por correo',
      'notifications_likes': 'Me gusta',
      'notifications_likes_subtitle':
          'Cuando a alguien le gusta tu publicación',
      'notifications_comments': 'Comentarios',
      'notifications_comments_subtitle': 'Cuando alguien comenta',
      'notifications_follows': 'Seguidores',
      'notifications_follows_subtitle': 'Nuevos seguidores',
      'notifications_mentions': 'Menciones',
      'notifications_mentions_subtitle': 'Cuando te mencionan',
      'notifications_channels_title': 'CANALES',
      'notifications_interactions_title': 'INTERACCIONES',

      // Privacy Settings
      'privacy_private_account': 'Cuenta privada',
      'privacy_private_subtitle':
          'Solo los seguidores pueden ver tus publicaciones',
      'privacy_allow_messages': 'Mensajes directos',
      'privacy_allow_messages_subtitle':
          'Permitir que todos te envíen mensajes',
      'privacy_online_status': 'Estado en línea',
      'privacy_online_subtitle': 'Mostrar cuando estás activo',
      'privacy_read_receipts': 'Confirmaciones de lectura',
      'privacy_read_receipts_subtitle': 'Ver cuando se leen los mensajes',

      // Change Password
      'change_password_title': 'Cambiar contraseña',
      'current_password': 'Contraseña actual',
      'new_password': 'Nueva contraseña',
      'confirm_password': 'Confirmar contraseña',
      'password_match_error': 'Las contraseñas no coinciden',
      'password_min_length': 'Mínimo 8 caracteres',
      'update_button': 'Actualizar',
      'password_updated': 'Contraseña actualizada con éxito',

      // Chat
      'message_hint': 'Mensaje...',
      'online': 'En línea',
      'private_account_title': 'Esta cuenta es privada',
      'private_account_subtitle':
          'Sigue a esta cuenta para ver sus publicaciones.',
      'follow': 'Seguir',
      'following_status': 'Siguiendo',

      // Stories
      'stories_add': 'Añadir',
      'stories_created': 'Historia creada',
      'stories_error': 'Error',

      // Badge Selection
      'my_militant_badge': 'Mi insignia militante',
      'no_badge': 'Sin insignia',
      'select_badge_text': 'Elige tu afiliación política',
      'export_data_title': 'Exportar mis datos',
      'export_data_subtitle': 'Descargar una copia de tus datos (JSON)',
    },
  };

  String translate(String key) {
    final langCode = value.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['fr']![key] ??
        key;
  }
}
