import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class ApiService {
  String baseUrl;
  String? token;
  int? _currentUserId;

  ApiService({required this.baseUrl, this.token});

  // Singleton pattern pour accès global
  static ApiService? _instance;

  static String normalizeBaseUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) {
      return 'https://api.militant.revlibertaire.com';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Future<ApiService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      // Par défaut, utiliser l'API sur le sous-domaine api.
      final rawUrl =
          prefs.getString('base_url') ??
          'https://api.militant.revlibertaire.com';
      final url = normalizeBaseUrl(rawUrl);
      final token = prefs.getString('api_token');

      if (url != rawUrl) {
        await prefs.setString('base_url', url);
      }

      _instance = ApiService(baseUrl: url, token: token);
    }
    return _instance!;
  }

  /// Use a prefixed external ID to avoid blocked raw numeric aliases in OneSignal.
  static String oneSignalExternalIdFromUserId(dynamic userId) {
    final raw = userId?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    return 'u_$raw';
  }

  // Headers avec authentification
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // Generic POST helper
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(
          error['message'] ??
              error['error'] ??
              'Server error ${response.statusCode}',
        );
      } catch (e) {
        throw Exception('Server error ${response.statusCode}');
      }
    }
  }

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

  // Obtenir l'URL principale du site (sans sous-domaine api ni suffixe /api)
  String get mainSiteUrl {
    final normalizedBase = normalizeBaseUrl(baseUrl);
    final parsed = Uri.tryParse(normalizedBase);

    if (parsed == null || parsed.host.isEmpty) {
      return 'https://militant.revlibertaire.com';
    }

    String host = parsed.host;
    if (host.startsWith('api.')) {
      host = host.substring(4);
    }

    // Retirer /api ou /api/vX en fin de chemin si présent
    final rawPath = parsed.path;
    String path = rawPath.replaceFirst(RegExp(r'/api(?:/v\d+)?/?$'), '');
    if (path == '/') {
      path = '';
    }

    final mainUri = Uri(
      scheme: parsed.scheme.isEmpty ? 'https' : parsed.scheme,
      userInfo: parsed.userInfo.isNotEmpty ? parsed.userInfo : null,
      host: host,
      port: parsed.hasPort ? parsed.port : null,
      path: path,
    );

    String url = mainUri.toString();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
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

    // Les médias sont servis depuis le domaine principal (pas /api)
    String mainUrl = mainSiteUrl;

    // Si le chemin ne contient pas de slash, c'est juste un nom de fichier
    // Il faut ajouter le dossier approprié
    if (!path.contains('/')) {
      if (path.startsWith('media_')) {
        path = 'uploads/posts/$path';
      } else if (path.startsWith('avatar_')) {
        path = 'uploads/$path';
      } else if (path.startsWith('story_') || path.startsWith('stories_')) {
        path = 'uploads/stories/$path';
      } else if (path.startsWith('album_')) {
        path = 'uploads/albums/$path';
      } else if (path.startsWith('messages_') || path.startsWith('msg_')) {
        path = 'uploads/messages/$path';
      } else if (path.startsWith('group_post_')) {
        path = 'uploads/posts/$path';
      } else if (path.startsWith('group_')) {
        path = 'uploads/$path';
      } else {
        // Par défaut, on suppose que c'est dans uploads/
        path = 'uploads/$path';
      }
    } else if (path.startsWith('uploads/')) {
      // Si le chemin commence déjà par uploads/, on ne fait rien
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
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('user_id');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        OneSignal.logout();
      } catch (_) {}
    }
  }

  int? _parseDynamicUserId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int? _extractUserId(Map<String, dynamic> data) {
    final directId = _parseDynamicUserId(data['user_id'] ?? data['id']);
    if (directId != null) return directId;

    final nestedUser = data['user'];
    if (nestedUser is Map<String, dynamic>) {
      return _parseDynamicUserId(nestedUser['id'] ?? nestedUser['user_id']);
    }
    return null;
  }

  String _sanitizeServerMessage(
    String body, {
    String fallback = 'Réponse invalide du serveur',
  }) {
    final cleaned = body
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isNotEmpty ? cleaned : fallback;
  }

  Map<String, dynamic> _decodeJsonMap(
    http.Response response, {
    String fallbackError = 'Réponse invalide du serveur',
  }) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      throw Exception(
        _sanitizeServerMessage(response.body, fallback: fallbackError),
      );
    }

    throw Exception(fallbackError);
  }

  String _extractApiError(
    http.Response response, {
    String fallbackError = 'Erreur serveur',
  }) {
    try {
      final data = _decodeJsonMap(response, fallbackError: fallbackError);
      final message = data['error'] ?? data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    return _sanitizeServerMessage(response.body, fallback: fallbackError);
  }

  void _logApiIssue(
    String scope, {
    http.Response? response,
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[API][$scope]');
    if (response != null) {
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
    }
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
  }

  // Obtenir l'ID avec cache en mémoire
  Future<int?> getCurrentUserId() async {
    if (_currentUserId != null) return _currentUserId;
    try {
      final profile = await getProfile();
      final userId = _extractUserId(profile);
      if (userId != null) {
        _currentUserId = userId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', userId);
      }
      return _currentUserId;
    } catch (e) {
      return null;
    }
  }

  // === AUTHENTIFICATION ===

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? totp,
  }) async {
    try {
      final body = {'username': username, 'password': password};
      if (totp != null) body['totp'] = totp;

      final response = await http.post(
        Uri.parse('$apiUrl/v1/auth.php?action=login'),
        headers: _headers,
        body: jsonEncode(body),
      );

      // Debug: afficher la réponse brute
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['token'] != null) {
            await saveToken(data['token']);

            final userId = _extractUserId(data);
            if (userId != null) {
              _currentUserId = userId;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('user_id', userId);
            }
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
      if (e is HandshakeException ||
          e.toString().contains('HandshakeException') ||
          e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        throw Exception(
          'Connexion HTTPS refusée. Vérifiez le certificat SSL du serveur (certificat auto-signé/non valide).',
        );
      }
      if (e.toString().contains('Operation not permitted')) {
        throw Exception(
          'Connexion réseau bloquée par macOS. Rebuild l’app avec le script macOS mis à jour puis relancez.',
        );
      }
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
    String password, {
    String? cause,
  }) async {
    final body = {'username': username, 'email': email, 'password': password};

    if (cause != null) {
      body['cause'] = cause;
    }

    final response = await http.post(
      Uri.parse('$apiUrl/v1/auth.php?action=register'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'inscription: ${response.statusCode}');
    }
  }

  // === TWO-FACTOR AUTHENTICATION ===

  Future<Map<String, dynamic>> getTwoFactorStatus() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/two_factor.php'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la récupération du statut 2FA');
    }
  }

  Future<Map<String, dynamic>> enableTwoFactor(String code) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/two_factor.php?action=enable'),
      headers: _headers,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors de l\'activation du 2FA');
    }
  }

  Future<Map<String, dynamic>> disableTwoFactor() async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/two_factor.php'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la désactivation du 2FA');
    }
  }

  // === POSTS ===

  Future<List<dynamic>> getPosts({
    int page = 1,
    int limit = 20,
    int? userId,
    String? feedType,
  }) async {
    String url = '$apiUrl/v1/posts.php?page=$page&per_page=$limit';

    if (userId != null) {
      url += '&user_id=$userId';
    }

    if (feedType != null) {
      url += '&feed_type=$feedType';
    }

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Gérer différents formats de réponse
      if (data is Map && data['success'] == true) {
        // Format avec success
        if (data['posts'] != null) {
          return data['posts'];
        }
        if (data['data'] != null) {
          // Format paginé peut-être complexe {data: {posts: []}} ou {data: []}
          if (data['data'] is List) return data['data'];
          if (data['data'] is Map && data['data']['posts'] is List) {
            return data['data']['posts'];
          }
        }
      }

      // Format sans success: {posts: [...]}
      if (data is Map && data['posts'] != null) {
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

  Future<Map<String, dynamic>> getPost(int id) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/posts.php?id=$id'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data']; // The post object
      }
      return data; // Fallback if structure varies
    } else {
      throw Exception('Erreur de chargement du post');
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
    String? mediaType,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/posts.php'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'media': mediaUrls,
        if (mediaType != null) 'media_type': mediaType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de création du post: ${response.statusCode}');
    }
  }

  Future<void> updatePost(int postId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/posts.php?id=$postId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
      throw Exception('Erreur de mise à jour du post: ${response.statusCode}');
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
    // Utiliser l'API v1
    final url = apiUrl;

    // Détecter la langue de l'appareil si targetLang n'est pas fourni
    String finalTargetLang = targetLang ?? 'fr';
    if (targetLang == null) {
      try {
        // Obtenir la langue du système
        final locale = WidgetsBinding.instance.platformDispatcher.locale;
        finalTargetLang = locale.languageCode; // 'fr', 'en', 'es', etc.
      } catch (e) {
        // Fallback sur français
        finalTargetLang = 'fr';
      }
    }

    // Normalisation basique (ex: fr-FR -> fr) pour éviter les erreurs LibreTranslate
    // Préserver la casse de zh-Hans (sensible à la casse côté LibreTranslate)
    if (finalTargetLang.length > 2 && finalTargetLang.contains('-')) {
      final lower = finalTargetLang.toLowerCase();
      if (lower == 'zh-hans' || lower == 'zh-hant') {
        finalTargetLang = 'zh-Hans'; // Forcer la bonne casse
      } else {
        finalTargetLang = finalTargetLang.split('-')[0];
      }
    }

    final response = await http
        .post(
          Uri.parse('$url/v1/translate.php'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
          body: {'text': text, 'target_lang': finalTargetLang},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Normaliser le champ de réponse : serveur renvoie 'translated' ou 'translatedText'
      if (data is Map &&
          !data.containsKey('translatedText') &&
          data.containsKey('translated')) {
        data['translatedText'] = data['translated'];
      }
      return data;
    } else {
      String errorMsg = 'Erreur de traduction (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        errorMsg = err['error'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
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
      debugPrint('Comments API response: ${response.body}');
      return data['data'] ??
          []; // paginate() returns 'data' by default if not specified
    } else {
      debugPrint(
        'Comments API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Erreur de chargement des commentaires');
    }
  }

  Future<Map<String, dynamic>> addComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    final body = {'post_id': postId, 'content': content};
    if (parentId != null) {
      body['parent_id'] = parentId;
    }

    final response = await http.post(
      Uri.parse('$apiUrl/v1/comments.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'ajout du commentaire');
    }
  }

  Future<Map<String, dynamic>> updateComment(
    int commentId,
    String content,
  ) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/comments.php?id=$commentId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );

    debugPrint('Update comment response status: ${response.statusCode}');
    debugPrint('Update comment response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Erreur de modification du commentaire: ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/comments.php?id=$commentId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de suppression du commentaire');
    }
  }

  Future<List<dynamic>> getGroupPostComments(int postId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/group_comments.php?post_id=$postId&page=$page'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      debugPrint('Group comments API response: ${response.body}');
      return data['data'] ?? [];
    } else {
      debugPrint(
        'Group comments API error: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Erreur de chargement des commentaires du groupe');
    }
  }

  Future<Map<String, dynamic>> addGroupComment(
    int postId,
    String content, {
    int? parentId,
  }) async {
    final body = {'post_id': postId, 'content': content};
    if (parentId != null) {
      body['parent_id'] = parentId;
    }

    final response = await http.post(
      Uri.parse('$apiUrl/v1/group_comments.php'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'ajout du commentaire de groupe');
    }
  }

  Future<void> updateGroupComment(int commentId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/group_comments.php'),
      headers: _headers,
      body: jsonEncode({'id': commentId, 'content': content}),
    );

    debugPrint('Update group comment response status: ${response.statusCode}');
    debugPrint('Update group comment response body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur de modification du commentaire de groupe: ${response.body}',
      );
    }
  }

  Future<void> deleteGroupComment(int commentId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/group_comments.php?id=$commentId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur de suppression du commentaire de groupe');
    }
  }

  // === RÉACTIONS SUR COMMENTAIRES ===

  Future<Map<String, dynamic>> reactToComment(
    int commentId,
    String commentType, {
    String reactionType = 'like',
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/comment_reactions.php'),
      headers: _headers,
      body: jsonEncode({
        'comment_id': commentId,
        'comment_type': commentType,
        'reaction_type': reactionType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de réaction au commentaire');
    }
  }

  Future<Map<String, dynamic>> removeCommentReaction(
    int commentId,
    String commentType,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '$apiUrl/v1/comment_reactions.php?comment_id=$commentId&comment_type=$commentType',
      ),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de suppression de réaction');
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

  /// Met à jour les champs du profil utilisateur (bio, statut, badge…)
  Future<Map<String, dynamic>> updateUserProfile({
    String? bio,
    String? website,
    String? avatar,
    String? banner,
    String? militantBadge,
    String? statusEmoji,
    String? statusText,
    bool clearStatus = false,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (website != null) body['website'] = website;
    if (avatar != null) body['avatar'] = avatar;
    if (banner != null) body['banner'] = banner;
    if (militantBadge != null) body['militant_badge'] = militantBadge;
    if (clearStatus) {
      body['status_emoji'] = null;
      body['status_text'] = null;
    } else {
      if (statusEmoji != null) body['status_emoji'] = statusEmoji;
      if (statusText != null) body['status_text'] = statusText;
    }

    final response = await http.put(
      Uri.parse('$apiUrl/v1/users.php'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur mise à jour du profil');
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

  // === AMIS ===

  Future<Map<String, dynamic>> getFriends({
    String type = 'all',
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/friends.php?type=$type&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement des amis');
    }
  }

  Future<Map<String, dynamic>> sendFriendRequest(int userId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/friends.php'),
      headers: _headers,
      body: jsonEncode({'action': 'send', 'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body)['error'] ?? 'Erreur';
      throw Exception(error);
    }
  }

  Future<Map<String, dynamic>> handleFriendRequest(
    int requestId,
    String action, // 'accept' or 'reject'
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/friends.php'),
      headers: _headers,
      body: jsonEncode({'action': action, 'request_id': requestId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de traitement de la demande'); // Message d'erreur
    }
  }

  // === APPELS ===

  Future<Map<String, dynamic>> getCallInfo(String callId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/calls.php?action=poll&call_id=$callId'),
      headers: _flutterHeaders,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data']['call'] ?? {};
      }
      return data;
    } else {
      throw Exception('Impossible de récupérer les infos de l\'appel');
    }
  }

  Future<Map<String, dynamic>> unfriend(int userId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/friends.php?user_id=$userId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la suppression de l\'ami');
    }
  }

  // === MESSAGES ===

  Future<List<dynamic>> getMessages({int? userId, int page = 1}) async {
    final url = userId != null
        ? '$apiUrl/v1/messages.php?user_id=$userId&page=$page'
        : '$apiUrl/v1/messages.php?page=$page';

    final response = await http.get(Uri.parse(url), headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        // Handle paginated response structure: {success: true, data: {data: [...], meta: ...}}
        if (data['data'] is Map && data['data']['data'] != null) {
          return data['data']['data'];
        }
        // Fallback for simple list or other structures
        if (data['data'] is List) {
          return data['data'];
        }
      }
      return data['messages'] ?? []; // Very old fallback
    } else {
      throw Exception('Erreur de chargement des messages');
    }
  }

  Future<List<dynamic>> getGroupMessages(int groupId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse(
        '$apiUrl/v1/message_groups.php?path=$groupId/messages&page=$page',
      ),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['messages'] ?? [];
    } else {
      throw Exception('Erreur de chargement des messages du groupe');
    }
  }

  Future<Map<String, dynamic>> sendGroupMessage(
    int groupId,
    String content, {
    String? media,
    String? mediaType,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId/messages'),
      headers: _headers,
      body: jsonEncode({
        'content': content,
        'media': media,
        if (mediaType != null) 'media_type': mediaType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'envoi du message au groupe');
    }
  }

  Future<void> deleteGroupMessage(int messageId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/message_groups.php?path=messages/$messageId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la suppression du message de groupe');
    }
  }

  Future<void> editGroupMessage(int messageId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/message_groups.php?path=messages/$messageId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la modification du message de groupe');
    }
  }

  Future<Map<String, dynamic>> getGroupDetails(int groupId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['group'];
    } else {
      throw Exception('Erreur de chargement des détails du groupe');
    }
  }

  Future<void> updateGroupSettings(
    int groupId, {
    String? name,
    int? autoDeleteTime,
    bool? makeEveryoneAdmin,
  }) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (autoDeleteTime != null) 'auto_delete_time': autoDeleteTime,
        if (makeEveryoneAdmin != null) 'make_everyone_admin': makeEveryoneAdmin,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la mise à jour des paramètres du groupe');
    }
  }

  Future<void> leaveMessageGroup(int groupId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la sortie du groupe');
    }
  }

  Future<void> removeMemberFromGroup(int groupId, int userId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId/members/$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors du retrait du membre');
    }
  }

  Future<void> addGroupMember(int groupId, int userId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/message_groups.php?path=$groupId/members'),
      headers: _headers,
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'ajout du membre');
    }
  }

  Future<void> approveGroupRequest(int groupId, int requestId) async {
    final response = await http.post(
      Uri.parse(
        '$apiUrl/v1/message_groups.php?path=$groupId/requests/$requestId/approve',
      ),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'approbation de la demande');
    }
  }

  Future<void> rejectGroupRequest(int groupId, int requestId) async {
    final response = await http.post(
      Uri.parse(
        '$apiUrl/v1/message_groups.php?path=$groupId/requests/$requestId/reject',
      ),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors du refus de la demande');
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    int userId,
    String content, {
    String? media,
    String? mediaType,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/messages.php'),
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'content': content,
        'media': media,
        if (mediaType != null) 'media_type': mediaType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur d\'envoi du message: ${response.statusCode}');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/messages.php?id=$messageId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la suppression du message');
    }
  }

  Future<void> deleteConversation(int userId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/messages.php?user_id=$userId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la suppression de la conversation');
    }
  }

  Future<void> editMessage(int messageId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/messages.php?id=$messageId'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la modification du message');
    }
  }

  Future<String> uploadFile(String filePath, {String type = 'posts'}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiUrl/v1/upload.php'),
    );
    // Ne PAS ajouter Content-Type pour multipart (il est géré automatiquement)
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields['type'] = type;
    request.files.add(await http.MultipartFile.fromPath('media', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String url = data['url'];
          if (!url.contains('/')) {
            if (type == 'stories') {
              // Garder juste le nom de fichier pour les stories
            } else if (type == 'messages') {
              // Garder juste le nom de fichier pour les messages aussi !
              // Le web ajoute le chemin lui-même.
              // url = 'uploads/messages/$url';
            } else if (type == 'posts') {
              url = 'uploads/posts/$url';
            } else if (type == 'event') {
              url = 'uploads/events/$url';
            } else if (type == 'album') {
              url = 'uploads/albums/$url';
            } else {
              url = 'uploads/$url';
            }
          }
          return url;
        } else {
          throw Exception(data['error'] ?? 'Erreur d\'upload inconnue');
        }
      } catch (e) {
        // Si jsonDecode échoue, c'est probablement du HTML ou une erreur PHP brute
        if (response.body.contains('<br') || response.body.contains('<html>')) {
          print('Erreur serveur (HTML reçu): ${response.body}');
          throw Exception(
            'Erreur serveur: le fichier est peut-être trop volumineux ou le format est refusé.',
          );
        }
        throw Exception('Réponse invalide du serveur: $e');
      }
    } else if (response.statusCode == 413) {
      throw Exception(
        'Fichier trop volumineux (Erreur 413). Essayez un fichier plus petit.',
      );
    } else {
      throw Exception('Erreur d\'upload: ${response.statusCode}');
    }
  }

  // === DISCOVER ===

  Future<Map<String, dynamic>> getDiscoveryData({
    String type = 'all',
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/discover.php?type=$type&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      }
      return data;
    } else {
      throw Exception('Erreur de chargement des suggestions');
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
      final data = _decodeJsonMap(
        response,
        fallbackError: 'Erreur de chargement des groupes',
      );
      return data['groups'] ?? [];
    } else {
      throw Exception(
        _extractApiError(
          response,
          fallbackError: 'Erreur de chargement des groupes',
        ),
      );
    }
  }

  Future<List<dynamic>> discoverGroups({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/groups.php?discover=1&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(
        response,
        fallbackError: 'Erreur de chargement des groupes',
      );
      return data['groups'] ?? [];
    } else {
      throw Exception(
        _extractApiError(
          response,
          fallbackError: 'Erreur de chargement des groupes',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'create',
        'name': name,
        'description': description ?? '',
        'privacy': isPrivate ? 'private' : 'public',
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors de la création');
    }
  }

  Future<void> cancelCandidacy() async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/moderators.php'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'annulation de la candidature');
    }
  }

  Future<Map<String, dynamic>> joinGroup(int groupId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode({'action': 'join', 'group_id': groupId}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        return _decodeJsonMap(
          response,
          fallbackError: 'Réponse invalide lors de l’adhésion au groupe',
        );
      } catch (e, st) {
        _logApiIssue(
          'joinGroup success decode failed (group_id=$groupId)',
          response: response,
          error: e,
          stackTrace: st,
        );
        rethrow;
      }
    } else {
      _logApiIssue('joinGroup failed (group_id=$groupId)', response: response);
      throw Exception(
        _extractApiError(
          response,
          fallbackError: 'Erreur lors de l\'adhésion au groupe',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> leaveSocialGroup(int groupId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode({'action': 'leave', 'group_id': groupId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors de la sortie du groupe');
    }
  }

  Future<Map<String, dynamic>> getSocialGroupDetails(int groupId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/groups.php?id=$groupId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['data'] ?? json;
    } else {
      throw Exception('Groupe introuvable');
    }
  }

  Future<void> updateGroup(
    int groupId, {
    String? name,
    String? description,
    String? avatar,
    String? coverImage,
    bool? isPrivate,
  }) async {
    final body = {
      'id': groupId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatar != null) 'avatar': avatar,
      if (coverImage != null) 'cover_image': coverImage,
      if (isPrivate != null) 'privacy': isPrivate ? 'private' : 'public',
    };

    final response = await http.put(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Erreur de mise à jour du groupe');
    }
  }

  Future<List<dynamic>> getGroupJoinRequests(
    int groupId, {
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/groups.php?id=$groupId&join_requests=1&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final json = _decodeJsonMap(
        response,
        fallbackError: 'Erreur lors du chargement des demandes',
      );
      return json['data'] ?? [];
    } else {
      throw Exception(
        _extractApiError(
          response,
          fallbackError: 'Erreur lors du chargement des demandes',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> approveGroupJoinRequest(
    int groupId,
    int userId,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'approve_request',
        'group_id': groupId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors de l\'approbation');
    }
  }

  Future<Map<String, dynamic>> rejectGroupJoinRequest(
    int groupId,
    int userId,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/groups.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'reject_request',
        'group_id': groupId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors du rejet');
    }
  }

  Future<List<dynamic>> getGroupMembers(int groupId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/groups.php?id=$groupId&members=1&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Case where paginate uses custom key or default 'data' key
      if (data['members'] != null) return data['members'];
      if (data['data'] != null && data['data'] is List) return data['data'];
      // Sometimes it's wrapped in another 'data' if api_success logic changes
      if (data['data'] != null && data['data']['members'] != null) {
        return data['data']['members'];
      }
      if (data['data'] != null && data['data']['data'] != null) {
        return data['data']['data'];
      }

      return [];
    } else {
      throw Exception('Erreur de chargement des membres');
    }
  }

  Future<List<dynamic>> getGroupPosts(int groupId, {int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/group_posts.php?group_id=$groupId&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = _decodeJsonMap(
        response,
        fallbackError:
            'Réponse invalide du serveur pour les publications du groupe',
      );
      final posts = data['posts'];
      return posts is List ? posts : [];
    }

    final message = _extractApiError(
      response,
      fallbackError: 'Erreur de chargement des publications du groupe',
    );
    throw Exception('HTTP ${response.statusCode}: $message');
  }

  Future<Map<String, dynamic>> createGroupPost(
    int groupId,
    String content, {
    List<String>? media,
    String? mediaType,
  }) async {
    final body = {'group_id': groupId, 'content': content};

    if (media != null && media.isNotEmpty) {
      body['media'] = media.first; // Pour l'instant, un seul média
      if (mediaType != null) {
        body['media_type'] = mediaType;
      }
    }

    final response = await http.post(
      Uri.parse('$apiUrl/v1/group_posts.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la création de la publication');
    }
  }

  Future<Map<String, dynamic>> updateGroupPost(
    int postId,
    String content,
  ) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/group_posts.php'),
      headers: _headers,
      body: jsonEncode({'id': postId, 'content': content}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la modification de la publication');
    }
  }

  Future<Map<String, dynamic>> reactToGroupPost(
    int postId,
    String reactionType,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/group_reactions.php'),
      headers: _headers,
      body: jsonEncode({'post_id': postId, 'reaction_type': reactionType}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la réaction');
    }
  }

  Future<void> removeGroupPostReaction(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/group_reactions.php?post_id=$postId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la suppression de la réaction');
    }
  }

  Future<Map<String, dynamic>> deleteGroupPost(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/group_posts.php?id=$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la suppression de la publication');
    }
  }

  Future<List<dynamic>> getMessageGroups({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/message_groups.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['groups'] ?? [];
    } else {
      throw Exception('Erreur de chargement des groupes de discussion');
    }
  }

  Future<Map<String, dynamic>> createMessageGroup({
    required String name,
    String avatar = 'default.svg',
    List<int> memberIds = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/message_groups.php'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'avatar': avatar,
        'member_ids': memberIds,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la création du groupe');
    }
  }

  Future<List<dynamic>> getEvents({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/events.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Erreur de chargement des événements');
    }
  }

  Future<void> createEvent({
    required String title,
    required String description,
    required String location,
    required String eventDate,
    String? image,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/events.php'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'location': location,
        'event_date': eventDate,
        'image': image,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur de création de l\'événement');
    }
  }

  Future<void> deleteEvent(int eventId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/events.php?id=$eventId&action=delete'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur de suppression de l\'événement');
    }
  }

  Future<Map<String, dynamic>> getEventDetails(int eventId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/events.php?id=$eventId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // L'API retourne les champs directement au premier niveau (pas sous 'data')
      if (data['data'] != null) {
        return data['data'];
      }
      return data;
    } else {
      throw Exception('Erreur de chargement de l\'événement');
    }
  }

  Future<void> joinEvent(int eventId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/events.php'),
      headers: _headers,
      body: jsonEncode({'action': 'join', 'event_id': eventId}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Erreur lors de la participation');
    }
  }

  Future<void> leaveEvent(int eventId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/events.php?id=$eventId&action=leave'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'annulation');
    }
  }

  // === STORIES ===

  Future<List<dynamic>> getStories() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/stories.php'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception('Erreur de chargement des stories');
    }
  }

  Future<List<dynamic>> getUserStories(int userId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/stories.php?user_id=$userId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception('Erreur de chargement des stories');
    }
  }

  Future<Map<String, dynamic>> createStory({
    required String media,
    String? text,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/stories.php'),
      headers: _headers,
      body: jsonEncode({'media': media, 'text': text ?? ''}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body);
        print('DEBUG createStory success: $data');
        return data;
      } catch (e) {
        print('DEBUG createStory JSON ERROR: ${response.body}');
        // Si c'est du HTML, on ne peut pas le parser, mais on veut voir ce que c'est
        throw Exception('Erreur de format API (HTML reçu?): ${response.body}');
      }
    } else {
      print(
        'DEBUG createStory error: ${response.statusCode} - ${response.body}',
      );
      throw Exception('Erreur de création de la story: ${response.body}');
    }
  }

  Future<void> deleteStory(int storyId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/stories.php?id=$storyId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur de suppression de la story');
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
      Uri.parse('$apiUrl/v1/moderators.php?type=candidates'),
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
      Uri.parse('$apiUrl/v1/moderators.php?type=moderators'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['moderators'] ?? [];
    } else {
      throw Exception('Erreur de chargement des modérateurs');
    }
  }

  // Vérifier si l'utilisateur actuel est modérateur
  Future<bool> checkIfModerator() async {
    try {
      final moderators = await getModerators();
      final profile = await getProfile();
      final myId = profile['id'] ?? profile['user_id'];
      return moderators.any((m) => m['user_id'] == myId);
    } catch (e) {
      return false;
    }
  }

  // Action directe de modérateur : supprimer un post signalé
  Future<Map<String, dynamic>> moderatorDeletePost(int reportId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/reports.php'),
      headers: _headers,
      body: jsonEncode({
        'moderator_action': 'delete_post',
        'report_id': reportId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Erreur de suppression');
    }
  }

  // Action directe de modérateur : avertir un utilisateur
  Future<Map<String, dynamic>> moderatorWarnUser(
    int reportId, {
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/reports.php'),
      headers: _headers,
      body: jsonEncode({
        'moderator_action': 'warn_user',
        'report_id': reportId,
        if (reason != null) 'reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Erreur d\'avertissement');
    }
  }

  // Journal transparent des actions de modération
  Future<List<dynamic>> getModeratorActions() async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/moderators.php?type=actions'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['actions'] ?? [];
    } else {
      throw Exception('Erreur de chargement des actions');
    }
  }

  // Sanctions transparentes (toutes les sanctions publiques)
  Future<Map<String, dynamic>> getAllSanctions({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/sanctions.php?type=all&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de chargement des sanctions');
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
    String? avatar,
    String? banner,
    String? twitter,
    String? instagram,
    String? facebook,
    String? tiktok,
    String? mastodon,
    String? bluesky,
  }) async {
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (website != null) body['website'] = website;
    if (avatar != null) body['avatar'] = avatar;
    if (banner != null) body['banner'] = banner;
    if (twitter != null) body['twitter'] = twitter;
    if (instagram != null) body['instagram'] = instagram;
    if (facebook != null) body['facebook'] = facebook;
    if (tiktok != null) body['tiktok'] = tiktok;
    if (mastodon != null) body['mastodon'] = mastodon;
    if (bluesky != null) body['bluesky'] = bluesky;

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

  Future<Map<String, dynamic>> updateMilitantBadge(String? badge) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/users.php'),
      headers: _headers,
      body: jsonEncode({'militant_badge': badge}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur de mise à jour du badge');
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
      if (data is Map<String, dynamic>) {
        return data;
      }
      return {'success': false, 'items': []};
    } else {
      throw Exception('Erreur de recherche');
    }
  }

  // === PAGES ===

  Future<List<dynamic>> getPages({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
        if (data['data']['data'] != null) return data['data']['data'];
      }
      return data['pages'] ?? [];
    } else {
      throw Exception('Erreur de chargement des pages');
    }
  }

  Future<List<dynamic>> getFollowedPages({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?followed=1&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
        if (data['data']['data'] != null) return data['data']['data'];
      }
      return [];
    } else {
      throw Exception('Erreur de chargement des pages suivies');
    }
  }

  Future<List<dynamic>> discoverPages({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?discover=1&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
        if (data['data']['data'] != null) return data['data']['data'];
      }
      return data['pages'] ?? [];
    } else {
      throw Exception('Erreur de chargement des pages');
    }
  }

  Future<Map<String, dynamic>> getPageDetail(int pageId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?id=$pageId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return Map<String, dynamic>.from(data['data']);
      }
      return data;
    } else {
      throw Exception('Erreur de chargement de la page');
    }
  }

  Future<List<dynamic>> getPagePosts(int pageId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?path=$pageId/posts'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
      }
      return [];
    } else {
      throw Exception('Erreur de chargement des posts');
    }
  }

  Future<List<dynamic>> getPagePostComments(int pageId, int postId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?path=$pageId/comments/$postId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
      }
      return [];
    } else {
      throw Exception('Erreur de chargement des commentaires');
    }
  }

  Future<Map<String, dynamic>> createPage({
    required String name,
    String? description,
    String? category,
    String? avatar,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'create',
        'name': name,
        'description': description ?? '',
        'category': category ?? '',
        if (avatar != null) 'avatar': avatar,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur lors de la création de la page');
    }
  }

  Future<Map<String, dynamic>> createPagePost(
    int pageId,
    String content, {
    String? media,
    String? mediaType,
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'create_post',
        'page_id': pageId,
        'content': content,
        if (media != null) 'media': media,
        if (mediaType != null) 'media_type': mediaType,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la création du post');
    }
  }

  Future<Map<String, dynamic>> commentOnPagePost(
    int postId,
    String content,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'comment',
        'post_id': postId,
        'content': content,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de l\'ajout du commentaire');
    }
  }

  Future<Map<String, dynamic>> reactToPagePost(int postId, String type) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({'action': 'react', 'post_id': postId, 'type': type}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la réaction');
    }
  }

  Future<Map<String, dynamic>> followPage(int pageId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({'action': 'follow', 'page_id': pageId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du suivi de la page');
    }
  }

  Future<Map<String, dynamic>> unfollowPage(int pageId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({'action': 'unfollow', 'page_id': pageId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du désabonnement de la page');
    }
  }

  Future<Map<String, dynamic>> deletePagePost(int postId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({'action': 'delete_post', 'post_id': postId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la suppression du post');
    }
  }

  Future<Map<String, dynamic>> updatePageSettings(
    int pageId,
    Map<String, dynamic> settings,
  ) async {
    final body = Map<String, dynamic>.from(settings);
    body['action'] = 'update_page';
    body['page_id'] = pageId;

    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de la mise à jour');
    }
  }

  Future<List<dynamic>> getPageTeam(int pageId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?path=$pageId/team'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
      }
      return [];
    } else {
      throw Exception('Erreur de chargement de l\'équipe');
    }
  }

  Future<Map<String, dynamic>> addTeamMember(
    int pageId,
    String username,
    String role,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'add_team_member',
        'page_id': pageId,
        'username': username,
        'role': role,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erreur');
    }
  }

  Future<Map<String, dynamic>> updateTeamMemberRole(
    int pageId,
    int userId,
    String role,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'update_team_role',
        'page_id': pageId,
        'user_id': userId,
        'role': role,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du changement de rôle');
    }
  }

  Future<Map<String, dynamic>> removeTeamMember(int pageId, int userId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'remove_team_member',
        'page_id': pageId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du retrait du membre');
    }
  }

  Future<List<dynamic>> getPageFollowers(int pageId) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/pages.php?path=$pageId/followers'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        if (data['data'] is List) return data['data'];
      }
      return [];
    } else {
      throw Exception('Erreur de chargement des abonnés');
    }
  }

  Future<Map<String, dynamic>> removePageFollower(
    int pageId,
    int userId,
  ) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'remove_follower',
        'page_id': pageId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du retrait de l\'abonné');
    }
  }

  Future<void> updatePagePost(int postId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'update_post',
        'post_id': postId,
        'content': content,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur de modification du post');
    }
  }

  Future<void> deletePageComment(int commentId) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({'action': 'delete_comment', 'comment_id': commentId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur de suppression du commentaire');
    }
  }

  Future<void> updatePageComment(int commentId, String content) async {
    final response = await http.put(
      Uri.parse('$apiUrl/v1/pages.php'),
      headers: _headers,
      body: jsonEncode({
        'action': 'update_comment',
        'comment_id': commentId,
        'content': content,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Erreur de modification du commentaire');
    }
  }

  // === CALLS (FLUTTER EXCLUSIVE) ===

  // Headers avec le flag Flutter exclusif
  Map<String, String> get _flutterHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Flutter-App': 'militant-flutter-v1', // Header exclusif Flutter
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> initiateCall(
    int recipientId,
    String callType,
    String offerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=initiate'),
      headers: _flutterHeaders,
      body: jsonEncode({
        'recipient_id': recipientId,
        'call_type': callType,
        'offer': offerSdp,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        // Backend wraps response in {success, data:{...}}
        return (body['data'] as Map<String, dynamic>?) ?? body;
      } catch (e) {
        throw Exception(
          'L\'API des appels n\'est pas encore déployée. Veuillez réessayer plus tard.',
        );
      }
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(
          error['error'] ?? 'Erreur lors de l\'initiation de l\'appel',
        );
      } catch (e) {
        throw Exception(
          'L\'API des appels n\'est pas encore disponible (code ${response.statusCode})',
        );
      }
    }
  }

  Future<Map<String, dynamic>> answerCall(
    String callId,
    String answerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=answer'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId, 'answer': answerSdp}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } else {
      throw Exception('Erreur lors de la réponse à l\'appel');
    }
  }

  Future<void> sendIceCandidate(
    String callId,
    Map<String, dynamic> candidate,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=ice_candidate'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId, 'candidate': candidate}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'envoi du ICE candidate');
    }
  }

  Future<void> rejectCall(String callId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=reject'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors du rejet de l\'appel');
    }
  }

  Future<void> leaveGroupCall(String callId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=leave'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la sortie de l\'appel de groupe');
    }
  }

  Future<void> endCall(String callId) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=end'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la fin de l\'appel');
    }
  }

  Future<Map<String, dynamic>> pollCallUpdates(
    String callId,
    String? lastPoll,
  ) async {
    String url = '$apiUrl/v1/calls.php?action=poll&call_id=$callId';
    if (lastPoll != null) {
      url += '&last_poll=${Uri.encodeComponent(lastPoll)}';
    }

    final response = await http.get(Uri.parse(url), headers: _flutterHeaders);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Backend wraps response in {success, data:{call, ice_candidates, ...}}
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data']);
      }
      return body;
    } else {
      throw Exception('Erreur lors du polling');
    }
  }

  Future<List<dynamic>> getCallHistory({int page = 1}) async {
    final response = await http.get(
      Uri.parse('$apiUrl/v1/calls.php?action=history&page=$page'),
      headers: _flutterHeaders,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Backend wraps in {success, data:{data:[...], total, ...}} (paginated)
      final inner = body['data'];
      if (inner is Map && inner['data'] is List) return inner['data'];
      if (inner is List) return inner;
      return [];
    } else {
      throw Exception('Erreur de chargement de l\'historique des appels');
    }
  }

  Future<void> restartIce(String callId, String newOfferSdp) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=ice_restart'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId, 'offer': newOfferSdp}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur lors du redémarrage ICE: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // === GROUP CALLS ===

  Future<Map<String, dynamic>> initiateGroupCall(
    int groupId,
    String callType,
    String offerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=initiate'),
      headers: _flutterHeaders,
      body: jsonEncode({
        'group_id': groupId,
        'call_type': callType,
        'offer': offerSdp,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error'] ?? 'Erreur lors de l\'initiation de l\'appel de groupe',
      );
    }
  }

  /// Enregistre un salon Nextcloud Talk dans la BDD Militant et notifie
  /// tous les membres du groupe avec le [roomToken] pour qu'ils puissent
  /// rejoindre directement le salon audio/vidéo depuis l'app.
  Future<Map<String, dynamic>> initiateTalkRoom({
    required int groupId,
    required String roomToken,
    String callType = 'audio',
  }) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=initiate_talk'),
      headers: _flutterHeaders,
      body: jsonEncode({
        'group_id': groupId,
        'room_token': roomToken,
        'call_type': callType,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error'] ??
            'Erreur lors de l\'envoi de l\'invitation au salon Talk',
      );
    }
  }

  Future<Map<String, dynamic>> joinGroupCall(
    String callId,
    String offerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=join'),
      headers: _flutterHeaders,
      body: jsonEncode({'call_id': callId, 'offer': offerSdp}),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      // Backend wraps response in {success, data:{...}}
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } else {
      throw Exception('Erreur lors de la jonction à l\'appel de groupe');
    }
  }

  Future<void> sendPeerOffer(
    String callId,
    int toUserId,
    String offerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=peer_offer'),
      headers: _flutterHeaders,
      body: jsonEncode({
        'call_id': callId,
        'to_user_id': toUserId,
        'offer': offerSdp,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'envoi de l\'offre au pair');
    }
  }

  Future<void> sendPeerAnswer(
    String callId,
    int toUserId,
    String answerSdp,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/v1/calls.php?action=peer_answer'),
      headers: _flutterHeaders,
      body: jsonEncode({
        'call_id': callId,
        'to_user_id': toUserId,
        'answer': answerSdp,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de l\'envoi de la réponse au pair');
    }
  }
}
