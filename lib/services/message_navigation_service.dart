import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import '../screens/group_chat_screen.dart';
import 'incoming_call_service.dart';

/// Service centralisant la redirection vers les conversations
/// privées et de groupe lors d'un clic sur une notification (OneSignal ou native)
class MessageNavigationService {
  MessageNavigationService._internal();
  static final MessageNavigationService instance =
      MessageNavigationService._internal();

  Map<String, dynamic>? _pendingNotification;
  DateTime? _lastNavTime;
  String? _lastNavKey;

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

    final navigator = appNavigatorKey.currentState;
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

    final navigator = appNavigatorKey.currentState;
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

  /// Traite un payload de notification (reçu depuis OneSignal ou Android MethodChannel)
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
        // Tentative d'extraction depuis le corps de notification (ex: "alice vous a envoyé un message")
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
    } else if (type == 'group_message') {
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
    }
  }

  /// Vide la notification en attente (appelé une fois l'écran d'accueil affiché)
  void flushPendingNotification() {
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
    }
  }
}
