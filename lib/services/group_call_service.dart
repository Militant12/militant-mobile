import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

/// Service pour gérer les appels de groupe avec architecture mesh
/// Chaque participant est connecté à tous les autres participants
class GroupCallService {
  final ApiService apiService;

  // Peer connections: Map<userId, RTCPeerConnection>
  final Map<int, RTCPeerConnection> _peerConnections = {};

  // Remote streams: Map<userId, MediaStream>
  final Map<int, MediaStream> _remoteStreams = {};

  MediaStream? _localStream;
  String? currentCallId;
  int? currentGroupId;
  Timer? _pollTimer;
  String? _lastPollTime;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(int userId, MediaStream stream)? onRemoteStreamAdded;
  Function(int userId)? onRemoteStreamRemoved;
  Function(String)? onCallEnded;
  Function(List<Map<String, dynamic>>)? onParticipantsChanged;
  Function(String)? onNetworkChange;

  GroupCallService({required this.apiService});

  // Configuration ICE servers
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
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

  /// Initier un appel de groupe audio
  Future<String> initiateAudioCall(int groupId) async {
    return _initiateCall(groupId, 'audio');
  }

  /// Initier un appel de groupe vidéo
  Future<String> initiateVideoCall(int groupId) async {
    return _initiateCall(groupId, 'video');
  }

  Future<String> _initiateCall(int groupId, String callType) async {
    try {
      currentGroupId = groupId;

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      onLocalStream?.call(_localStream!);

      // Créer une offre initiale (sera utilisée pour les peer connections)
      final tempPc = await createPeerConnection(_iceServers);
      _localStream!.getTracks().forEach((track) {
        tempPc.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await tempPc.createOffer();
      await tempPc.close();

      // Envoyer l'appel au serveur
      final response = await apiService.initiateGroupCall(
        groupId,
        callType,
        offer.sdp!,
      );

      currentCallId = response['call_id'];

      // Commencer le polling
      _startPolling();
      _startConnectivityMonitoring();

      return currentCallId!;
    } catch (e) {
      await cleanup();
      rethrow;
    }
  }

  /// Rejoindre un appel de groupe
  Future<void> joinCall(String callId, String callType) async {
    try {
      currentCallId = callId;

      // Obtenir le stream local
      final constraints = callType == 'video'
          ? _mediaConstraints
          : {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      onLocalStream?.call(_localStream!);

      // Créer une offre initiale
      final tempPc = await createPeerConnection(_iceServers);
      _localStream!.getTracks().forEach((track) {
        tempPc.addTrack(track, _localStream!);
      });

      RTCSessionDescription offer = await tempPc.createOffer();
      await tempPc.close();

      // Rejoindre l'appel
      final response = await apiService.joinGroupCall(callId, offer.sdp!);

      final otherParticipants = response['other_participants'] as List;

      // Créer des peer connections avec tous les participants existants
      for (var userId in otherParticipants) {
        await _createPeerConnection(userId as int);
      }

      // Commencer le polling
      _startPolling();
      _startConnectivityMonitoring();
    } catch (e) {
      await cleanup();
      rethrow;
    }
  }

  /// Créer une peer connection avec un participant
  Future<void> _createPeerConnection(int userId) async {
    if (_peerConnections.containsKey(userId)) return;

    final pc = await createPeerConnection(_iceServers);

    // Ajouter les tracks locaux
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Écouter les ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendIceCandidate(candidate);
      }
    };

    // Écouter le stream distant
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams[0];
        onRemoteStreamAdded?.call(userId, event.streams[0]);
      }
    };

    // Créer et envoyer l'offre
    RTCSessionDescription offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    await apiService.sendPeerOffer(currentCallId!, userId, offer.sdp!);

