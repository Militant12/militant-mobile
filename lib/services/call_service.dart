import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

class CallService {
  final ApiService apiService;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  String? currentCallId;
  Timer? _pollTimer;
  String? _lastPollTime;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isRestartingIce = false;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallEnded;
  Function(String)? onCallRejected;
  Function(String)? onNetworkChange;

  CallService({required this.apiService});

  // Configuration ICE servers (STUN/TURN)
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Ajoutez vos serveurs TURN ici si nécessaire
    ],
  };

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
      _peerConnection = await createPeerConnection(_iceServers);

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // Ajouter les tracks au peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Notifier le stream local
      onLocalStream?.call(_localStream!);

      // Écouter les ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _sendIceCandidate(candidate);
        }
      };

      // Écouter le stream distant
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
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
      currentCallId = callId;

      // Créer le peer connection
      _peerConnection = await createPeerConnection(_iceServers);

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // Ajouter les tracks
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      onLocalStream?.call(_localStream!);

      // Écouter les ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          _sendIceCandidate(candidate);
        }
      };

      // Écouter le stream distant
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          onRemoteStream?.call(_remoteStream!);
        }
      };

      // Définir l'offre distante
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offerSdp, 'offer'),
      );

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
      print('Error sending ICE candidate: $e');
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

    try {
      final updates = await apiService.pollCallUpdates(
        currentCallId!,
        _lastPollTime,
      );

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
      } else if (status == 'active' && call['answer_sdp'] != null) {
        final currentDesc = await _peerConnection?.getRemoteDescription();
        if (currentDesc == null || currentDesc.sdp != call['answer_sdp']) {
          await _peerConnection?.setRemoteDescription(
            RTCSessionDescription(call['answer_sdp'], 'answer'),
          );
        }
      }

      // Traiter les ICE candidates
      final candidates = updates['ice_candidates'] as List? ?? [];
      for (var candidateData in candidates) {
        final candidate = jsonDecode(candidateData['candidate']);
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
    }

    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (currentCallId == null) return;
    _pollTimer = Timer(const Duration(seconds: 2), _pollLoop);
  }

  /// Surveiller les changements de connectivité
  void _startConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    bool _isFirstEvent = true;

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (result) async {
          // Ignorer le premier événement (initialisation)
          if (_isFirstEvent) {
            _isFirstEvent = false;
            return;
          }

          if (currentCallId == null || _peerConnection == null) return;

          // Vérifier si on a une connexion
          final hasConnection = result != ConnectivityResult.none;

          if (hasConnection && !_isRestartingIce) {
            debugPrint('Network change detected, restarting ICE...');
            onNetworkChange?.call('Reconnexion en cours...');
            await _restartIce();
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

      print('ICE restart successful');
    } catch (e) {
      print('ICE restart failed: $e');
    } finally {
      _isRestartingIce = false;
    }
  }

  /// Nettoyer les ressources
  Future<void> cleanup() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _localStream?.dispose();
    _localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    currentCallId = null;
    _lastPollTime = null;
    _isRestartingIce = false;
  }

  /// Obtenir l'historique des appels
  Future<List<dynamic>> getCallHistory({int page = 1}) async {
    return await apiService.getCallHistory(page: page);
  }
}
