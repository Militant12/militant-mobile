import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api_service.dart';
import 'call_service.dart';
import 'language_service.dart';

enum PrivateCallTerminalState { none, localEnded, remoteEnded, rejected, error }

class PrivateCallSession extends ChangeNotifier {
  PrivateCallSession._internal();

  static final PrivateCallSession instance = PrivateCallSession._internal();

  ApiService? _apiService;
  CallService? _callService;
  bool _isStarting = false;

  String? callId;
  int? recipientId;
  String recipientName = '';
  String? recipientAvatar;
  bool isVideo = false;
  bool isIncoming = false;
  String? offerSdp;

  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool isMuted = false;
  bool isCameraOff = false;
  bool isConnected = false;
  bool isRinging = true;
  String callStatus = LanguageService.instance.translate('call_connecting');
  String? errorMessage;
  PrivateCallTerminalState terminalState = PrivateCallTerminalState.none;

  MediaStream? get localStream => _callService?.localStream ?? _localStream;
  MediaStream? get remoteStream => _callService?.remoteStream ?? _remoteStream;
  bool get isStarting => _isStarting;

  void _log(String message) {
    debugPrint('[WebRTC][private][session] $message');
  }

  String _normalizeOfferSdp(String? sdp) {
    final normalized = (sdp ?? '').trim();
    if (normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'undefined') {
      return '';
    }
    return normalized;
  }

  String _extractOfferSdpFromCallData(Map<String, dynamic>? data) {
    if (data == null) return '';

    final direct = _normalizeOfferSdp(
      data['offer_sdp']?.toString() ??
          data['offerSdp']?.toString() ??
          data['offer']?.toString(),
    );
    if (direct.isNotEmpty) {
      return direct;
    }

    final nestedCall = data['call'];
    if (nestedCall is Map) {
      return _extractOfferSdpFromCallData(
        Map<String, dynamic>.from(nestedCall),
      );
    }

    return '';
  }

  Future<String> _resolveIncomingOfferSdp(String incomingCallId) async {
    final notificationSdp = _normalizeOfferSdp(offerSdp);
    if (notificationSdp.isNotEmpty) {
      _log('using offer_sdp from payload callId=$incomingCallId');
      return notificationSdp;
    }

    for (var attempt = 1; attempt <= 4; attempt++) {
      try {
        final callInfo = await _apiService!.getCallInfo(incomingCallId);
        final resolved = _extractOfferSdpFromCallData(callInfo);
        if (resolved.isNotEmpty) {
          _log(
            'resolved offer_sdp via getCallInfo attempt=$attempt callId=$incomingCallId',
          );
          return resolved;
        }
        _log(
          'offer_sdp still missing via getCallInfo attempt=$attempt callId=$incomingCallId keys=${callInfo.keys.join(',')}',
        );
      } catch (e) {
        _log(
          'getCallInfo failed attempt=$attempt callId=$incomingCallId error=$e',
        );
      }

      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }

    try {
      final history = await _apiService!.getCallHistory(page: 1);
      for (final item in history) {
        if (item is! Map) continue;
        final callData = Map<String, dynamic>.from(item);
        final candidateCallId = callData['call_id']?.toString().trim();
        if (candidateCallId != incomingCallId) continue;

        final resolved = _extractOfferSdpFromCallData(callData);
        if (resolved.isNotEmpty) {
          _log('resolved offer_sdp via getCallHistory callId=$incomingCallId');
          return resolved;
        }
      }
    } catch (e) {
      _log('getCallHistory fallback failed callId=$incomingCallId error=$e');
    }

    return '';
  }

  bool matches({
    required String? nextCallId,
    required int? nextRecipientId,
    required bool nextIsVideo,
    required bool nextIsIncoming,
  }) {
    if (_isCallSettled) {
      return false;
    }

    if (_callService == null && callId == null && recipientId == null) {
      return false;
    }

    if (isIncoming || nextIsIncoming) {
      return callId != null && nextCallId != null && callId == nextCallId;
    }

    return !isIncoming &&
        !nextIsIncoming &&
        recipientId == nextRecipientId &&
        isVideo == nextIsVideo;
  }

