import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:uuid/uuid.dart';

import '../screens/call_screen.dart';
import '../screens/group_call_screen.dart'; // Pour les salons Nextcloud Talk
import 'api_service.dart';
import 'call_kit_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class IncomingCallService {
  IncomingCallService._internal();
  static final IncomingCallService instance = IncomingCallService._internal();

  final CallKitService _callKit = CallKitService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    _callKit.init(
      onAccept: _handleCallAccept,
      onDecline: _handleCallDecline,
      onEnded: _handleCallEnded,
    );

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;

      // ─── Invitation Talk (Nextcloud Talk) ────────────────────────────────
      if (_isTalkInviteNotification(data)) {
        event.preventDefault();
        _showTalkInviteBanner(data: data!, body: event.notification.body);
        return;
      }

      // ─── Appel 1-to-1 classique ──────────────────────────────────────────
      if (!_isCallNotification(data)) {
        event.notification.display();
        return;
      }

      event.preventDefault();
      _showIncomingCallKit(data: data!, body: event.notification.body);
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;

      // ─── Clic sur une invitation Talk (depuis la barre de notifs système) ─
      if (_isTalkInviteNotification(data)) {
        _openTalkGroupCallScreen(
          data: data!,
          callerName: event.notification.body ?? 'Appel de groupe',
        );
        return;
      }

      // ─── Clic sur un appel 1-to-1 classique ─────────────────────────────
      if (!_isCallNotification(data)) return;

      _openIncomingCallScreen(
        callId: _parseCallId(
          raw: data?['call_id'],
          fallback: const Uuid().v4(),
        ),
        callerId: _parseUserId(data?['caller_id']),
        callerName: event.notification.body ?? 'Appel entrant',
        isVideo: _isVideoCall(data),
      );
    });

    _isInitialized = true;
  }

  // ─── Détection du type de notification ────────────────────────────────────

  bool _isCallNotification(Map<String, dynamic>? data) {
    return data != null && data['type'] == 'call';
  }

  /// Retourne true si c'est une invitation à rejoindre un salon Nextcloud Talk.
  bool _isTalkInviteNotification(Map<String, dynamic>? data) {
    return data != null && data['type'] == 'talk_invite';
  }

  bool _isVideoCall(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['is_video'] == true || data['call_type'] == 'video';
  }

  int? _parseUserId(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String _parseCallId({required dynamic raw, required String fallback}) {
    final value = raw?.toString().trim() ?? '';
    return value.isNotEmpty ? value : fallback;
  }

  // ─── Appel 1-to-1 : Affichage CallKit natif ──────────────────────────────

  void _showIncomingCallKit({
    required Map<String, dynamic> data,
    required String? body,
  }) {
    final callId = _parseCallId(
      raw: data['call_id'],
      fallback: const Uuid().v4(),
    );
    final callerId = _parseUserId(data['caller_id']);
    final callerName = body ?? 'Appel entrant';
    final isVideo = _isVideoCall(data);

    _callKit.showIncomingCall(
      uuid: callId,
      callerName: callerName,
      callerAvatar: data['avatar']?.toString() ?? '',
      isVideo: isVideo,
      extra: {
        'callId': callId,
        'callerId': callerId,
        'callerName': callerName,
        'isVideo': isVideo,
      },
    );
  }

  void _handleCallAccept(String uuid, Map<String, dynamic>? extra) {
    _openIncomingCallScreen(
      callId: _parseCallId(raw: extra?['callId'], fallback: uuid),
      callerId: _parseUserId(extra?['callerId']),
      callerName: extra?['callerName']?.toString() ?? 'Appel entrant',
      isVideo: extra?['isVideo'] == true || extra?['isVideo'] == 'true',
    );
  }

  Future<void> _handleCallDecline(
    String uuid,
    Map<String, dynamic>? extra,
  ) async {
    final callId = _parseCallId(raw: extra?['callId'], fallback: uuid);

    try {
      final api = await ApiService.getInstance();
      await api.rejectCall(callId);
    } catch (e) {
      debugPrint('Call reject sync failed: $e');
    }

    try {
      await _callKit.endCall(uuid);
    } catch (e) {
      debugPrint('CallKit endCall failed: $e');
    }
  }

  Future<void> _handleCallEnded(
    String uuid,
    Map<String, dynamic>? extra,
  ) async {
    try {
      await _callKit.endCall(uuid);
    } catch (e) {
      debugPrint('CallKit endCall failed: $e');
    }
  }

  void _openIncomingCallScreen({
    required String callId,
    required int? callerId,
    required String callerName,
    required bool isVideo,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator unavailable, cannot open call screen for $callId');
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          recipientId: callerId,
          recipientName: callerName,
          isVideo: isVideo,
          isIncoming: true,
          offerSdp: '',
        ),
      ),
    );
  }

  // ─── Invitation Talk (Nextcloud Talk HPB) ─────────────────────────────────

  /// Affiche une bannière "Rejoindre ?" quand l'invitation arrive en foreground.
  void _showTalkInviteBanner({
    required Map<String, dynamic> data,
    required String? body,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final context = navigator.overlay?.context;
    if (context == null) return;

    final roomToken = data['room_token']?.toString() ?? '';
    if (roomToken.isEmpty) {
      debugPrint('[IncomingCallService] talk_invite sans room_token, ignoré.');
      return;
    }

    final callerName = body ?? 'Appel de groupe entrant';
    final isVideo = _isVideoCall(data);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.mic,
              color: Colors.redAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isVideo ? 'Appel vidéo de groupe' : 'Appel audio de groupe',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          callerName,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Refuser',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(isVideo ? Icons.videocam : Icons.mic, size: 18),
            label: const Text('Rejoindre'),
            onPressed: () {
              Navigator.pop(ctx);
              _openTalkGroupCallScreen(data: data, callerName: callerName);
            },
          ),
        ],
      ),
    );
  }

  /// Ouvre directement `GroupCallScreen` en mode "rejoindre" avec le room_token.
  void _openTalkGroupCallScreen({
    required Map<String, dynamic> data,
    required String callerName,
  }) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        '[IncomingCallService] Navigator unavailable pour Talk invite',
      );
      return;
    }

    final roomToken = data['room_token']?.toString() ?? '';
    final groupId = _parseUserId(data['group_id']);
    final isVideo = _isVideoCall(data);
    final groupName = data['group_name']?.toString() ?? callerName;

    if (roomToken.isEmpty) {
      debugPrint('[IncomingCallService] room_token manquant dans talk_invite.');
      return;
    }

    debugPrint(
      '[IncomingCallService] Ouverture GroupCallScreen Talk: token=$roomToken',
    );

    navigator.push(
      MaterialPageRoute(
        builder: (_) => GroupCallScreen(
          callId: roomToken, // room_token Nextcloud Talk (utilisé comme callId)
          groupId: groupId,
          groupName: groupName,
          isVideo: isVideo,
          isIncoming: true, // Mode "rejoindre" (pas créer)
        ),
      ),
    );
  }
}
