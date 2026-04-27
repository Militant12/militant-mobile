import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  static const MethodChannel _channel = MethodChannel(
    'com.militant.militant_flutter/calls',
  );

  bool _isInitialized = false;

  /// Initialiser les écouteurs d'événements (STUB)
  void init({
    required Function(String uuid, Map<String, dynamic>? extra) onAccept,
    required Function(String uuid, Map<String, dynamic>? extra) onDecline,
    Function(String uuid, Map<String, dynamic>? extra)? onEnded,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;
    // CallKit désactivé
  }

  /// Afficher l'écran d'appel entrant (STUB)
  Future<void> showIncomingCall({
    required String uuid,
    required String callerName,
    required String callerAvatar,
    String? handle,
    bool isVideo = false,
    Map<String, dynamic>? extra,
  }) async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await _channel.invokeMethod('showIncomingCall', {
        'callId': uuid,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'handle': handle,
        'isVideo': isVideo,
        ...?extra,
      });
    }
  }

  /// Arrêter l'appel (STUB)
  Future<void> endCall(String uuid) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await _channel.invokeMethod('endCall', {'callId': uuid});
    }
  }

  /// Nettoyer tous les appels (STUB)
  Future<void> endAllCalls() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      await _channel.invokeMethod('endAllCalls');
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}
