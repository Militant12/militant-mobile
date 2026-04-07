import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/nextcloud_talk_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

/// ─── CONFIGURATION NEXTCLOUD TALK ──────────────────────────────────────────
/// Adresse de votre serveur Nextcloud Talk (avec HPB installé).
const String _kNextcloudBaseUrl =
    'https://visiorevlibertaire.revlibertaire.com';

/// Compte de service Nextcloud (utilisé comme "bot" pour créer/gérer les rooms).
/// ⚠️  Utilisez un "App Password" (Paramètres → Sécurité → Mots de passe d'application)
/// et NON le vrai mot de passe du compte.
const String _kNextcloudServiceUser = 'anar';
const String _kNextcloudServiceAppPassword = 'Kjsk2-eDCSm-5Sj97-z97Kz-xwAFP';

/// URL forcée du serveur de signalisation externe (HPB).
/// Si l'API de base ne le renvoie pas, on utilise celui-ci.
const String _kNextcloudHpbUrl = 'https://signalvisiorevlibertaire.revlibertaire.com';
// ───────────────────────────────────────────────────────────────────────────

class GroupCallScreen extends StatefulWidget {
  /// Token de room Nextcloud Talk existante (si on rejoint une room existante).
  final String? callId;
  final int? groupId;
  final String groupName;
  final bool isVideo;
  final bool isIncoming;

  const GroupCallScreen({
    super.key,
    this.callId,
    this.groupId,
    required this.groupName,
    required this.isVideo,
    required this.isIncoming,
  });

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  // ─── Service Nextcloud Talk (remplace l'ancien GroupCallService) ────────────
  NextcloudTalkService? _talkService;

  // ─── Renderers WebRTC ────────────────────────────────────────────────────────
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();

  /// Map sessionId → RTCVideoRenderer pour les participants distants
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  /// Map sessionId → displayName pour afficher les noms dans la grille
  final Map<String, String> _remoteNames = {};

  // ─── État UI ──────────────────────────────────────────────────────────────────
  bool _isMuted = false;
  bool _isCameraOff = false;
  String _callStatus = '';
  List<NextcloudParticipant> _participants = [];
  late ApiService apiService; // Accessible dans toute la classe

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _callStatus = LanguageService.instance.translate('call_connecting');
    _initRenderers();
    _setupTalkService();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _setupTalkService() async {
    // Récupérer le nom d'affichage de l'utilisateur connecté
    apiService = await ApiService.getInstance();
    String displayName = 'Militant';
    try {
      final profile = await apiService.getProfile();
      displayName = profile['username']?.toString() ?? 'Militant';
    } catch (_) {}

    final service = NextcloudTalkService(
      nextcloudBaseUrl: _kNextcloudBaseUrl,
      nextcloudUser: _kNextcloudServiceUser,
      nextcloudAppPassword: _kNextcloudServiceAppPassword,
      localDisplayName: displayName,
      forcedHpbUrl: _kNextcloudHpbUrl, // Passer l'URL HPB forcée
    );

    // ─── Callbacks ────────────────────────────────────────────────────────────

    service.onLocalStream = (stream) {
      if (!mounted) return;
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    service.onRemoteStreamAdded = (sessionId, name, stream) async {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;

      if (!mounted) {
        renderer.dispose();
        return;
      }

      setState(() {
        _remoteRenderers[sessionId] = renderer;
        _remoteNames[sessionId] = name;
        _callStatus = LanguageService.instance
            .translate('call_participant_count')
            .replaceAll('{count}', '${_remoteRenderers.length}');
      });
    };

    service.onRemoteStreamRemoved = (sessionId) {
      final renderer = _remoteRenderers[sessionId];
      renderer?.dispose();
      if (!mounted) return;
      setState(() {
        _remoteRenderers.remove(sessionId);
        _remoteNames.remove(sessionId);
        _callStatus = LanguageService.instance
            .translate('call_participant_count')
            .replaceAll('{count}', '${_remoteRenderers.length}');
      });
    };

    service.onParticipantsChanged = (participants) {
      if (!mounted) return;
      setState(() {
        _participants = participants;
      });
    };

    service.onConnected = () {
      if (!mounted) return;
      setState(() {
        _callStatus = LanguageService.instance.translate('call_participant_count')
            .replaceAll('{count}', '0');
      });
    };

    service.onDisconnected = (reason) async {
      if (!mounted) return;
      setState(() => _callStatus = '📵 Appel terminé');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    };

    service.onError = (error) {
      if (!mounted) return;
      setState(() => _callStatus = error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 3)),
      );
    };

