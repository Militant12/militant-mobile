import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:uuid/uuid.dart';

import '../screens/call_screen.dart';
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
      if (!_isCallNotification(data)) {
        event.notification.display();
        return;
      }

      event.preventDefault();
      _showIncomingCallKit(
        data: data!,
        body: event.notification.body,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
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

  bool _isCallNotification(Map<String, dynamic>? data) {
    return data != null && data['type'] == 'call';
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

  Future<void> _handleCallEnded(String uuid, Map<String, dynamic>? extra) async {
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
}
