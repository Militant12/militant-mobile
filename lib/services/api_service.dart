import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class ApiService {
  String baseUrl;
  String? token;

  ApiService({required this.baseUrl, this.token});

  // Singleton pattern pour accès global
  static ApiService? _instance;

  static Future<ApiService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      // Par défaut, utiliser l'API sur le sous-domaine api.
      final url =
          prefs.getString('server_url') ??
          'https://api.militant.revlibertaire.com';
      final token = prefs.getString('api_token');

      _instance = ApiService(baseUrl: url, token: token);
    }
    return _instance!;
  }

  // Headers avec authentification
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // Obtenir l'URL de l'API
  String get apiUrl {
    // Si l'URL contient déjà 'api.' (sous-domaine), l'utiliser directement
    if (baseUrl.contains('api.')) {
      return baseUrl;
    }
    // Sinon, ajouter /api au chemin
    if (baseUrl.contains('/api')) {
      return baseUrl;
    }
    return '$baseUrl/api';
  }

  // === DYNAMIC CONFIGURATION ===

  /// Récupère la configuration publique du serveur (comme l'App ID OneSignal)
  Future<Map<String, dynamic>> getServerSettings() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/v1/settings.php'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Erreur lors de la récupération des paramètres serveur: $e');
    }
    return {};
  }

  /// Initialise OneSignal dynamiquement avec l'App ID du serveur
  Future<void> initializeOneSignal() async {
    // Only on supported platforms
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final settings = await getServerSettings();
    final appId = settings['onesignal_app_id'];

    if (appId != null && appId.isNotEmpty) {
      print('Initialisation de OneSignal avec App ID: $appId');
      try {
        OneSignal.initialize(appId);
        OneSignal.Notifications.requestPermission(true);
      } catch (e) {
        print('Erreur d\'initialisation OneSignal: $e');
      }
    }
  }

  // Helper pour les URLs d'images et médias
  String? getImageUrl(String? path) {
    if (path == null || path.isEmpty || path == 'default.svg') return null;
    if (path.startsWith('http')) return path;

    // Nettoyer le chemin (enlever les espaces et slashes au début)
    path = path.trim();
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Construire l'URL complète
    // Les images sont sur le serveur principal, pas sur api.
    String mainUrl = baseUrl;
    if (baseUrl.contains('api.')) {
      // Remplacer api. par rien pour avoir le domaine principal
      mainUrl = baseUrl.replaceFirst('api.', '');
    } else if (baseUrl.contains('/api')) {
      mainUrl = baseUrl.replaceAll('/api', '');
    }

    // Sécurité: si mainUrl est vide ou invalide, utiliser le domaine par défaut
    if (mainUrl.isEmpty || !mainUrl.startsWith('http')) {
      mainUrl = 'https://militant.revlibertaire.com';
    }

    // Enlever le slash final de mainUrl s'il y en a un
    if (mainUrl.endsWith('/')) {
      mainUrl = mainUrl.substring(0, mainUrl.length - 1);
    }

    // Si le chemin ne contient pas de slash, c'est juste un nom de fichier
    // Il faut ajouter le dossier uploads/posts/
    if (!path.contains('/')) {
      if (path.startsWith('media_')) {
        path = 'uploads/posts/$path';
      } else if (path.startsWith('avatar_')) {
        path = 'uploads/$path';
      } else if (path.startsWith('story_')) {
        path = 'uploads/stories/$path';
      } else if (path.startsWith('album_')) {
        path = 'uploads/albums/$path';
      } else {
        path = 'uploads/$path';
      }
    }

    return '$mainUrl/$path';
  }

  // Sauvegarder le token
  Future<void> saveToken(String newToken) async {
    token = newToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', newToken);
  }

  // Supprimer le token (logout)
  Future<void> clearToken() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
  }

  // === AUTHENTIFICATION ===

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/v1/auth.php?action=login'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}),
      );

      // Debug: afficher la réponse brute
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['token'] != null) {
            await saveToken(data['token']);
          }
          return data;
        } catch (e) {
          // Si le JSON est invalide, afficher le contenu HTML
          throw Exception(
            'Réponse invalide du serveur (HTML au lieu de JSON). Première ligne: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé. Vérifiez l\'URL du serveur.');
      } else {
        try {
          final data = jsonDecode(response.body);
          throw Exception(
            data['message'] ?? 'Erreur de connexion: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'Erreur ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception(
          'Impossible de se connecter au serveur. Vérifiez votre connexion internet et l\'URL du serveur.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/auth.php?action=register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'inscription: ${response.statusCode}');
    }
  }

  // === POSTS ===

  Future<List<dynamic>> getPosts({int page = 1, int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/posts.php?page=$page&limit=$limit'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Gérer différents formats de réponse
      if (data['success'] == true) {
        // Format avec success
        if (data['data'] != null) {
          // Format paginé: {success: true, data: {posts: [...], meta: {...}}}
          if (data['data']['posts'] != null) {
            return data['data']['posts'];
          }
          // Format simple: {success: true, data: [...]}
          if (data['data'] is List) {
            return data['data'];
          }
        }
        // Format direct: {success: true, posts: [...]}
        if (data['posts'] != null) {
          return data['posts'];
        }
      }

      // Format sans success: {posts: [...]}
      if (data['posts'] != null) {
        return data['posts'];
      }

      // Format tableau direct: [...]
      if (data is List) {
        return data;
      }

      return [];
    } else {
      throw Exception('Erreur de chargement des posts: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getUserPosts(int userId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/posts.php?user_id=$userId&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data']['posts'] != null) {
          return data['data']['posts'];
        }
      }
      return data['posts'] ?? [];
    } else {
      throw Exception('Erreur de chargement des posts');
    }
  }

  Future<Map<String, dynamic>> createPost(
    String content, {
    List<String>? mediaUrls,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/posts.php'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'media': mediaUrls,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de création du post: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> likePost(
    int postId, {
    String type = 'like',
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/reactions.php'),
      headers: _headers,
      body: jsonEncode({'post_id': postId, 'reaction_type': type}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de réaction: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> unlikePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/reactions.php?post_id=$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de suppression de réaction');
    }
  }

  Future<Map<String, dynamic>> sharePost(int postId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/shares.php'),
      headers: _headers,
      body: jsonEncode({'post_id': postId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de partage');
    }
  }

  Future<Map<String, dynamic>> bookmarkPost(int postId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/bookmarks.php'),
      headers: _headers,
      body: jsonEncode({'post_id': postId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de sauvegarde');
    }
  }

  Future<Map<String, dynamic>> deletePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/posts.php?id=$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de suppression du post');
    }
  }

  Future<Map<String, dynamic>> translateText(
    String text, {
    String? targetLang,
  }) async {
    // Utiliser l'endpoint principal (pas l'API v1)
    final mainUrl = baseUrl.replaceFirst('api.', '');

    final response = await http.post(
      Uri.parse('$mainUrl/ajax/translate.php'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: {'text': text, if (targetLang != null) 'target_lang': targetLang},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de traduction');
    }
  }

  // === COMMENTAIRES ===

  Future<List<dynamic>> getComments(int postId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/comments.php?post_id=$postId&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ??
          []; // paginate() returns 'data' by default if not specified
    } else {
      throw Exception('Erreur de chargement des commentaires');
    }
  }

  Future<Map<String, dynamic>> addComment(int postId, String content) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/comments.php'),
      headers: _headers,
      body: jsonEncode({'post_id': postId, 'content': content}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'ajout du commentaire');
    }
  }

  // === UTILISATEURS ===

  Future<Map<String, dynamic>> getProfile({int? userId}) async {
    final url = userId != null
        ? '$apiUrl/v1/users.php?id=$userId'
        : '$apiUrl/v1/users.php';

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de chargement du profil');
    }
  }

  Future<List<dynamic>> getFollows({
    int? userId,
    required String type,
    int page = 1,
  }) async {
    final url =
        '$apiUrl/v1/follows.php?user_id=${userId ?? ''}&type=$type&page=$page';
    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'] as List<dynamic>;
      }
      return [];
    } else {
      throw Exception('Erreur de chargement de la liste');
    }
  }

  Future<Map<String, dynamic>> followUser(int userId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/follows.php'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du suivi');
    }
  }

  Future<Map<String, dynamic>> unfollowUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/follows.php?user_id=$userId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du désabonnement');
    }
  }

  // === MESSAGES ===

  Future<List<dynamic>> getMessages({int? userId, int page = 1}) async {
    final url = userId != null
        ? '$apiUrl/v1/messages.php?user_id=$userId&page=$page'
        : '$apiUrl/v1/message_groups.php?page=$page';

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['messages'] ?? data['groups'] ?? [];
    } else {
      throw Exception('Erreur de chargement des messages');
    }
  }

  Future<Map<String, dynamic>> sendMessage(int userId, String content) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/messages.php'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'content': content}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'envoi du message: ${response.statusCode}');
    }
  }

  // === NOTIFICATIONS ===

  Future<List<dynamic>> getNotifications({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/notifications.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['notifications'] ?? [];
    } else {
      throw Exception('Erreur de chargement des notifications');
    }
  }

  // === GROUPES ===

  Future<List<dynamic>> getGroups({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/groups.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['groups'] ?? [];
    } else {
      throw Exception('Erreur de chargement des groupes');
    }
  }

  Future<List<dynamic>> getEvents({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/events.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['events'] ?? [];
    } else {
      throw Exception('Erreur de chargement des événements');
    }
  }

  // === MODÉRATION ===

  Future<List<dynamic>> getReports({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/reports.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['reports'] ?? [];
    } else {
      throw Exception('Erreur de chargement des signalements');
    }
  }

  Future<Map<String, dynamic>> voteOnReport(int reportId, String vote) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/reports.php'),
      headers: _headers,
      body: jsonEncode({
        'report_id': reportId,
        'vote': vote, // 'remove', 'warn', 'keep', 'cancel'
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de vote');
    }
  }

  Future<Map<String, dynamic>> reportContent({
    int? postId,
    int? userId,
    required String reason,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/reports.php'),
      headers: _headers,
      body: jsonEncode({
        if (postId != null) 'post_id': postId,
        if (userId != null) 'user_id': userId,
        'reason': reason,
        if (description != null) 'description': description,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de signalement');
    }
  }

  // Candidature modérateur
  Future<Map<String, dynamic>> applyForModerator(String motivation) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/moderators.php?action=apply'),
      headers: _headers,
      body: jsonEncode({'motivation': motivation}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de candidature');
    }
  }

  // Vote pour/contre un candidat ou modérateur
  Future<Map<String, dynamic>> voteForModerator(int userId, String vote) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/moderators.php?action=vote_moderator'),
      headers: _headers,
      body: jsonEncode({
        'candidate_id': userId,
        'vote': vote, // 'for' ou 'against'
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de vote');
    }
  }

  // Liste des candidats
  Future<List<dynamic>> getCandidates() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/moderators.php?action=candidates'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'] ?? [];
    } else {
      throw Exception('Erreur de chargement des candidats');
    }
  }

  // Liste des modérateurs
  Future<List<dynamic>> getModerators() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/moderators.php?action=list'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['moderators'] ?? [];
    } else {
      throw Exception('Erreur de chargement des modérateurs');
    }
  }

  // === BOOKMARKS ===

  Future<List<dynamic>> getBookmarks({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/bookmarks.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Handle paginated response
      if (data['data'] != null) {
        return data['data'];
      }
      return data['bookmarks'] ?? [];
    } else {
      throw Exception('Erreur de chargement des favoris');
    }
  }

  Future<Map<String, dynamic>> removeBookmark(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/bookmarks.php?post_id=$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de suppression du favori');
    }
  }

  // === PROFILE UPDATE ===

  Future<Map<String, dynamic>> updateProfile({
    String? bio,
    String? website,
    String? location,
    String? avatar,
    String? banner,
    String? github,
    String? twitter,
    String? instagram,
    String? facebook,
    String? tiktok,
    String? mastodon,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (website != null) body['website'] = website;
    if (location != null) body['location'] = location;
    if (avatar != null) body['avatar'] = avatar;
    if (banner != null) body['banner'] = banner;
    if (github != null) body['github'] = github;
    if (twitter != null) body['twitter'] = twitter;
    if (instagram != null) body['instagram'] = instagram;
    if (facebook != null) body['facebook'] = facebook;
    if (tiktok != null) body['tiktok'] = tiktok;
    if (mastodon != null) body['mastodon'] = mastodon;

    final response = await http.put(
      Uri.parse('$apiUrl/v1/users.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de mise à jour du profil');
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/user_preferences.php'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['success'] == true ? json : {};
    } else {
      throw Exception('Erreur de chargement des préférences');
    }
  }

  Future<Map<String, dynamic>> updatePreferences(
    Map<String, dynamic> prefs,
  ) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/user_preferences.php'),
      headers: _headers,
      body: jsonEncode(prefs),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de mise à jour des préférences');
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/change_password.php'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Impossible de changer le mot de passe');
    }
  }

  // === SEARCH ===

  Future<Map<String, dynamic>> search(
    String query, {
    String type = 'all',
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$apiUrl/v1/search.php?q=${Uri.encodeComponent(query)}&type=$type&page=$page',
      ),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'] ?? data;
      }
      return data;
    } else {
      throw Exception('Erreur de recherche');
    }
  }
}