    // Assigner le service une fois configuré
    setState(() {
      _talkService = service;
    });

    // ─── Rejoindre ou créer le salon ─────────────────────────────────────────
    try {
      if (widget.isIncoming && widget.callId != null) {
        // Rejoindre un salon existant (callId = room token Nextcloud Talk)
        setState(() => _callStatus =
            LanguageService.instance.translate('call_joining'));
        await service.joinOrCreateRoom(
          existingRoomToken: widget.callId,
          videoEnabled: widget.isVideo,
        );
      } else {
        // Créer un nouveau salon pour ce groupe
        setState(() => _callStatus =
            LanguageService.instance.translate('call_ringing'));
        final roomToken = await service.joinOrCreateRoom(
          roomName: widget.groupName,
          videoEnabled: widget.isVideo,
        );
        debugPrint('[GroupCallScreen] Room créée: $roomToken');

        // Notifier tous les membres du groupe avec le roomToken Nextcloud Talk
        if (widget.groupId != null) {
          try {
            await apiService.initiateTalkRoom(
              groupId: widget.groupId!,
              roomToken: roomToken,
              callType: widget.isVideo ? 'video' : 'audio',
            );
            debugPrint('[GroupCallScreen] Invitation Talk envoyée au groupe ${widget.groupId}');
          } catch (e) {
            // Non bloquant : le salon fonctionne même si la notification échoue
            debugPrint('[GroupCallScreen] Erreur envoi invitation: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _callStatus = 'Erreur de connexion: $e');
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_talkService == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Grille de vidéos / Vue audio
            _buildVideoGrid(),

            // Informations en haut
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Contrôles en bas
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton micro
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: () {
                      final isNowEnabled = _talkService?.toggleMicrophone() ?? false;
                      setState(() => _isMuted = !isNowEnabled);
                    },
                    color: _isMuted ? Colors.red : Colors.white,
                  ),

                  // Bouton caméra (si vidéo)
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: () {
                        final isNowEnabled = _talkService?.toggleCamera() ?? false;
                        setState(() => _isCameraOff = !isNowEnabled);
                      },
                      color: _isCameraOff ? Colors.red : Colors.white,
                    ),

                  // Bouton raccrocher
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: () async {
                      await _talkService?.leaveRoom();
                      if (mounted) Navigator.pop(context);
                    },
                    color: Colors.white,
                    backgroundColor: Colors.red,
                  ),

                  // Bouton changer de caméra
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () => _talkService?.switchCamera(),
                      color: Colors.white,
                    ),

                  // Bouton participants
                  _buildControlButton(
                    icon: Icons.people,
                    onPressed: _showParticipants,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildVideoGrid() {
    // Si c'est un appel audio pur (depuis le bouton audio), on reste en vue audio
    if (!widget.isVideo) {
      return _buildAudioOnlyView();
    }

    final entries = [
      // Local en premier
      MapEntry<String, RTCVideoRenderer>('__local__', _localRenderer),
      ..._remoteRenderers.entries,
    ];

    final count = entries.length;
    final columns = count <= 1 ? 1 : count <= 4 ? 2 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isLocal = entry.key == '__local__';
        final name = isLocal
            ? LanguageService.instance.translate('call_you')
            : (_remoteNames[entry.key] ?? entry.key);

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(entry.value, mirror: isLocal),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioOnlyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group, size: 80, color: Colors.white54),
          const SizedBox(height: 20),
          Text(
            LanguageService.instance.translate('call_group_audio'),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 12),
          // Nombre de participants en temps réel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_talkService?.participantCount ?? 0} participant${(_talkService?.participantCount ?? 0) > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${LanguageService.instance.translate('call_participants')} (${_participants.length + 1})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_participants.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Vous êtes seul(e) dans le salon.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      final p = _participants[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.redAccent,
                          child: Text(
                            p.displayName.isNotEmpty
                                ? p.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          p.displayName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          p.isModerator ? 'Modérateur' : 'Participant',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: p.inCall
                            ? const Icon(Icons.mic, color: Colors.greenAccent, size: 18)
                            : const Icon(Icons.mic_off, color: Colors.white38, size: 18),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white24,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 32,
        onPressed: onPressed,
      ),
    );
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _talkService?.cleanup();
    super.dispose();
  }
}
