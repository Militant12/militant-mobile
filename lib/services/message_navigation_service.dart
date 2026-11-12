import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import '../screens/group_chat_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/group_detail_screen.dart';
import 'api_service.dart';
import 'deep_link_service.dart';
import 'incoming_call_service.dart';

/// Service centralisant la redirection vers les différents écrans de l'app
/// lors d'un clic sur une notification (ntfy, OneSignal ou native Android)
class MessageNavigationService {
  MessageNavigationService._internal();
  static final MessageNavigationService instance =
      MessageNavigationService._internal();

  Map<String, dynamic>? _pendingNotification;
  DateTime? _lastNavTime;
  String? _lastNavKey;

  /// Vrai une fois l'ecran d'accueil affiche. Avant, l'ecran de demarrage
  /// remplace la route du dessus par l'accueil (pushReplacement) et effacerait
  /// l'ecran ouvert depuis la notification : on met donc la navigation en attente.
  bool _appReady = false;

  NavigatorState? _readyNavigator() =>
      _appReady ? appNavigatorKey.currentState : null;

  /// Tente d'ouvrir la conversation privée immédiatement,
  /// ou met en attente si le Navigator n'est pas encore prêt.
  void openPrivateChat({
    required int userId,
    String? username,
    String? avatar,
  }) {
    final now = DateTime.now();
    final navKey = 'chat_$userId';
    if (_lastNavKey == navKey &&
        _lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(seconds: 1)) {
      return;
    }

    final navigator = _readyNavigator();
    if (navigator == null) {
      debugPrint('[MessageNav] Navigator indisponible, mise en attente chat $userId');
      _pendingNotification = {
        'type': 'message',
        'userId': userId,
        'username': username,
        'avatar': avatar,
      };
      return;
    }

    _lastNavKey = navKey;
    _lastNavTime = now;

    final resolvedUsername = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : 'Utilisateur #$userId';

    debugPrint('[MessageNav] Navigation vers ChatScreen (userId: $userId, username: $resolvedUsername)');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          userId: userId,
          username: resolvedUsername,
          avatar: avatar,
        ),
      ),
    );
  }

  /// Tente d'ouvrir la conversation de groupe immédiatement,
  /// ou met en attente si le Navigator n'est pas encore prêt.
  void openGroupChat({
    required int groupId,
    String? groupName,
    String? groupAvatar,
  }) {
    final now = DateTime.now();
    final navKey = 'group_$groupId';
    if (_lastNavKey == navKey &&
        _lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(seconds: 1)) {
      return;
    }

    final navigator = _readyNavigator();
    if (navigator == null) {
      debugPrint('[MessageNav] Navigator indisponible, mise en attente groupe $groupId');
      _pendingNotification = {
        'type': 'group_message',
        'groupId': groupId,
        'groupName': groupName,
        'groupAvatar': groupAvatar,
      };
      return;
    }

    _lastNavKey = navKey;
    _lastNavTime = now;

    final resolvedGroupName = (groupName != null && groupName.trim().isNotEmpty)
        ? groupName.trim()
        : 'Groupe #$groupId';

    debugPrint('[MessageNav] Navigation vers GroupChatScreen (groupId: $groupId, groupName: $resolvedGroupName)');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          groupId: groupId,
          groupName: resolvedGroupName,
          groupAvatar: groupAvatar,
        ),
      ),
    );
  }

  /// Ouvre l'écran de détail d'un post (avec ses commentaires)
  void openPost({
    required int postId,
  }) {
    final now = DateTime.now();
    final navKey = 'post_$postId';
    if (_lastNavKey == navKey &&
        _lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(seconds: 1)) {
      return;
    }

    final navigator = _readyNavigator();
    if (navigator == null) {
      debugPrint('[MessageNav] Navigator indisponible, mise en attente post $postId');
      _pendingNotification = {
        'type': 'post',
        'postId': postId,
      };
      return;
    }

    _lastNavKey = navKey;
    _lastNavTime = now;

    debugPrint('[MessageNav] Navigation vers PostDetailScreen (postId: $postId)');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: postId),
      ),
    );
  }

  /// Ouvre le profil d'un utilisateur
  void openProfile({
    required int userId,
  }) {
    final now = DateTime.now();
    final navKey = 'profile_$userId';
    if (_lastNavKey == navKey &&
        _lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(seconds: 1)) {
      return;
    }

    final navigator = _readyNavigator();
    if (navigator == null) {
      debugPrint('[MessageNav] Navigator indisponible, mise en attente profile $userId');
      _pendingNotification = {
        'type': 'profile',
        'userId': userId,
      };
      return;
    }

    _lastNavKey = navKey;
    _lastNavTime = now;

    debugPrint('[MessageNav] Navigation vers ProfileScreen (userId: $userId)');

    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  /// Ouvre le détail d'un groupe social
  Future<void> openGroupDetail({
    required int groupId,
  }) async {
    final now = DateTime.now();
    final navKey = 'group_detail_$groupId';
    if (_lastNavKey == navKey &&
        _lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(seconds: 1)) {
      return;
    }

    final navigator = _readyNavigator();
    if (navigator == null) {
      debugPrint('[MessageNav] Navigator indisponible, mise en attente group_detail $groupId');
      _pendingNotification = {
        'type': 'group_detail',
        'groupId': groupId,
      };
      return;
    }

    _lastNavKey = navKey;
    _lastNavTime = now;

    try {
      final api = await ApiService.getInstance();
      final groupData = await api.getSocialGroupDetails(groupId);
      final currentNav = appNavigatorKey.currentState;
      if (currentNav != null) {
        currentNav.push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: groupData),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MessageNav] Erreur chargement group detail: $e');
    }
  }

  /// Traite un payload de notification (reçu depuis ntfy, OneSignal ou MethodChannel)
  void handlePayload(
    Map<dynamic, dynamic>? rawData, {
    String? notificationTitle,
    String? notificationBody,
  }) {
    if (rawData == null) return;
    final data = Map<String, dynamic>.from(rawData);

    final type = data['type']?.toString();
    final body = notificationBody?.trim() ?? '';
    final title = notificationTitle?.trim() ?? '';

    debugPrint('[MessageNav] handlePayload: type=$type, data=$data');

    // 1. Messages privés
    if (type == 'message') {
      final senderId = int.tryParse(
        data['sender_id']?.toString() ??
            data['senderId']?.toString() ??
            data['user_id']?.toString() ??
            '',
      );
      if (senderId == null || senderId <= 0) {
        debugPrint('[MessageNav] sender_id manquant ou invalide: $data');
        return;
      }

      String? username = data['username']?.toString() ??
          data['sender_name']?.toString() ??
          data['name']?.toString() ??
          data['author']?.toString();

      if (username == null || username.trim().isEmpty) {
        final convName = data['conversationName']?.toString();
        if (convName != null &&
            convName.trim().isNotEmpty &&
            !convName.contains('Nouveau message')) {
          username = convName;
        }
      }

      if (username == null || username.trim().isEmpty) {
        final match = RegExp(r'^(.+?)\s+vous a envoyé un message', caseSensitive: false)
            .firstMatch(body);
        if (match != null) {
          username = match.group(1)?.trim();
        }
      }

      if (username == null || username.trim().isEmpty) {
        if (title.isNotEmpty && !title.contains('Nouveau message')) {
          username = title;
        }
      }

      final avatar = data['avatar']?.toString() ??
          data['sender_avatar']?.toString();

      openPrivateChat(
        userId: senderId,
        username: username,
        avatar: avatar,
      );
      return;
    }

    // 2. Messages de groupe
    if (type == 'group_message') {
      final groupId = int.tryParse(
        data['group_id']?.toString() ??
            data['groupId']?.toString() ??
            '',
      );
      if (groupId == null || groupId <= 0) {
        debugPrint('[MessageNav] group_id manquant ou invalide: $data');
        return;
      }

      String? groupName = data['group_name']?.toString() ??
          data['conversationName']?.toString();

      if (groupName == null || groupName.trim().isEmpty) {
        if (title.isNotEmpty && !title.contains('Nouveau message')) {
          groupName = title;
        }
      }

      final groupAvatar = data['group_avatar']?.toString();

      openGroupChat(
        groupId: groupId,
        groupName: groupName,
        groupAvatar: groupAvatar,
      );
      return;
    }

    // 3. Commentaires & Réponses sur des posts
    if (type == 'comment' ||
        type == 'post_comment' ||
        type == 'reply' ||
        type == 'post_reply') {
      final postId = _extractPostId(data);
      if (postId != null && postId > 0) {
        openPost(postId: postId);
        return;
      }
    }

    // 4. Likes & Réactions sur des posts
    if (type == 'like' ||
        type == 'post_like' ||
        type == 'reaction' ||
        type == 'post_reaction') {
      final postId = _extractPostId(data);
      if (postId != null && postId > 0) {
        openPost(postId: postId);
        return;
      }
    }

    // 5. Mentions
    if (type == 'mention') {
      final postId = _extractPostId(data);
      if (postId != null && postId > 0) {
        openPost(postId: postId);
        return;
      }
      final userId = _extractUserId(data);
      if (userId != null && userId > 0) {
        openProfile(userId: userId);
        return;
      }
    }

    // 6. Demandes d'ami, acceptations, abonnements
    if (type == 'follow' ||
        type == 'friend_request' ||
        type == 'friend_accept') {
      final userId = _extractUserId(data);
      if (userId != null && userId > 0) {
        openProfile(userId: userId);
        return;
      }
    }

    // 7. Si un lien direct est fourni dans les métadonnées (ex: post.php?id=123)
    final link = data['link']?.toString() ?? data['url']?.toString();
    if (link != null && link.trim().isNotEmpty) {
      DeepLinkService().handleLinkString(link);
      return;
    }

    // 8. Repli générique basé sur la présence d'identifiants
    final fallbackPostId = _extractPostId(data);
    if (fallbackPostId != null && fallbackPostId > 0) {
      openPost(postId: fallbackPostId);
      return;
    }

    final fallbackGroupId = int.tryParse(data['group_id']?.toString() ?? '');
    if (fallbackGroupId != null && fallbackGroupId > 0) {
      openGroupDetail(groupId: fallbackGroupId);
      return;
    }

    final fallbackUserId = _extractUserId(data);
    if (fallbackUserId != null && fallbackUserId > 0) {
      openProfile(userId: fallbackUserId);
      return;
    }

    debugPrint('[MessageNav] Type de notification non routable: $type');
  }

  int? _extractPostId(Map<String, dynamic> data) {
    final direct = int.tryParse(
      data['post_id']?.toString() ?? data['postId']?.toString() ?? '',
    );
    if (direct != null && direct > 0) return direct;

    final link = data['link']?.toString() ?? data['url']?.toString();
    if (link != null) {
      final uri = Uri.tryParse(link);
      if (uri != null) {
        final queryId = int.tryParse(uri.queryParameters['id'] ?? '');
        if (queryId != null && queryId > 0) return queryId;
      }
      final regex = RegExp(r'[?&]id=(\d+)');
      final match = regex.firstMatch(link);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  int? _extractUserId(Map<String, dynamic> data) {
    return int.tryParse(
      data['user_id']?.toString() ??
          data['userId']?.toString() ??
          data['sender_id']?.toString() ??
          data['senderId']?.toString() ??
          data['from_user_id']?.toString() ??
          '',
    );
  }

  /// Vide la notification en attente (appelé une fois l'écran d'accueil affiché)
  void flushPendingNotification() {
    _appReady = true;
    final pending = _pendingNotification;
    if (pending == null) return;
    _pendingNotification = null;

    final type = pending['type'];
    debugPrint('[MessageNav] flushPendingNotification: type=$type');

    if (type == 'message') {
      openPrivateChat(
        userId: pending['userId'] as int,
        username: pending['username'] as String?,
        avatar: pending['avatar'] as String?,
      );
    } else if (type == 'group_message') {
      openGroupChat(
        groupId: pending['groupId'] as int,
        groupName: pending['groupName'] as String?,
        groupAvatar: pending['groupAvatar'] as String?,
      );
    } else if (type == 'post') {
      openPost(
        postId: pending['postId'] as int,
      );
    } else if (type == 'profile') {
      openProfile(
        userId: pending['userId'] as int,
      );
    } else if (type == 'group_detail') {
      openGroupDetail(
        groupId: pending['groupId'] as int,
      );
    }
  }
}
