import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service d'appels audio/vidéo en temps réel basé sur Nextcloud Talk (HPB).
///
/// Architecture :
///   1. REST API Nextcloud → Créer ou rejoindre une "conversation" (room).
///   2. OCS API Nextcloud → Récupérer les paramètres de signalisation (ticket, STUN/TURN).
///   3. WebSocket → Connexion au serveur HPB (High Performance Backend).
///   4. flutter_webrtc → Échange audio/vidéo via le serveur SFU du HPB.
///
/// CONFIGURATION (à renseigner selon votre installation) :
///   - [nextcloudBaseUrl] : URL de votre serveur Nextcloud (ex: https://visiorevlibertaire.revlibertaire.com)
///   - [nextcloudUser] : Nom d'utilisateur du compte Nextcloud utilisé comme "bot" de service.
///   - [nextcloudAppPassword] : App Password généré dans Paramètres → Sécurité → Mots de passe d'application.
///     ⚠️  NE JAMAIS hard-coder le vrai mot de passe ici. Toujours utiliser un App Password.

class NextcloudTalkService {
  // ─── Configuration du serveur ───────────────────────────────────────────────
  final String nextcloudBaseUrl;
  final String nextcloudUser;
  final String nextcloudAppPassword;
  final String? forcedHpbUrl; // URL du serveur de signalisation externe (HPB)

  // ─── Identités locales ───────────────────────────────────────────────────────
  /// Nom d'affichage de l'utilisateur local dans la room.
  final String localDisplayName;

  /// ID unique de la session locale (généré aléatoirement à chaque connexion).
  late String _sessionId;

  // ─── État de la room ────────────────────────────────────────────────────────
  String? _roomToken;
  bool _isConnected = false;

