import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _groupCallMessagePrefix = '__militant_group_call__:';

/// Service qui affiche des notifications locales avec bouton "Répondre"
/// pour les messages privés et de groupe — comme Signal/WhatsApp
class MessageNotificationService {
  MessageNotificationService._internal();
  static final MessageNotificationService instance =
      MessageNotificationService._internal();

  static const _channel = MethodChannel(
    'com.militant.militant_flutter/notifications',
  );

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    // Écouter les notifications OneSignal en avant-plan pour les messages
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data == null) {
        event.notification.display();
        return;
      }

      final type = data['type']?.toString();
      if (type == 'call') {
        return;
      }

      final messagePreview = data['message_preview']?.toString().trim() ?? '';
      final isGroupCallMarker =
          type == 'group_message' &&
          messagePreview.startsWith(_groupCallMessagePrefix);

      if (isGroupCallMarker) {
        event.preventDefault();
        return;
      }

      // Pour les messages, on affiche notre propre notification avec le bouton Répondre
      if (type == 'message' || type == 'group_message') {
        event
            .preventDefault(); // Empêcher l'affichage de la notif OneSignal standard
        _showReplyableNotification(
          title: event.notification.title ?? 'Nouveau message',
          body: event.notification.body ?? '',
          data: data,
        );
        return;
      }

      // Pour les autres notifs (likes, commentaires...) affichage normal
      event.notification.display();
    });

    _isInitialized = true;
  }

  Future<void> _showReplyableNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final baseUrl = prefs.getString('base_url') ?? '';

      final isGroup = data['type'] == 'group_message';
      final senderId = int.tryParse(data['sender_id']?.toString() ?? '') ?? -1;
      final groupId = int.tryParse(data['group_id']?.toString() ?? '') ?? -1;

      await _channel.invokeMethod('showReplyNotification', {
        'title': title,
        'body': body,
        'senderId': senderId,
        'groupId': groupId,
        'isGroup': isGroup,
        'conversationName': title,
        'token': token,
        'baseUrl': baseUrl,
      });
    } catch (e) {
      debugPrint('MessageNotificationService: Erreur affichage notif: $e');
    }
  }
}