  Future<void> configure({
    required String? callId,
    required int? recipientId,
    required String recipientName,
    required String? recipientAvatar,
    required bool isVideo,
    required bool isIncoming,
    required String? offerSdp,
  }) async {
    _log(
      'configure callId=$callId recipientId=$recipientId incoming=$isIncoming video=$isVideo currentCallId=${this.callId} settled=$_isCallSettled',
    );
    if (!matches(
      nextCallId: callId,
      nextRecipientId: recipientId,
      nextIsVideo: isVideo,
      nextIsIncoming: isIncoming,
    )) {
      await _disposeActiveSession('reconfigure');
      _resetState();
    }

    this.callId = callId ?? this.callId;
    this.recipientId = recipientId;
    this.recipientName = recipientName;
    this.recipientAvatar = recipientAvatar;
    this.isVideo = isVideo;
    this.isIncoming = isIncoming;
    this.offerSdp = offerSdp;

    if (!_isCallSettled) {
      callStatus = LanguageService.instance.translate(
        isIncoming ? 'call_connecting' : 'call_ringing',
      );
      isRinging = !isConnected;
    }

    _syncStateFromService();
    notifyListeners();
  }

  Future<void> ensureStarted() async {
    if (_isStarting) return;
    _log(
      'ensureStarted callId=$callId recipientId=$recipientId incoming=$isIncoming serviceExists=${_callService != null}',
    );

    if (_callService != null &&
        (_callService!.currentCallId != null ||
            localStream != null ||
            remoteStream != null)) {
      _syncStateFromService();
      notifyListeners();
      return;
    }

    _isStarting = true;
    errorMessage = null;
    terminalState = PrivateCallTerminalState.none;
    notifyListeners();

    try {
      _apiService ??= await ApiService.getInstance();
      final service = CallService(apiService: _apiService!);
      _bindService(service);
      _callService = service;

      if (isIncoming) {
        final incomingCallId = callId;
        if (incomingCallId == null || incomingCallId.isEmpty) {
          throw Exception('call_id manquant');
        }

        final remoteSdp = await _resolveIncomingOfferSdp(incomingCallId);
        if (remoteSdp.isEmpty) {
          throw Exception('offer_sdp manquant');
        }

        callStatus = LanguageService.instance.translate('call_connecting');
        _log('answering incoming callId=$incomingCallId');
        await service.answerCall(
          incomingCallId,
          remoteSdp,
          isVideo ? 'video' : 'audio',
        );
      } else {
        callStatus = LanguageService.instance.translate('call_ringing');
        _log('starting outgoing call recipientId=$recipientId video=$isVideo');
        final startedCallId = isVideo
            ? await service.initiateVideoCall(recipientId!)
            : await service.initiateAudioCall(recipientId!);
        callId = startedCallId;
        _log('outgoing call started callId=$callId');
      }

      _syncStateFromService();
      notifyListeners();
    } catch (e) {
      _log('ensureStarted error=$e');
      errorMessage = _humanizeError(e);
      callStatus = LanguageService.instance.translate('call_ended');
      terminalState = PrivateCallTerminalState.error;
      await _disposeActiveSession('ensureStarted-error');
      notifyListeners();
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  Future<void> endCall() async {
    _log('endCall invoked stack=${StackTrace.current}');
    final service = _callService;
    if (service != null) {
      try {
        await service.endCall();
      } catch (e) {
        debugPrint('Erreur endCall: $e');
      }
    }

    callStatus = LanguageService.instance.translate('call_ended');
    terminalState = PrivateCallTerminalState.localEnded;
    await _disposeActiveSession('local-end');
    notifyListeners();
  }

  Future<void> rejectCall() async {
    final currentId = callId;
    final service = _callService;

    try {
      if (service != null && currentId != null) {
        await service.rejectCall(currentId);
      } else if (currentId != null) {
        _apiService ??= await ApiService.getInstance();
        await _apiService!.rejectCall(currentId);
      }
    } catch (e) {
      debugPrint('Erreur rejectCall: $e');
    }

    callStatus = LanguageService.instance.translate('call_rejected');
    terminalState = PrivateCallTerminalState.rejected;
    await _disposeActiveSession('local-reject');
    notifyListeners();
  }

  void toggleMicrophone() {
    _callService?.toggleMicrophone();
    _syncTrackFlags();
    notifyListeners();
  }

  void toggleCamera() {
    _callService?.toggleCamera();
    _syncTrackFlags();
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _callService?.switchCamera();
  }

  void _bindService(CallService service) {
    service.onLocalStream = (stream) {
      _log(
        'local stream audio=${stream.getAudioTracks().length} video=${stream.getVideoTracks().length}',
      );
      _localStream = stream;
      _syncTrackFlags();
      notifyListeners();
    };

    service.onRemoteStream = (stream) {
      _log(
        'remote stream audio=${stream.getAudioTracks().length} video=${stream.getVideoTracks().length}',
      );
      _remoteStream = stream;
      if (!_isCallSettled && !isConnected) {
        callStatus = LanguageService.instance.translate('call_connecting');
      }
      notifyListeners();
    };

    service.onCallConnected = () {
      _log('transport connected');
      isConnected = true;
      isRinging = false;
      if (!_isCallSettled) {
        callStatus = LanguageService.instance.translate('call_active');
      }
      notifyListeners();
    };

    service.onCallEnded = (reason) {
      _log('remote end reason=$reason');
      callStatus = LanguageService.instance.translate('call_ended');
      terminalState = PrivateCallTerminalState.remoteEnded;
      isConnected = false;
      isRinging = false;
      _syncStateFromService();
      notifyListeners();
    };

    service.onCallRejected = (reason) {
      _log('remote reject reason=$reason');
      callStatus = LanguageService.instance.translate('call_rejected');
      terminalState = PrivateCallTerminalState.rejected;
      isConnected = false;
      isRinging = false;
      _syncStateFromService();
      notifyListeners();
    };

    service.onNetworkChange = (message) {
      _log('network change message=$message');
      if (message.trim().isEmpty) {
        callStatus = LanguageService.instance.translate(
          isConnected ? 'call_active' : 'call_connecting',
        );
      } else {
        callStatus = LanguageService.instance.translate(
          'call_network_reconnecting',
        );
      }
      notifyListeners();
    };
  }

  void _syncStateFromService() {
    _localStream = _callService?.localStream ?? _localStream;
    _remoteStream = _callService?.remoteStream ?? _remoteStream;
    callId = _callService?.currentCallId ?? callId;

    _syncTrackFlags();
  }

  void _syncTrackFlags() {
    final local = _callService?.localStream ?? _localStream;
    final audioTracks = local?.getAudioTracks() ?? const <MediaStreamTrack>[];
    final videoTracks = local?.getVideoTracks() ?? const <MediaStreamTrack>[];

    isMuted =
        audioTracks.isNotEmpty && audioTracks.every((track) => !track.enabled);
    isCameraOff =
        videoTracks.isNotEmpty && videoTracks.every((track) => !track.enabled);
  }

  bool get _isCallSettled => terminalState != PrivateCallTerminalState.none;

  Future<void> _disposeActiveSession(String reason) async {
    _log(
      'disposeActiveSession reason=$reason callId=$callId serviceCallId=${_callService?.currentCallId}',
    );
    final service = _callService;
    _callService = null;
    _localStream = null;
    _remoteStream = null;
    isConnected = false;
    isRinging = false;
    _syncTrackFlags();

    if (service != null) {
      try {
        await service.cleanup();
      } catch (e) {
        debugPrint('Erreur cleanup session privée: $e');
      }
    }
  }

  void _resetState() {
    _log('resetState previousCallId=$callId');
    callId = null;
    recipientId = null;
    recipientName = '';
    recipientAvatar = null;
    isVideo = false;
    isIncoming = false;
    offerSdp = null;
    _localStream = null;
    _remoteStream = null;
    isMuted = false;
    isCameraOff = false;
    isConnected = false;
    isRinging = true;
    errorMessage = null;
    terminalState = PrivateCallTerminalState.none;
    callStatus = LanguageService.instance.translate('call_connecting');
  }

  String _humanizeError(Object error) {
    var message = error.toString().replaceAll('Exception: ', '');

    if (message.contains('Permission') || message.contains('permission')) {
      return 'Permission refusée. Veuillez autoriser l\'accès au microphone et à la caméra.';
    }
    if (message.contains('NotFoundError') || message.contains('not found')) {
      return 'Aucun microphone ou caméra trouvé sur cet appareil.';
    }
    if (message.contains('NotAllowedError')) {
      return 'Accès refusé. Veuillez autoriser les permissions dans les paramètres.';
    }
    if (message.contains('offer_sdp manquant')) {
      return 'Impossible de récupérer l’offre de l’appel. Réessaie dans quelques secondes.';
    }

    return message;
  }
}
