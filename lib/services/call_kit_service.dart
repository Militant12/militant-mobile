import 'dart:async';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

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
    // CallKit désactivé
  }

  /// Arrêter l'appel (STUB)
  Future<void> endCall(String uuid) async {
    // CallKit désactivé
  }

  /// Nettoyer tous les appels (STUB)
  Future<void> endAllCalls() async {
    // CallKit désactivé
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}
