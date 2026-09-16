import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'api_service.dart';
import 'message_navigation_service.dart';

const String _groupCallMessagePrefix = '__militant_group_call__:';

/// Service de réponse rapide depuis les notifications
/// Permet de répondre à un message privé ou de groupe
/// directement depuis la notification Android (comme Signal/WhatsApp)
class NotificationReplyService {
  NotificationReplyService._internal();
  static final NotificationReplyService instance =
      NotificationReplyService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Écouter les clics sur les notifications
    OneSignal.Notifications.addClickListener(_handleNotificationClick);

    _isInitialized = true;
  }

  void _handleNotificationClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (data == null) return;

    final type = data['type']?.toString();
    final messagePreview = data['message_preview']?.toString().trim() ?? '';

    // Ne traiter que les messages privés et de groupe
    if (type != 'message' && type != 'group_message') return;
    if (type == 'group_message' &&
        messagePreview.startsWith(_groupCallMessagePrefix)) {
      return;
    }

    MessageNavigationService.instance.handlePayload(
      data,
      notificationTitle: event.notification.title,
      notificationBody: event.notification.body,
    );
  }

  /// Gérer une réponse rapide inline depuis la notification
  /// Appelé quand l'utilisateur tape une réponse directement dans la notification
  Future<void> handleInlineReply({
    required Map<String, dynamic> notifData,
    required String replyText,
  }) async {
    if (replyText.trim().isEmpty) return;

    final type = notifData['type']?.toString();

    try {
      final api = await ApiService.getInstance();

      if (type == 'message') {
        // Message privé
        final senderId = _parseInt(notifData['sender_id']);
        if (senderId == null) return;
        await api.sendMessage(senderId, replyText.trim());
      } else if (type == 'group_message') {
        // Message de groupe
        final groupId = _parseInt(notifData['group_id']);
        if (groupId == null) return;
        await api.sendGroupMessage(groupId, replyText.trim());
      }
    } catch (e) {
      debugPrint('NotificationReplyService: Erreur envoi réponse rapide: $e');
    }
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
