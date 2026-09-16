import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/api_service.dart';
import '../services/group_call_service.dart';
import '../services/language_service.dart';
import '../utils/error_helper.dart';

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
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _remoteRenderers = {};
  final Map<int, String> _participantNames = {};
  final Map<int, String> _participantStatuses = {};
  final Map<int, String> _participantAvatars = {};
  final Set<int> _speakingParticipantIds = <int>{};

  GroupCallService? _groupCallService;
  ApiService? _apiService;
  int? _currentUserId;
  String _currentUserName = '';
  String? _currentUserAvatar;
  String _callStatus = '';
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isLocalSpeaking = false;
  bool _hasLeft = false;
  int _joinedParticipantsCount = 1;

  @override
  void initState() {
    super.initState();
    _callStatus = LanguageService.instance.translate('call_connecting');
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.isVideo) {
      await _localRenderer.initialize();
    }

    final api = await ApiService.getInstance();
    try {
      final profile = await api.getProfile();
      _currentUserId = int.tryParse(profile['id']?.toString() ?? '');
      _currentUserName =
          profile['username']?.toString().trim().isNotEmpty == true
          ? profile['username'].toString()
          : LanguageService.instance.translate('call_you');
      _currentUserAvatar = _extractAvatar(profile);
    } catch (_) {}
    final service = GroupCallService(apiService: api);
    service.currentUserId = _currentUserId;

    service.onLocalStream = (stream) {
      if (!mounted) return;
      setState(() {
        _syncTrackFlags();
        if (widget.isVideo) {
          _localRenderer.srcObject = stream;
        }
      });
    };

    service.onRemoteStreamAdded = (userId, stream) async {
      for (final track in stream.getAudioTracks()) {
        track.enabled = true;
      }

      if (!widget.isVideo) {
        if (!mounted) return;
        setState(_updateCallStatus);
        return;
      }

      final previousRenderer = _remoteRenderers[userId];
      if (previousRenderer != null) {
        previousRenderer.srcObject = stream;
        if (!mounted) return;
        setState(_updateCallStatus);
        return;
      }

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (!mounted) {
        renderer.srcObject = null;
        await renderer.dispose();
        return;
      }
      renderer.srcObject = stream;

      setState(() {
        _remoteRenderers[userId] = renderer;
        _updateCallStatus();
      });
    };

    service.onRemoteStreamRemoved = (userId) async {
      final renderer = _remoteRenderers.remove(userId);
      renderer?.srcObject = null;
      await renderer?.dispose();

      if (!mounted) return;
      setState(_updateCallStatus);
    };

    service.onParticipantsChanged = (participants) {
      if (!mounted) return;

      int joinedCount = 0;
      final nextParticipantNames = <int, String>{};
      final nextParticipantStatuses = <int, String>{};
      final nextParticipantAvatars = <int, String>{};

      for (final participant in participants) {
        final userId = int.tryParse(participant['user_id']?.toString() ?? '');
        final status = participant['status']?.toString() ?? 'invited';

        if (status == 'joined') {
          joinedCount++;
        }

        if (userId != null && userId != _currentUserId) {
          nextParticipantNames[userId] =
              participant['username']?.toString().trim().isNotEmpty == true
              ? participant['username'].toString()
              : 'Utilisateur $userId';
          nextParticipantStatuses[userId] = status;
          final avatar = _extractAvatar(participant);
          if (avatar != null) {
            nextParticipantAvatars[userId] = avatar;
          }
        }
      }

      setState(() {
        _participantNames
          ..clear()
          ..addAll(nextParticipantNames);
        _participantStatuses
          ..clear()
          ..addAll(nextParticipantStatuses);
        _participantAvatars
          ..clear()
          ..addAll(nextParticipantAvatars);
        _speakingParticipantIds.removeWhere(
          (id) => !nextParticipantNames.containsKey(id),
        );
        _joinedParticipantsCount = joinedCount > 0 ? joinedCount : 1;
        _updateCallStatus();
      });
    };

    service.onSpeakingChanged = (userId, isSpeaking) {
      if (!mounted) return;
      setState(() {
        if (userId == null) {
          _isLocalSpeaking = isSpeaking;
        } else if (isSpeaking) {
          _speakingParticipantIds.add(userId);
        } else {
          _speakingParticipantIds.remove(userId);
        }
      });
    };

    service.onNetworkChange = (message) {
      if (!mounted) return;
      setState(() {
        if (message.trim().isEmpty) {
          _updateCallStatus();
        } else {
          _callStatus = message;
        }
      });
    };

    service.onCallEnded = (_) async {
      if (!mounted || _hasLeft) return;
      setState(() => _callStatus = 'Appel terminé');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).maybePop();
    };

    _apiService = api;
    _groupCallService = service;

    try {
      if (widget.isIncoming) {
        final incomingCallId = widget.callId;
        if (incomingCallId == null || incomingCallId.isEmpty) {
          throw Exception('call_id manquant pour rejoindre l\'appel');
        }
        setState(
          () =>
              _callStatus = LanguageService.instance.translate('call_joining'),
        );
        await service.joinCall(
          incomingCallId,
          widget.isVideo ? 'video' : 'audio',
        );
      } else {
        final groupId = widget.groupId;
        if (groupId == null) {
          throw Exception('group_id manquant pour initier l\'appel');
        }
        setState(
          () =>
              _callStatus = LanguageService.instance.translate('call_ringing'),
        );
        if (widget.isVideo) {
          await service.initiateVideoCall(groupId);
        } else {
          await service.initiateAudioCall(groupId);
        }
      }

      if (!mounted) return;
      setState(() {
        _syncTrackFlags();
        _updateCallStatus();
      });
    } catch (e) {
      await service.cleanup();
      if (!mounted) return;
      setState(() => _callStatus = getFriendlyErrorMessage(e));
    }
  }

  void _syncTrackFlags() {
    final service = _groupCallService;
    if (service == null) return;
    _isMuted = service.isMicrophoneMuted;
    _isCameraOff = service.isCameraOff;
  }

  void _updateCallStatus() {
    _callStatus = LanguageService.instance
        .translate('call_participant_count')
        .replaceAll('{count}', '$_joinedParticipantsCount');
  }

  String? _extractAvatar(Map<String, dynamic> values) {
    const keys = [
      'avatar',
      'user_avatar',
      'profile_picture',
      'profilePicture',
      'picture',
      'photo',
    ];

    for (final key in keys) {
      final value = values[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return _apiService?.getImageUrl(value) ??
            ApiService.resolveImageUrl(value) ??
            value;
      }
    }
    return null;
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return String.fromCharCode(parts.first.runes.first).toUpperCase();
    }
    return '${String.fromCharCode(parts.first.runes.first)}${String.fromCharCode(parts.last.runes.first)}'
        .toUpperCase();
  }

  Future<void> _leaveCall() async {
    if (_hasLeft) return;
    _hasLeft = true;

    final service = _groupCallService;

    try {
      await service?.leaveCall();
    } catch (_) {
      await service?.cleanup();
    } finally {
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _toggleMicrophone() {
    _groupCallService?.toggleMicrophone();
    if (!mounted) return;
    setState(_syncTrackFlags);
  }

  void _toggleCamera() {
    _groupCallService?.toggleCamera();
    if (!mounted) return;
    setState(_syncTrackFlags);
  }

  void _showParticipants() {
    final theme = Theme.of(context);
    final participants = _participantNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${LanguageService.instance.translate('call_participants')} ($_joinedParticipantsCount)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(LanguageService.instance.translate('call_you')),
                  subtitle: const Text('Connecté'),
                ),
                if (participants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'En attente des autres participants…',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  ...participants.map(
                    (entry) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(entry.value),
                      subtitle: Text(
                        (_participantStatuses[entry.key] ?? 'invited') ==
                                'joined'
                            ? 'Connecté'
                            : 'Invitation envoyée',
                      ),
                    ),
                  ),
              ],
            ),
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
        iconSize: 30,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildAudioOnlyView() {
    final participants = <_AudioParticipant>[
      _AudioParticipant(
        id: null,
        name: _currentUserName.isNotEmpty
            ? _currentUserName
            : LanguageService.instance.translate('call_you'),
        avatarUrl: _currentUserAvatar,
        status: 'joined',
        isMuted: _isMuted,
        isSpeaking: _isLocalSpeaking && !_isMuted,
      ),
      ...(_participantNames.entries.toList()
            ..sort((a, b) => a.value.compareTo(b.value)))
          .map(
            (entry) => _AudioParticipant(
              id: entry.key,
              name: entry.value,
              avatarUrl: _participantAvatars[entry.key],
              status: _participantStatuses[entry.key] ?? 'invited',
              isMuted: false,
              isSpeaking: _speakingParticipantIds.contains(entry.key),
            ),
          ),
    ];

    final columns = participants.length <= 2
        ? 2
        : participants.length <= 6
        ? 3
        : 4;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 108, 18, 132),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        return _buildAudioParticipantTile(participants[index]);
      },
    );
  }

  Widget _buildAudioParticipantTile(_AudioParticipant participant) {
    final isConnected = participant.status == 'joined';
    final borderColor = participant.isSpeaking
        ? const Color(0xFF35D07F)
        : Colors.white24;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: participant.isSpeaking ? Colors.white12 : Colors.white10,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: participant.isSpeaking ? 3 : 1,
        ),
        boxShadow: participant.isSpeaking
            ? [
                BoxShadow(
                  color: const Color(0xFF35D07F).withValues(alpha: 0.32),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white12,
                backgroundImage:
                    participant.avatarUrl != null &&
                        participant.avatarUrl!.isNotEmpty
                    ? NetworkImage(participant.avatarUrl!)
                    : null,
                child:
                    participant.avatarUrl == null ||
                        participant.avatarUrl!.isEmpty
                    ? Text(
                        _initialsFor(participant.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (participant.isMuted)
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: _AudioStatusDot(
                    color: Color(0xFFE53935),
                    icon: Icons.mic_off,
                  ),
                )
              else if (participant.isSpeaking)
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: _AudioStatusDot(
                    color: Color(0xFF35D07F),
                    icon: Icons.graphic_eq,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            participant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: participant.isSpeaking
                ? const _SpeakingBars(key: ValueKey('speaking'))
                : Text(
                    isConnected ? 'Connecté' : 'Invité',
                    key: ValueKey(participant.status),
                    style: TextStyle(
                      color: isConnected ? Colors.white70 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    if (!widget.isVideo) {
      return _buildAudioOnlyView();
    }

    final entries = <MapEntry<int, RTCVideoRenderer>>[
      MapEntry(-1, _localRenderer),
      ..._remoteRenderers.entries,
    ];
    final count = entries.length;
    final columns = count <= 1
        ? 1
        : count <= 4
        ? 2
        : 3;

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
        final isLocal = entry.key == -1;
        final label = isLocal
            ? LanguageService.instance.translate('call_you')
            : (_participantNames[entry.key] ?? 'Utilisateur ${entry.key}');

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(entry.value, mirror: isLocal),
              if (entry.value.srcObject == null ||
                  entry.value.srcObject!.getVideoTracks().isEmpty)
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.videocam_off,
                      color: Colors.white54,
                      size: 42,
                    ),
                  ),
                ),
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
                    label,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildVideoGrid(),
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMicrophone,
                    color: _isMuted ? Colors.red : Colors.white,
                  ),
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: _toggleCamera,
                      color: _isCameraOff ? Colors.red : Colors.white,
                    ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _leaveCall,
                    color: Colors.white,
                    backgroundColor: Colors.red,
                  ),
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () => _groupCallService?.switchCamera(),
                      color: Colors.white,
                    ),
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

  @override
  void dispose() {
    _groupCallService?.cleanup();
    if (widget.isVideo) {
      _localRenderer.srcObject = null;
      _localRenderer.dispose();
    }
    for (final renderer in _remoteRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    super.dispose();
  }
}

class _AudioParticipant {
  final int? id;
  final String name;
  final String? avatarUrl;
  final String status;
  final bool isMuted;
  final bool isSpeaking;

  const _AudioParticipant({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.status,
    required this.isMuted,
    required this.isSpeaking,
  });
}

class _AudioStatusDot extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _AudioStatusDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class _SpeakingBars extends StatelessWidget {
  const _SpeakingBars({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _SpeakingBar(height: 8),
        SizedBox(width: 3),
        _SpeakingBar(height: 14),
        SizedBox(width: 3),
        _SpeakingBar(height: 10),
      ],
    );
  }
}

class _SpeakingBar extends StatelessWidget {
  final double height;

  const _SpeakingBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF35D07F),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