  // ─── WebSocket (connexion HPB) ───────────────────────────────────────────────
  // ignore: close_sinks
  StreamController<Map<String, dynamic>>? _wsMessageController;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // ─── WebRTC ─────────────────────────────────────────────────────────────────
  MediaStream? _localStream;
  // Peer connections indexées par sessionId distant
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  // ICE candidates en attente (pour les participants non encore connectés)
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};

  // ─── Callbacks publics ───────────────────────────────────────────────────────
  /// Appelé quand le flux audio/vidéo local est prêt.
  Function(MediaStream stream)? onLocalStream;

  /// Appelé quand un nouveau participant audio/vidéo arrive.
  Function(String sessionId, String displayName, MediaStream stream)?
  onRemoteStreamAdded;

  /// Appelé quand un participant quitte la room.
  Function(String sessionId)? onRemoteStreamRemoved;

  /// Appelé quand la liste des participants change.
  Function(List<NextcloudParticipant> participants)? onParticipantsChanged;

  /// Appelé en cas d'erreur critique.
  Function(String error)? onError;

  /// Appelé quand la connexion à la room est établie.
  Function()? onConnected;

  /// Appelé quand la room se termine ou que la connexion est perdue.
  Function(String reason)? onDisconnected;

  // ─── Constructeur ────────────────────────────────────────────────────────────
  NextcloudTalkService({
    required this.nextcloudBaseUrl,
    required this.nextcloudUser,
    required this.nextcloudAppPassword,
    required this.localDisplayName,
    this.forcedHpbUrl,
  });

  // ─── API Helpers ─────────────────────────────────────────────────────────────

  String get _basicAuth {
    final credentials = '$nextcloudUser:$nextcloudAppPassword';
    return 'Basic ${base64Encode(utf8.encode(credentials))}';
  }

  Map<String, String> get _ocsHeaders => {
    'Authorization': _basicAuth,
    'OCS-APIRequest': 'true',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ─── 1. Créer/Rejoindre une Room via l'API REST Nextcloud Talk ───────────────

  /// Crée un nouveau salon audio public (type 3 = public) sur Nextcloud Talk.
  /// Retourne le token unique du salon (ex: "abc123xyz").
  Future<String> createRoom(String roomName) async {
    final url = '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v4/room';
    final response = await http
        .post(
          Uri.parse(url),
          headers: _ocsHeaders,
          body: jsonEncode({
            'roomType': 3, // 3 = Salon public
            'roomName': roomName,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Impossible de créer le salon Nextcloud Talk: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final token = data['ocs']['data']['token'] as String?;
    if (token == null) {
      throw Exception('Token de salon introuvable dans la réponse Nextcloud.');
    }
    debugPrint('[NextcloudTalk] Room créée: token=$token');
    return token;
  }

  /// Vérifie qu'un salon existe et renvoie ses informations.
  Future<Map<String, dynamic>> getRoomInfo(String roomToken) async {
    final url =
        '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v4/room/$roomToken';
    final response = await http
        .get(Uri.parse(url), headers: _ocsHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Salon introuvable ($roomToken): ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['ocs']['data'] as Map<String, dynamic>;
  }

  /// Récupère la liste des participants d'un salon.
  Future<List<NextcloudParticipant>> getParticipants(String roomToken) async {
    final url =
        '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v4/room/$roomToken/participants';
    final response = await http
        .get(Uri.parse(url), headers: _ocsHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final list = data['ocs']['data'] as List<dynamic>? ?? [];
    return list
        .map(
          (p) => NextcloudParticipant(
            actorId: p['actorId']?.toString() ?? '',
            displayName: p['displayName']?.toString() ?? 'Anonyme',
            sessionId: p['sessionId']?.toString() ?? '',
            inCall: (p['inCall'] as int? ?? 0) > 0,
            isModerator: (p['participantType'] as int? ?? 0) <= 2,
          ),
        )
        .toList();
  }

  /// Valide la session de l'utilisateur auprès du serveur Nextcloud.
  /// Indispensable pour que le HPB accepte la connexion.
  Future<void> _joinCallOCS(String roomToken) async {
    // Liste des endpoints possibles selon la version de Nextcloud
    final endpoints = [
      '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v1/call/$roomToken',
      '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v4/call/$roomToken',
    ];

    for (final url in endpoints) {
      try {
        final response = await http.post(Uri.parse(url), headers: _ocsHeaders).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('[NextcloudTalk] Session APPEL validée via $url');
          return;
        }
      } catch (_) {}
    }

    // Fallback ultime : getRoomInfo
    try {
      await getRoomInfo(roomToken);
      debugPrint('[NextcloudTalk] Session validée (fallback info) pour $roomToken');
    } catch (e) {
      debugPrint('[NextcloudTalk] Erreur validation session: $e');
    }
  }

  // ─── 2. Récupérer les paramètres de signalisation (STUN/TURN + Ticket) ──────

  Future<_SignalingSettings> _getSignalingSettings(String roomToken) async {
    final url =
        '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v3/signaling/settings';
    final response = await http
        .get(
          Uri.parse('$url?token=$roomToken'),
          headers: _ocsHeaders,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
        'Impossible de récupérer les paramètres de signalisation: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final settings = data['ocs']['data'] as Map<String, dynamic>;

    final stunServers =
        (settings['stunservers'] as List<dynamic>? ?? [])
            .map(
              (s) => (s['urls'] as List<dynamic>? ?? [])
                  .map((u) => u.toString())
                  .toList(),
            )
            .expand((e) => e)
            .toList();

    final turnServers =
        (settings['turnservers'] as List<dynamic>? ?? [])
            .map(
              (t) => {
                'urls': (t['urls'] as List<dynamic>? ?? [])
                    .map((u) => u.toString())
                    .toList(),
                'username': t['username']?.toString() ?? '',
                'credential': t['credential']?.toString() ?? '',
              },
            )
            .toList();

    // Le HPB (signaling serveur externe)
    final signalingServers =
        settings['signalingservers'] as List<dynamic>? ?? [];
    String? hpbUrl;
    String? ticket;

    if (signalingServers.isNotEmpty) {
      // On prend le premier HPB disponible
      final first = signalingServers[0] as Map<String, dynamic>;
      hpbUrl = first['url']?.toString();
      ticket = settings['ticket']?.toString();
      debugPrint('[NextcloudTalk] HPB détecté: $hpbUrl');
    } else if (forcedHpbUrl != null && settings['ticket'] != null) {
      // Utiliser l'URL forcée si le serveur de base ne renvoie rien
      hpbUrl = forcedHpbUrl;
      ticket = settings['ticket']?.toString();
      debugPrint('[NextcloudTalk] HPB forcé (fallback local): $hpbUrl');
    } else {
      debugPrint(
        '[NextcloudTalk] ⚠️  Aucun HPB configuré sur ce serveur Nextcloud.',
      );
    }

    // Fallback STUN publics si le serveur n'en fournit pas
    if (stunServers.isEmpty) {
      stunServers.addAll([
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ]);
    }

    return _SignalingSettings(
      stunServers: stunServers,
      turnServers: turnServers,
      hpbUrl: hpbUrl,
      ticket: ticket,
    );
  }

  // ─── 3. Connexion WebSocket au HPB ───────────────────────────────────────────

  Future<void> _connectToHpb(
    String hpbUrl,
    String ticket,
    String roomToken,
    _SignalingSettings settings,
  ) async {
    // Convertir http(s) en ws(s) si nécessaire
    String wsUrl = hpbUrl;
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }
    if (!wsUrl.endsWith('/'))  wsUrl += '/';
    wsUrl += 'spreed';

    debugPrint('[NextcloudTalk] Connexion WebSocket vers: $wsUrl');
    _ws = WebSocketChannel.connect(Uri.parse(wsUrl));

    _wsMessageController = StreamController<Map<String, dynamic>>.broadcast();

    _wsSubscription = _ws!.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _handleHpbMessage(msg, settings, roomToken);
          _wsMessageController?.add(msg);
        } catch (e) {
          debugPrint('[NextcloudTalk] Erreur parsing WS: $e');
        }
      },
      onDone: () {
        debugPrint('[NextcloudTalk] WebSocket fermé.');
        _scheduleReconnect(ticket, roomToken, settings);
      },
      onError: (e) {
        debugPrint('[NextcloudTalk] Erreur WebSocket: $e');
        onError?.call('Connexion perdue. Reconnexion en cours...');
        _scheduleReconnect(ticket, roomToken, settings);
      },
    );

    // Message "hello" pour s'authentifier sur le HPB
    _sendWsMessage({
      'type': 'hello',
      'hello': {
        'version': '1.0',
        'auth': {
          'url': '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v3/signaling/backend',
          'params': {
            'userid': nextcloudUser,
            'ticket': ticket,
          },
        },
      },
    });
  }

  void _sendWsMessage(Map<String, dynamic> message) {
    if (_ws != null) {
      try {
        _ws!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('[NextcloudTalk] ⚠️  Erreur envoi WS: $e');
      }
    } else {
      debugPrint('[NextcloudTalk] ⚠️  WebSocket non ouvert, message non envoyé.');
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendWsMessage({'type': 'ping'});
    });
  }

  void _scheduleReconnect(
    String ticket,
    String roomToken,
    _SignalingSettings settings,
  ) {
    if (!_isConnected || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: min(30, pow(2, _reconnectAttempts).toInt()));
    debugPrint('[NextcloudTalk] Reconnexion dans ${delay.inSeconds}s (tentative $_reconnectAttempts)...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (settings.hpbUrl != null) {
        try {
          await _connectToHpb(settings.hpbUrl!, ticket, roomToken, settings);
        } catch (e) {
          debugPrint('[NextcloudTalk] Erreur de reconnexion: $e');
        }
      }
    });
  }

  // ─── 4. Gérer les messages HPB entrants ──────────────────────────────────────

  Future<void> _handleHpbMessage(
    Map<String, dynamic> msg,
    _SignalingSettings settings,
    String roomToken,
  ) async {
    final type = msg['type'] as String?;
    debugPrint('[NextcloudTalk] Message HPB reçu: $type');

    switch (type) {
      case 'hello':
        // ✅ Authentifié sur le HPB — rejoindre la room
        debugPrint('[NextcloudTalk] Authentifié sur le HPB!');
        _sessionId = msg['hello']?['sessionid'] ?? _sessionId;
        _reconnectAttempts = 0;
        _startPingTimer();
        _joinRoom(roomToken);
        onConnected?.call();
        break;

      case 'room':
        // Confirmation de jonction à la room
        debugPrint('[NextcloudTalk] Rejoint la room: ${msg['room']?['roomid']}');
        break;

      case 'participants':
        // Liste des participants mise à jour
        final participants = msg['participants'] as Map<String, dynamic>?;
        final changed = participants?['changed'] as List<dynamic>? ?? [];
        for (final p in changed) {
          final pMap = p as Map<String, dynamic>;
          final sessId = pMap['sessionid']?.toString() ?? '';
          if (sessId.isEmpty || sessId == _sessionId) continue;

          final inCall = (pMap['inCall'] as int? ?? 0) > 0;
          if (inCall && !_peerConnections.containsKey(sessId)) {
            // Un nouveau participant est dans la room en voix/vidéo
            await _initPeerConnection(sessId, settings, isOffer: true);
          } else if (!inCall && _peerConnections.containsKey(sessId)) {
            // Un participant a quitté
            await _closePeerConnection(sessId);
            onRemoteStreamRemoved?.call(sessId);
          }
        }
        break;

      case 'message':
        // Messages de signalisation WebRTC (offers, answers, candidates)
        await _handleSignalingMessage(msg, settings);
        break;

      case 'error':
        debugPrint('[NextcloudTalk] ERREUR HPB: ${msg['error']}');
        onError?.call(msg['error']?['message']?.toString() ?? 'Erreur HPB inconnue');
        break;

      default:
        break;
    }
  }

  void _joinRoom(String roomToken) {
    _sendWsMessage({
      'type': 'room',
      'room': {
        'name': roomToken, // Requis par les versions récentes de HPB
        'roomid': roomToken, // Fallback pour les anciennes versions
        'sessionid': _sessionId,
      },
    });
  }

  // ─── 5. Signalisation WebRTC (Offer / Answer / ICE Candidates) ───────────────

  Future<void> _handleSignalingMessage(
    Map<String, dynamic> msg,
    _SignalingSettings settings,
  ) async {
    final data = msg['message'] as Map<String, dynamic>?;
    if (data == null) return;

    final fromSession = msg['from']?.toString() ?? '';
    final msgData = data['data'] as Map<String, dynamic>?;
    if (msgData == null) return;

    final msgType = msgData['type'] as String?;

    switch (msgType) {
      case 'offer':
        await _handleOffer(fromSession, msgData, settings);
        break;
      case 'answer':
        await _handleAnswer(fromSession, msgData);
        break;
      case 'candidate':
        await _handleCandidate(fromSession, msgData);
        break;
      case 'unshareScreen':
      case 'endOfCandidates':
        // Fin des candidats ICE pour ce pair
        break;
      default:
        break;
    }
  }

  Future<void> _handleOffer(
    String fromSession,
    Map<String, dynamic> data,
    _SignalingSettings settings,
  ) async {
    debugPrint('[NextcloudTalk] Offer reçu de $fromSession');
    var pc = _peerConnections[fromSession];
    pc ??= await _initPeerConnection(fromSession, settings, isOffer: false);

    final sdpData = data['sdp'] as Map<String, dynamic>?;
    if (sdpData == null) return;

    await pc.setRemoteDescription(
      RTCSessionDescription(
        sdpData['sdp'] as String?,
        sdpData['type'] as String?,
      ),
    );

    // Ajouter les candidates en attente
    final pending = _pendingCandidates.remove(fromSession) ?? [];
    for (final c in pending) {
      await pc.addCandidate(c);
    }

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _sendWsMessage({
      'type': 'message',
      'to': fromSession,
      'message': {
        'data': {
          'type': 'answer',
          'sdp': {'type': answer.type, 'sdp': answer.sdp},
        },
      },
    });
  }

  Future<void> _handleAnswer(
    String fromSession,
    Map<String, dynamic> data,
  ) async {
    debugPrint('[NextcloudTalk] Answer reçu de $fromSession');
    final pc = _peerConnections[fromSession];
    if (pc == null) return;

    final sdpData = data['sdp'] as Map<String, dynamic>?;
    if (sdpData == null) return;

    await pc.setRemoteDescription(
      RTCSessionDescription(
        sdpData['sdp'] as String?,
        sdpData['type'] as String?,
      ),
    );

    // Ajouter les candidates en attente
    final pending = _pendingCandidates.remove(fromSession) ?? [];
    for (final c in pending) {
      await pc.addCandidate(c);
    }
  }

  Future<void> _handleCandidate(
    String fromSession,
    Map<String, dynamic> data,
  ) async {
    final candidateData = data['candidate'] as Map<String, dynamic>?;
    if (candidateData == null) return;

    final candidate = RTCIceCandidate(
      candidateData['candidate'] as String?,
      candidateData['sdpMid'] as String?,
      candidateData['sdpMLineIndex'] as int?,
    );

    final pc = _peerConnections[fromSession];
    if (pc != null && pc.signalingState != null) {
      await pc.addCandidate(candidate);
    } else {
      // Mémoriser pour plus tard si la PC n'est pas encore prête
      _pendingCandidates.putIfAbsent(fromSession, () => []).add(candidate);
    }
  }

  // ─── 6. Gestion des Peer Connections ─────────────────────────────────────────

  Future<RTCPeerConnection> _initPeerConnection(
    String remoteSession,
    _SignalingSettings settings, {
    required bool isOffer,
  }) async {
    final iceServers = <Map<String, dynamic>>[];

    // Ajouter les serveurs STUN
    for (final url in settings.stunServers) {
      iceServers.add({'urls': url});
    }

    // Ajouter les serveurs TURN (avec credentials)
    for (final turn in settings.turnServers) {
      iceServers.add(turn);
    }

    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });

    // Ajouter notre flux local
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // Réception du flux distant
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        final remoteStream = event.streams[0];
        _remoteStreams[remoteSession] = remoteStream;
        onRemoteStreamAdded?.call(remoteSession, remoteSession, remoteStream);
        debugPrint('[NextcloudTalk] Stream distant reçu de $remoteSession');
      }
    };

    // Envoi des ICE candidates locaux
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _sendWsMessage({
          'type': 'message',
          'to': remoteSession,
          'message': {
            'data': {
              'type': 'candidate',
              'candidate': {
                'candidate': candidate.candidate,
                'sdpMid': candidate.sdpMid,
                'sdpMLineIndex': candidate.sdpMLineIndex,
              },
            },
          },
        });
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[NextcloudTalk] ICE state pour $remoteSession: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _closePeerConnection(remoteSession);
        onRemoteStreamRemoved?.call(remoteSession);
      }
    };

    _peerConnections[remoteSession] = pc;

    // Si on est l'initiateur, créer et envoyer l'offre
    if (isOffer) {
      final offer = await pc.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false, // Mode audio uniquement par défaut
      });
      await pc.setLocalDescription(offer);

      _sendWsMessage({
        'type': 'message',
        'to': remoteSession,
        'message': {
          'data': {
            'type': 'offer',
            'sdp': {'type': offer.type, 'sdp': offer.sdp},
          },
        },
      });
    }

    return pc;
  }

  Future<void> _closePeerConnection(String sessionId) async {
    final pc = _peerConnections.remove(sessionId);
    await pc?.close();
    await _remoteStreams.remove(sessionId)?.dispose();
    _pendingCandidates.remove(sessionId);
  }

  // ─── API Publique ─────────────────────────────────────────────────────────────

  /// Point d'entrée principal.
  /// Crée un salon audio sur Nextcloud Talk et se connecte au HPB.
  ///
  /// Si [existingRoomToken] est fourni, on rejoint ce salon existant.
  /// Sinon, un nouveau salon nommé [roomName] est créé.
  Future<String> joinOrCreateRoom({
    String? existingRoomToken,
    String roomName = 'Militant Live',
    bool videoEnabled = false,
  }) async {
    _isConnected = true;
    _sessionId = _generateSessionId();

    try {
      // 1. Obtenir/créer le token du salon
      final token = existingRoomToken ?? await createRoom(roomName);
      _roomToken = token;

      // 1.5 S'enregistrer officiellement comme participant dans l'APPEL (étape OCS)
      // Indispensable pour que le HPB nous autorise l'entrée.
      await _joinCallOCS(token);

      // 2. Récupérer les paramètres de signalisation (STUN/TURN + ticket HPB)
      final settings = await _getSignalingSettings(token);

      // 3. Capturer le micro (et optionnellement la caméra)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': videoEnabled
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '24',
                },
                'facingMode': 'user',
              }
            : false,
      });
      onLocalStream?.call(_localStream!);

      // 4. Se connecter au HPB (WebSocket)
      if (settings.hpbUrl != null && settings.ticket != null) {
        await _connectToHpb(
          settings.hpbUrl!,
          settings.ticket!,
          token,
          settings,
        );
      } else {
        // Mode de secours : P2P direct (Mesh). Limitee à 4-5 personnes.
        debugPrint(
          '[NextcloudTalk] Mode secours P2P (pas de HPB). Salon limité à ~5 participants.',
        );
        onConnected?.call();
      }

      return token;
    } catch (e) {
      _isConnected = false;
      await cleanup();
      rethrow;
    }
  }

  /// Quitter le salon proprement.
  Future<void> leaveRoom() async {
    _isConnected = false;
    try {
      if (_roomToken != null) {
        // Prévenir le serveur que l'on part
        final url =
            '$nextcloudBaseUrl/ocs/v2.php/apps/spreed/api/v4/room/$_roomToken/participants/self';
        await http
            .delete(Uri.parse(url), headers: _ocsHeaders)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // On quitte quoi qu'il arrive
    }
    await cleanup();
  }

  /// Activer/désactiver le micro. Retourne le nouvel état (true = activé).
  bool toggleMicrophone() {
    bool newState = true;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
      newState = track.enabled;
    });
    return newState;
  }

  /// État actuel du micro (true = actif).
  bool get isMicrophoneEnabled {
    final tracks = _localStream?.getAudioTracks() ?? [];
    return tracks.isNotEmpty && tracks.first.enabled;
  }

  /// Activer/désactiver la caméra. Retourne le nouvel état (true = activé).
  bool toggleCamera() {
    bool newState = true;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !track.enabled;
      newState = track.enabled;
    });
    return newState;
  }

  /// Changer de caméra (avant/arrière).
  Future<void> switchCamera() async {
    try {
      final videoTracks = _localStream?.getVideoTracks() ?? [];
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    } catch (e) {
      debugPrint('[NextcloudTalk] switchCamera non supporté sur cette plateforme: $e');
    }
  }

  /// Nettoyer toutes les ressources (WebSocket, streams, peer connections).
  Future<void> cleanup() async {
    _isConnected = false;

    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _ws?.sink.close();
    _ws = null;

    await _wsMessageController?.close();
    _wsMessageController = null;

    await _localStream?.dispose();
    _localStream = null;

    for (final stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();

    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _pendingCandidates.clear();

    _roomToken = null;
  }

  // ─── Helpers internes ─────────────────────────────────────────────────────────

  static String _generateSessionId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(32, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ─── Getters d'état ───────────────────────────────────────────────────────────

  bool get isConnected => _isConnected;
  String? get roomToken => _roomToken;
  int get participantCount => _peerConnections.length + 1; // +1 pour soi-même
}

// ─── Modèles de données ───────────────────────────────────────────────────────

/// Représente un participant dans un salon Nextcloud Talk.
class NextcloudParticipant {
  final String actorId;
  final String displayName;
  final String sessionId;
  final bool inCall;
  final bool isModerator;

  const NextcloudParticipant({
    required this.actorId,
    required this.displayName,
    required this.sessionId,
    required this.inCall,
    required this.isModerator,
  });
}

/// Paramètres de signalisation retournés par Nextcloud Talk.
class _SignalingSettings {
  final List<String> stunServers;
  final List<Map<String, dynamic>> turnServers;
  final String? hpbUrl;
  final String? ticket;

  const _SignalingSettings({
    required this.stunServers,
    required this.turnServers,
    this.hpbUrl,
    this.ticket,
  });
}
