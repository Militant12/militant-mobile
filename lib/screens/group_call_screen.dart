import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/group_call_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class GroupCallScreen extends StatefulWidget {
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
  late GroupCallService _callService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};

  bool _isMuted = false;
  bool _isCameraOff = false;
  List<Map<String, dynamic>> _participants = [];
  String _callStatus = '';

  @override
  void initState() {
    super.initState();
    _callStatus = LanguageService.instance.translate('call_connecting');
    _initRenderers();
    _setupCallService();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  void _setupCallService() async {
    final apiService = await ApiService.getInstance();
    _callService = GroupCallService(apiService: apiService);

    _callService.onLocalStream = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _callService.onRemoteStreamAdded = (userId, stream) async {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = stream;

      setState(() {
        _remoteRenderers[userId] = renderer;
        _callStatus = LanguageService.instance
            .translate('call_participant_count')
            .replaceAll('{count}', '${_remoteRenderers.length}');
      });
    };

    _callService.onRemoteStreamRemoved = (userId) {
      final renderer = _remoteRenderers[userId];
      if (renderer != null) {
        renderer.dispose();
        setState(() {
          _remoteRenderers.remove(userId);
          _callStatus = LanguageService.instance
              .translate('call_participant_count')
              .replaceAll('{count}', '${_remoteRenderers.length}');
        });
      }
    };

    _callService.onCallEnded = (reason) async {
      if (!mounted) return;
      setState(() {
        _callStatus = '📵 Appel terminé';
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    };

    _callService.onParticipantsChanged = (participants) {
      setState(() {
        _participants = participants;
      });
    };

    _callService.onNetworkChange = (message) {
      if (mounted) {
        setState(
          () => _callStatus = LanguageService.instance.translate(
            'call_network_reconnecting',
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: Duration(seconds: 2)),
        );
      }
    };

    // Initier ou rejoindre l'appel
    if (widget.isIncoming && widget.callId != null) {
      setState(
        () => _callStatus = LanguageService.instance.translate('call_joining'),
      );
      await _callService.joinCall(
        widget.callId!,
        widget.isVideo ? 'video' : 'audio',
      );
    } else if (!widget.isIncoming && widget.groupId != null) {
      setState(
        () => _callStatus = LanguageService.instance.translate('call_ringing'),
      );
      if (widget.isVideo) {
        await _callService.initiateVideoCall(widget.groupId!);
      } else {
        await _callService.initiateAudioCall(widget.groupId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Grille de vidéos
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
                      _callService.toggleMicrophone();
                      setState(() => _isMuted = !_isMuted);
                    },
                    color: _isMuted ? Colors.red : Colors.white,
                  ),

                  // Bouton caméra (si vidéo)
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: () {
                        _callService.toggleCamera();
                        setState(() => _isCameraOff = !_isCameraOff);
                      },
                      color: _isCameraOff ? Colors.red : Colors.white,
                    ),

                  // Bouton raccrocher
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: () async {
                      await _callService.leaveCall();
                      if (mounted) Navigator.pop(context);
                    },
                    color: Colors.white,
                    backgroundColor: Colors.red,
                  ),

                  // Bouton changer de caméra
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () => _callService.switchCamera(),
                      color: Colors.white,
                    ),

                  // Bouton participants
                  _buildControlButton(
                    icon: Icons.people,
                    onPressed: () => _showParticipants(),
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

  Widget _buildVideoGrid() {
    final allRenderers = [
      {'userId': 0, 'renderer': _localRenderer, 'isLocal': true},
      ..._remoteRenderers.entries.map(
        (e) => {'userId': e.key, 'renderer': e.value, 'isLocal': false},
      ),
    ];

    if (!widget.isVideo || allRenderers.isEmpty) {
      return _buildAudioOnlyView();
    }

    // Calculer la grille (2x2, 3x3, etc.)
    final count = allRenderers.length;
    final columns = count <= 1
        ? 1
        : count <= 4
        ? 2
        : 3;
    final rows = (count / columns).ceil();

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        final item = allRenderers[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(
                item['renderer'] as RTCVideoRenderer,
                mirror: item['isLocal'] as bool,
              ),
              if (item['isLocal'] as bool)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      LanguageService.instance.translate('call_you'),
                      style: TextStyle(color: Colors.white, fontSize: 12),
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
          Icon(Icons.group, size: 80, color: Colors.white54),
          SizedBox(height: 20),
          Text(
            LanguageService.instance.translate('call_group_audio'),
            style: TextStyle(color: Colors.white, fontSize: 20),
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
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${LanguageService.instance.translate('call_participants')} (${_participants.length + 1})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _participants.length,
                  itemBuilder: (context, index) {
                    final participant = _participants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: participant['avatar'] != null
                            ? NetworkImage(participant['avatar'])
                            : null,
                        child: participant['avatar'] == null
                            ? Text(participant['username'][0].toUpperCase())
                            : null,
                      ),
                      title: Text(
                        participant['username'],
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        participant['status'],
                        style: TextStyle(color: Colors.white70),
                      ),
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

  @override
  void dispose() {
    _localRenderer.dispose();
    for (var renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    _callService.cleanup();
    super.dispose();
  }
}