    _peerConnections[userId] = pc;
  }

  /// Traiter une offre d'un pair
  Future<void> _handlePeerOffer(int fromUserId, String offerSdp) async {
    if (_peerConnections.containsKey(fromUserId)) return;

    final pc = await createPeerConnection(_iceServers);

    // Ajouter les tracks locaux
    _localStream!.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // Écouter les ICE candidates
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendIceCandidate(candidate);
      }
    };

    // Écouter le stream distant
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[fromUserId] = event.streams[0];
        onRemoteStreamAdded?.call(fromUserId, event.streams[0]);
      }
    };

    // Définir l'offre distante
    await pc.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer'));

    // Créer et envoyer la réponse
    RTCSessionDescription answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await apiService.sendPeerAnswer(currentCallId!, fromUserId, answer.sdp!);

    _peerConnections[fromUserId] = pc;
  }

  /// Traiter une réponse d'un pair
  Future<void> _handlePeerAnswer(int fromUserId, String answerSdp) async {
    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    await pc.setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
  }

  /// Quitter l'appel
  Future<void> leaveCall() async {
    try {
      if (currentCallId != null) {
        await apiService.leaveGroupCall(currentCallId!);
      }
    } catch (e) {
      // Keep UX smooth even if network/API leave fails.
      print('Error leaving group call: $e');
    } finally {
      await cleanup();
    }
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

  /// Changer de caméra
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
  int _errorCount = 0;

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _errorCount = 0;
    _pollLoop();
  }

  /// Polling récursif : attend la fin de la requête avant de relancer
  void _pollLoop() async {
    if (currentCallId == null) return;

    try {
      final updates = await apiService.pollCallUpdates(
        currentCallId!,
        _lastPollTime,
      );

      _lastPollTime = updates['timestamp'];
      _errorCount = 0; // Reset error count on success

      final call = updates['call'];
      if (call == null) {
        _scheduleNextPoll();
        return;
      }

      if (call['status']?.toString() == 'ended') {
        onCallEnded?.call('Call ended');
        await cleanup();
        return; // Stopper le polling
      }

      // Traiter les nouveaux ICE candidates
      final candidates = updates['ice_candidates'] as List? ?? [];
      for (var candidateData in candidates) {
        final candidate = jsonDecode(candidateData['candidate']);
        final senderId = candidateData['user_id'];
        final pc = _peerConnections[senderId];
        if (pc != null) {
          await pc.addCandidate(
            RTCIceCandidate(
              candidate['candidate'],
              candidate['sdpMid'],
              candidate['sdpMLineIndex'],
            ),
          );
        }
      }

      // Pour les appels de groupe
      if (call['is_group_call'] == 1) {
        final participants = updates['participants'] as List? ?? [];
        onParticipantsChanged?.call(participants.cast<Map<String, dynamic>>());

        final peerOffers = updates['peer_offers'] as List? ?? [];
        for (var offer in peerOffers) {
          await _handlePeerOffer(offer['from_user_id'], offer['offer_sdp']);
        }

        final peerAnswers = updates['peer_answers'] as List? ?? [];
        for (var answer in peerAnswers) {
          await _handlePeerAnswer(answer['from_user_id'], answer['answer_sdp']);
        }
      }
    } catch (e) {
      _errorCount++;
      if (_errorCount >= 3) {
        debugPrint('Too many polling errors, stopping call: $e');
        await cleanup();
        return; // Stopper le polling
      }
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
    bool isFirstEvent = true;

    try {
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (result) async {
          // Ignorer le premier événement (initialisation)
          if (isFirstEvent) {
            isFirstEvent = false;
            return;
          }

          if (currentCallId == null) return;

          final hasConnection = result != ConnectivityResult.none;

          if (hasConnection) {
            debugPrint('Network change detected in group call');
            onNetworkChange?.call('Reconnexion en cours...');
            // Note: ICE restart pour les appels de groupe est plus complexe
            // Il faudrait redémarrer toutes les peer connections
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

  /// Nettoyer les ressources
  Future<void> cleanup() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    await _localStream?.dispose();
    _localStream = null;

    for (var stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();

    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    currentCallId = null;
    currentGroupId = null;
    _lastPollTime = null;
  }
}
