import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';
import 'webrtc_config_service.dart';

class CallService {
  final ApiService apiService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? currentCallId;
  Timer? _pollTimer;
  Timer? _statsTimer;
  Timer? _iceRestartDebounceTimer;
  String? _lastPollTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isRestartingIce = false;
  int _pollFailureCount = 0;
  final Set<String> _appliedRemoteCandidates = <String>{};
  String? _appliedRemoteOfferSdp;
  String? _appliedRemoteAnswerSdp;
  int _lastInboundBytesReceived = -1;
  int _stalledMediaPollCount = 0;
  String _lastConnectionState = '';
  String _lastIceConnectionState = '';
  bool _hasNotifiedConnected = false;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  VoidCallback? onCallConnected;
  Function(String)? onCallEnded;
  Function(String)? onCallRejected;
  Function(String)? onNetworkChange;

  CallService({required this.apiService});

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': [],
    },
  };

  String _candidateTypeFromSdp(String? candidate) {
    if (candidate == null) return 'unknown';
    if (candidate.contains(' typ relay')) return 'relay';
    if (candidate.contains(' typ srflx')) return 'srflx';
    if (candidate.contains(' typ prflx')) return 'prflx';
    if (candidate.contains(' typ host')) return 'host';
    return 'unknown';
  }

  String _normalizeRemoteSdp(String? sdp) {
    if (sdp == null) return '';
    final trimmed = sdp.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return '';
    }
    return sdp.endsWith('\n') ? sdp : '$sdp\r\n';
  }

  bool _sameNormalizedSdp(String? left, String? right) {
    final normalizedLeft = _normalizeRemoteSdp(left);
    final normalizedRight = _normalizeRemoteSdp(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return false;
    }
    return normalizedLeft == normalizedRight;
  }

  void _scheduleIceRestart({
    required String reason,
    Duration delay = const Duration(milliseconds: 1200),
  }) {
    if (currentCallId == null || _peerConnection == null) return;

    _iceRestartDebounceTimer?.cancel();
    _iceRestartDebounceTimer = Timer(delay, () async {
      if (currentCallId == null ||
          _peerConnection == null ||
          _isRestartingIce) {
        return;
      }

      debugPrint(
        '[WebRTC][private] scheduling ICE restart reason=$reason call=$currentCallId',
      );
      onNetworkChange?.call('Reconnexion en cours...');
      await _restartIce();
    });
  }

  Future<void> _handleRemoteOffer(String? rawOfferSdp) async {
    final normalizedOfferSdp = _normalizeRemoteSdp(rawOfferSdp);
    if (normalizedOfferSdp.isEmpty ||
        _peerConnection == null ||
        currentCallId == null) {
      return;
    }

    final localDesc = await _peerConnection!.getLocalDescription();
    final localType = localDesc?.type?.toLowerCase();
    if (localType == 'offer' &&
        _sameNormalizedSdp(localDesc?.sdp, normalizedOfferSdp)) {
      debugPrint(
        '[WebRTC][private] ignoring echoed local offer call=$currentCallId',
      );
      _appliedRemoteOfferSdp = normalizedOfferSdp;
      return;
    }

    if (localType == 'offer') {
      debugPrint(
        '[WebRTC][private] deferring remote offer while local offer pending call=$currentCallId',
      );
      return;
    }

    if (_appliedRemoteOfferSdp == normalizedOfferSdp) {
      return;
    }

    final currentRemoteDesc = await _peerConnection!.getRemoteDescription();
    if (currentRemoteDesc?.type?.toLowerCase() == 'offer' &&
        _sameNormalizedSdp(currentRemoteDesc?.sdp, normalizedOfferSdp)) {
      _appliedRemoteOfferSdp = normalizedOfferSdp;
      return;
    }

    try {
      debugPrint('[WebRTC][private] applying remote offer call=$currentCallId');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(normalizedOfferSdp, 'offer'),
      );
      _appliedRemoteOfferSdp = normalizedOfferSdp;

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _appliedRemoteAnswerSdp = null;
      await apiService.answerCall(currentCallId!, answer.sdp!);
      debugPrint('[WebRTC][private] remote offer answered call=$currentCallId');
    } catch (e) {
      debugPrint(
        '[WebRTC][private] setRemoteDescription offer failed during polling: $e\nSDP: $normalizedOfferSdp',
      );
    }
  }

  Future<void> _handleRemoteAnswer(String? rawAnswerSdp) async {
    final answerSdp = _normalizeRemoteSdp(rawAnswerSdp);
    if (answerSdp.isEmpty || _peerConnection == null) {
      return;
    }

    if (_appliedRemoteAnswerSdp == answerSdp) {
      return;
    }

    final currentDesc = await _peerConnection!.getRemoteDescription();
    if (currentDesc?.type?.toLowerCase() == 'answer' &&
        _sameNormalizedSdp(currentDesc?.sdp, answerSdp)) {
      _appliedRemoteAnswerSdp = answerSdp;
      return;
    }

    final localDesc = await _peerConnection!.getLocalDescription();
    final localType = localDesc?.type?.toLowerCase();
    if (localType != 'offer') {
      debugPrint(
        '[WebRTC][private] ignoring stale remote answer call=$currentCallId localType=$localType',
      );
      _appliedRemoteAnswerSdp = answerSdp;
      return;
    }

    try {
      debugPrint(
        '[WebRTC][private] applying remote answer call=$currentCallId',
      );
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      _appliedRemoteAnswerSdp = answerSdp;
    } catch (e) {
      debugPrint(
        '[WebRTC][private] setRemoteDescription answer failed: $e\nSDP: $answerSdp',
      );
    }
  }

  void _startStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _logStatsSnapshot();
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  String _stringValue(Map<String, dynamic> values, String key) {
    final value = values[key];
    return value == null ? '' : value.toString();
  }

  Map<String, dynamic> _valuesOf(StatsReport? report) {
    return report?.values.cast<String, dynamic>() ?? <String, dynamic>{};
  }

  StatsReport? _findSelectedCandidatePair(List<StatsReport> reports) {
    final byId = <String, StatsReport>{
      for (final report in reports) report.id: report,
    };

    for (final report in reports) {
      if (report.type == 'transport') {
        final selectedPairId = report.values['selectedCandidatePairId'];
        if (selectedPairId != null) {
          final selected = byId[selectedPairId.toString()];
          if (selected != null) return selected;
        }
      }
    }

    for (final report in reports) {
      if (report.type != 'candidate-pair') continue;
      final values = report.values.cast<String, dynamic>();
      final selected = _stringValue(values, 'selected');
      final nominated = _stringValue(values, 'nominated');
      final state = _stringValue(values, 'state');
      if (selected == 'true' || nominated == 'true' || state == 'succeeded') {
        return report;
      }
    }

    return null;
  }

  Future<void> _logStatsSnapshot() async {
    final pc = _peerConnection;
    if (pc == null || currentCallId == null) return;

    try {
      final reports = await pc.getStats();
      if (reports.isEmpty) return;

      final byId = <String, StatsReport>{
        for (final report in reports) report.id: report,
      };

      final selectedPair = _findSelectedCandidatePair(reports);
      if (selectedPair != null) {
        final selectedPairValues = selectedPair.values.cast<String, dynamic>();
        final localCandidateId = _stringValue(
          selectedPairValues,
          'localCandidateId',
        );
        final remoteCandidateId = _stringValue(
          selectedPairValues,
          'remoteCandidateId',
        );
        final localCandidate = byId[localCandidateId];
        final remoteCandidate = byId[remoteCandidateId];
        final localValues = _valuesOf(localCandidate);
        final remoteValues = _valuesOf(remoteCandidate);

        debugPrint(
          '[WebRTC][private][stats] pair state=${_stringValue(selectedPairValues, 'state')} '
          'nominated=${_stringValue(selectedPairValues, 'nominated')} '
          'writable=${_stringValue(selectedPairValues, 'writable')} '
          'bytesSent=${_stringValue(selectedPairValues, 'bytesSent')} '
          'bytesReceived=${_stringValue(selectedPairValues, 'bytesReceived')} '
          'rtt=${_stringValue(selectedPairValues, 'currentRoundTripTime')} '
          'local=${_stringValue(localValues, 'candidateType')}/${_stringValue(localValues, 'protocol')}/${_stringValue(localValues, 'address')}:${_stringValue(localValues, 'port')} '
          'remote=${_stringValue(remoteValues, 'candidateType')}/${_stringValue(remoteValues, 'protocol')}/${_stringValue(remoteValues, 'address')}:${_stringValue(remoteValues, 'port')} '
          'call=$currentCallId',
        );
      } else {
        final candidatePairs = reports
            .where((report) => report.type == 'candidate-pair')
            .map((report) {
              final values = report.values.cast<String, dynamic>();
              return 'state=${_stringValue(values, 'state')} '
                  'nominated=${_stringValue(values, 'nominated')} '
                  'selected=${_stringValue(values, 'selected')} '
                  'writable=${_stringValue(values, 'writable')} '
                  'bytesSent=${_stringValue(values, 'bytesSent')} '
                  'bytesReceived=${_stringValue(values, 'bytesReceived')}';
            })
            .take(4)
            .join(' || ');
        debugPrint(
          '[WebRTC][private][stats] no_selected_pair reports=${reports.length} '
          'pairs=$candidatePairs call=$currentCallId',
        );
      }

      var totalInboundBytes = 0;
      for (final report in reports) {
        if (report.type != 'inbound-rtp') continue;
        final values = report.values.cast<String, dynamic>();
        final kind = _stringValue(values, 'kind').isNotEmpty
            ? _stringValue(values, 'kind')
            : _stringValue(values, 'mediaType');
        totalInboundBytes +=
            int.tryParse(_stringValue(values, 'bytesReceived')) ?? 0;
        debugPrint(
          '[WebRTC][private][stats] inbound kind=$kind '
          'bytesReceived=${_stringValue(values, 'bytesReceived')} '
          'packetsReceived=${_stringValue(values, 'packetsReceived')} '
          'packetsLost=${_stringValue(values, 'packetsLost')} '
          'jitter=${_stringValue(values, 'jitter')} '
          'framesDecoded=${_stringValue(values, 'framesDecoded')} '
          'decoder=${_stringValue(values, 'decoderImplementation')} '
          'trackId=${_stringValue(values, 'trackIdentifier')} '
          'call=$currentCallId',
        );
      }

      final hasSelectedPair = selectedPair != null;
      final isTransportNegotiating =
          _lastConnectionState.contains('connecting') ||
          _lastIceConnectionState.contains('checking');
      final mediaFlowing =
          totalInboundBytes > 0 &&
          (_lastInboundBytesReceived < 0 ||
              totalInboundBytes > _lastInboundBytesReceived);

      if (mediaFlowing) {
        _stalledMediaPollCount = 0;
      } else if (_remoteStream != null &&
          (hasSelectedPair || isTransportNegotiating)) {
        _stalledMediaPollCount++;
        debugPrint(
          '[WebRTC][private][stats] media stalled totalInboundBytes=$totalInboundBytes '
          'selectedPair=$hasSelectedPair negotiating=$isTransportNegotiating '
          'stalledPolls=$_stalledMediaPollCount call=$currentCallId',
        );
        if (_stalledMediaPollCount >= 3 && !_isRestartingIce) {
          _scheduleIceRestart(
            reason: 'media-stalled',
            delay: const Duration(milliseconds: 300),
          );
        }
      }

      _lastInboundBytesReceived = totalInboundBytes;
    } catch (e) {
      debugPrint('[WebRTC][private][stats] error=$e call=$currentCallId');
    }
  }

  void _attachPeerConnectionDebugHandlers(RTCPeerConnection pc) {
    pc.onConnectionState = (state) {
      debugPrint(
        '[WebRTC][private] connectionState=$state call=$currentCallId',
      );
      final normalized = state.toString().toLowerCase();
      _lastConnectionState = normalized;
      if (normalized.contains('connecting') ||
          normalized.contains('connected')) {
        _startStatsPolling();
        if (normalized.contains('connected')) {
          _notifyCallConnected();
        }
      } else if (normalized.contains('failed') ||
          normalized.contains('closed') ||
          normalized.contains('disconnected')) {
        _stopStatsPolling();
      }
    };
    pc.onIceConnectionState = (state) {
      debugPrint(
        '[WebRTC][private] iceConnectionState=$state call=$currentCallId',
      );
      final normalized = state.toString().toLowerCase();
      _lastIceConnectionState = normalized;
      if (normalized.contains('checking') ||
          normalized.contains('connected') ||
          normalized.contains('completed')) {
        _iceRestartDebounceTimer?.cancel();
        _startStatsPolling();
        if (normalized.contains('connected') ||
            normalized.contains('completed')) {
          _notifyCallConnected();
          onNetworkChange?.call('');
        }
      } else if (normalized.contains('failed') ||
          normalized.contains('closed') ||
          normalized.contains('disconnected')) {
        _stopStatsPolling();
        if (normalized.contains('failed') ||
            normalized.contains('disconnected')) {
          _scheduleIceRestart(reason: 'ice-state-$state');
        }
      }
    };
    pc.onIceGatheringState = (state) {
      debugPrint(
        '[WebRTC][private] iceGatheringState=$state call=$currentCallId',
      );
    };
    pc.onSignalingState = (state) {
      debugPrint('[WebRTC][private] signalingState=$state call=$currentCallId');
    };
  }

  void _notifyCallConnected() {
    if (_hasNotifiedConnected) return;
    _hasNotifiedConnected = true;
    onCallConnected?.call();
  }

  /// Initier un appel audio
  Future<String> initiateAudioCall(int recipientId) async {
    return _initiateCall(recipientId, 'audio');
  }

  /// Initier un appel vidéo
  Future<String> initiateVideoCall(int recipientId) async {
    return _initiateCall(recipientId, 'video');
  }

  Future<String> _initiateCall(int recipientId, String callType) async {
    try {
      // Créer le peer connection
      final rtcConfiguration = await WebRtcConfigService.buildRtcConfiguration(
        apiService,
      );
      _peerConnection = await createPeerConnection(rtcConfiguration);
      _attachPeerConnectionDebugHandlers(_peerConnection!);

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      debugPrint(
        '[WebRTC][private] local stream audio=${_localStream!.getAudioTracks().length} video=${_localStream!.getVideoTracks().length} callType=$callType',
      );

      // Ajouter les tracks au peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Notifier le stream local
      onLocalStream?.call(_localStream!);

      // Écouter les ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          debugPrint(
            '[WebRTC][private] local candidate type=${_candidateTypeFromSdp(candidate.candidate)} mid=${candidate.sdpMid}',
          );
          _sendIceCandidate(candidate);
        }
      };

      // Écouter le stream distant
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint(
            '[WebRTC][private] remote track kind=${event.track.kind} audio=${_remoteStream!.getAudioTracks().length} video=${_remoteStream!.getVideoTracks().length}',
          );
          onRemoteStream?.call(_remoteStream!);
        }
      };

      // Créer l'offre
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Envoyer l'offre au serveur
      final response = await apiService.initiateCall(
        recipientId,
        callType,
        offer.sdp!,
      );

      currentCallId = response['call_id'];

      // Commencer le polling pour les mises à jour
      _startPolling();

      // Écouter les changements de connectivité
      _startConnectivityMonitoring();

      return currentCallId!;
    } catch (e) {
      await cleanup();
      rethrow;
    }
  }

  /// Répondre à un appel
  Future<void> answerCall(
    String callId,
    String offerSdp,
    String callType,
  ) async {
    try {
      final trimmedSdp = offerSdp.trim();
      if (trimmedSdp.isEmpty || trimmedSdp == 'null') {
        throw Exception('offer_sdp manquant');
      }
      final normalizedOfferSdp = offerSdp.endsWith('\n')
          ? offerSdp
          : '$offerSdp\r\n';

      currentCallId = callId;

      // Créer le peer connection
      final rtcConfiguration = await WebRtcConfigService.buildRtcConfiguration(
        apiService,
      );
      _peerConnection = await createPeerConnection(rtcConfiguration);
      _attachPeerConnectionDebugHandlers(_peerConnection!);

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      debugPrint(
        '[WebRTC][private] answer local stream audio=${_localStream!.getAudioTracks().length} video=${_localStream!.getVideoTracks().length} callType=$callType',
      );

      // Ajouter les tracks
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      onLocalStream?.call(_localStream!);

      // Écouter les ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          debugPrint(
            '[WebRTC][private] local candidate type=${_candidateTypeFromSdp(candidate.candidate)} mid=${candidate.sdpMid}',
          );
          _sendIceCandidate(candidate);
        }
      };

      // Écouter le stream distant
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint(
            '[WebRTC][private] remote track kind=${event.track.kind} audio=${_remoteStream!.getAudioTracks().length} video=${_remoteStream!.getVideoTracks().length}',
          );
          onRemoteStream?.call(_remoteStream!);
        }
      };

      try {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(normalizedOfferSdp, 'offer'),
        );
        _appliedRemoteOfferSdp = normalizedOfferSdp;
      } catch (e) {
        debugPrint(
          '[WebRTC][private] setRemoteDescription offer failed: $e\nSDP: $normalizedOfferSdp',
        );
        throw Exception('Offre SDP invalide ou malformée.');
      }

      // Créer la réponse
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Envoyer la réponse au serveur
      await apiService.answerCall(callId, answer.sdp!);

      // Commencer le polling
      _startPolling();

      // Écouter les changements de connectivité
      _startConnectivityMonitoring();
    } catch (e) {
      await cleanup();
      rethrow;
    }
  }

  /// Rejeter un appel
  Future<void> rejectCall(String callId) async {
    await apiService.rejectCall(callId);
    await cleanup();
  }

  /// Terminer un appel
  Future<void> endCall() async {
    if (currentCallId != null) {
      await apiService.endCall(currentCallId!);
    }
    await cleanup();
  }

  /// Basculer le micro
  void toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  /// Basculer la caméra
  void toggleCamera() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  /// Changer de caméra (avant/arrière)
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  /// Envoyer un ICE candidate
  Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
    if (currentCallId == null) return;

    try {
      await apiService.sendIceCandidate(currentCallId!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    } catch (e) {
      debugPrint('Error sending ICE candidate: $e');
    }
  }

  /// Polling pour les mises à jour
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollLoop();
  }

  /// Polling récursif : attend la fin de la requête avant de relancer
  /// Évite l'accumulation des ticks (TimerSignificantlyOverdue)
  void _pollLoop() async {
    if (currentCallId == null) return;

    var nextDelay = const Duration(seconds: 2);

    try {
      final updates = await apiService.pollCallUpdates(
        currentCallId!,
        _lastPollTime,
      );
      _pollFailureCount = 0;

      _lastPollTime = updates['timestamp'];

      final call = updates['call'];
      if (call == null) {
        _scheduleNextPoll();
        return;
      }

      final status = call['status']?.toString();
      if (status == 'ended') {
        onCallEnded?.call('Call ended by other party');
        await cleanup();
        return; // Stopper le polling
      } else if (status == 'rejected') {
        onCallRejected?.call('Call rejected');
        await cleanup();
        return; // Stopper le polling
      } else if (status == 'active') {
        if (call['offer_sdp'] != null) {
          await _handleRemoteOffer(call['offer_sdp']?.toString());
        }

        if (call['answer_sdp'] != null) {
          await _handleRemoteAnswer(call['answer_sdp']?.toString());
        }
      }

      // Traiter les ICE candidates
      final candidates = updates['ice_candidates'] as List? ?? [];
      for (var candidateData in candidates) {
        final candidate = jsonDecode(candidateData['candidate']);
        final candidateKey =
            '${candidateData['id'] ?? ''}|${candidate['candidate'] ?? ''}|${candidate['sdpMid'] ?? ''}|${candidate['sdpMLineIndex'] ?? ''}';
        if (!_appliedRemoteCandidates.add(candidateKey)) {
          continue;
        }
        debugPrint(
          '[WebRTC][private] remote candidate type=${_candidateTypeFromSdp(candidate['candidate']?.toString())} from=${candidateData['user_id']}',
        );
        await _peerConnection?.addCandidate(
          RTCIceCandidate(
            candidate['candidate'],
            candidate['sdpMid'],
            candidate['sdpMLineIndex'],
          ),
        );
      }
    } catch (e) {
      debugPrint('Polling error: $e');
      _pollFailureCount++;
      if (e.toString().contains('HTTP 429')) {
        nextDelay = Duration(seconds: 6 + (_pollFailureCount > 3 ? 4 : 0));
        debugPrint(
          '[WebRTC][private] poll backoff due to rate limit delay=${nextDelay.inSeconds}s call=$currentCallId',
        );
      } else if (_pollFailureCount > 1) {
        nextDelay = const Duration(seconds: 3);
      }
    }

    _scheduleNextPoll(nextDelay);
  }

  void _scheduleNextPoll([Duration delay = const Duration(seconds: 2)]) {
    if (currentCallId == null) return;
    _pollTimer = Timer(delay, _pollLoop);
  }

  /// Surveiller les changements de connectivité
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    bool isFirstEvent = true;

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (List<ConnectivityResult> result) async {
          // Ignorer le premier événement (initialisation)
          if (isFirstEvent) {
            isFirstEvent = false;
            return;
          }

          if (currentCallId == null || _peerConnection == null) return;

          // Vérifier si on a une connexion
          final hasConnection = result.any((r) => r != ConnectivityResult.none);

          if (hasConnection && !_isRestartingIce) {
            debugPrint(
              'Network change detected, waiting before ICE restart...',
            );
            _scheduleIceRestart(reason: 'connectivity-$result');
          }
        },
        onError: (e) {
          debugPrint('Connectivity stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('Connectivity API not available: $e');
    }
  }

  /// Redémarrer ICE après un changement de réseau
  Future<void> _restartIce() async {
    if (_isRestartingIce || currentCallId == null || _peerConnection == null) {
      return;
    }

    _isRestartingIce = true;

    try {
      // Créer une nouvelle offre avec iceRestart
      final constraints = {'iceRestart': true};
      RTCSessionDescription offer = await _peerConnection!.createOffer(
        constraints,
      );
      await _peerConnection!.setLocalDescription(offer);

      // Envoyer la nouvelle offre au serveur
      await apiService.restartIce(currentCallId!, offer.sdp!);

      debugPrint('ICE restart successful');
    } catch (e) {
      debugPrint('ICE restart failed: $e');
    } finally {
      _isRestartingIce = false;
    }
  }

  /// Nettoyer les ressources
  Future<void> cleanup() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopStatsPolling();
    _iceRestartDebounceTimer?.cancel();
    _iceRestartDebounceTimer = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    debugPrint('[WebRTC][private] cleanup call=$currentCallId');
    currentCallId = null;
    _lastPollTime = null;
    _isRestartingIce = false;
    _pollFailureCount = 0;
    _lastInboundBytesReceived = -1;
    _stalledMediaPollCount = 0;
    _lastConnectionState = '';
    _lastIceConnectionState = '';
    _hasNotifiedConnected = false;
    _appliedRemoteCandidates.clear();
    _appliedRemoteOfferSdp = null;
    _appliedRemoteAnswerSdp = null;
  }

  /// Obtenir l'historique des appels
  Future<List<dynamic>> getCallHistory({int page = 1}) async {
    return await apiService.getCallHistory(page: page);
  }
}
