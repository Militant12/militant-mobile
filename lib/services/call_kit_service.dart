import 'dart:async';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  StreamSubscription<CallEvent?>? _eventSubscription;
  bool _isInitialized = false;

  /// Initialiser les écouteurs d'événements
  void init({
    required Function(String uuid, Map<String, dynamic>? extra) onAccept,
    required Function(String uuid, Map<String, dynamic>? extra) onDecline,
    Function(String uuid, Map<String, dynamic>? extra)? onEnded,
  }) {
    if (_isInitialized) return;
    _isInitialized = true;

    _eventSubscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;

      final extra = event.body['extra'] as Map<dynamic, dynamic>?;
      // Convertir Map<dynamic, dynamic> en Map<String, dynamic> si nécessaire
      final Map<String, dynamic>? typedExtra = extra?.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final String callUuid = event.body['id']?.toString() ?? '';
      if (callUuid.isEmpty) return;

      switch (event.event) {
        case Event.actionCallAccept:
          onAccept(callUuid, typedExtra);
          break;
        case Event.actionCallDecline:
          onDecline(callUuid, typedExtra);
          break;
        case Event.actionCallEnded:
          if (onEnded != null) {
            onEnded(callUuid, typedExtra);
          }
          break;
        default:
          break;
      }
    });
  }

  /// Afficher l'écran d'appel entrant
  Future<void> showIncomingCall({
    required String uuid,
    required String callerName,
    required String callerAvatar,
    String? handle,
    bool isVideo = false,
    Map<String, dynamic>? extra,
  }) async {
    final params = CallKitParams(
      id: uuid,
      nameCaller: callerName,
      appName: 'Militant',
      avatar: callerAvatar,
      handle: handle ?? 'Appel entrant...',
      type: isVideo
          ? 1 // 1: Video
          : 0, // 0: Audio
      duration: 30000, // Durée max de sonnerie
      textAccept: 'Accepter',
      textDecline: 'Refuser',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Appel manqué',
        callbackText: 'Rappeler',
      ),
      extra: extra ?? <String, dynamic>{}, // Utiliser les extra passés
      headers: <String, dynamic>{'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        backgroundUrl: 'assets/test.png',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: '',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Arrêter l'appel (sonnerie ou écran)
  Future<void> endCall(String uuid) async {
    await FlutterCallkitIncoming.endCall(uuid);
  }

  /// Nettoyer tous les appels
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _isInitialized = false;
  }
}
