import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'livekit_runtime_config.dart';
import 'livekit_token_service.dart';

const String kGroupCallMessagePrefix = '__militant_group_call__:';

/// Appels de groupe: signalisation via `calls.php`, media via LiveKit.
class GroupCallService {
  GroupCallService({required this.apiService});

  final ApiService apiService;

  MediaStream? _localStream;
  final Map<int, MediaStream> _remoteStreams = <int, MediaStream>{};
  final Map<int, List<MediaStreamTrack>> _remoteTracks =
      <int, List<MediaStreamTrack>>{};

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _pollTimer;

  String? currentCallId;
  int? currentGroupId;
  int? currentUserId;

  String _currentCallType = 'audio';
  String _currentDisplayName = 'Militant';
  bool _microphoneEnabled = true;
  bool _cameraEnabled = true;
  bool _isCleaningUp = false;
  String? _lastPollTime;

  Function(MediaStream)? onLocalStream;
  Function(int userId, MediaStream stream)? onRemoteStreamAdded;
  Function(int userId)? onRemoteStreamRemoved;
  Function(String)? onCallEnded;
  Function(List<Map<String, dynamic>>)? onParticipantsChanged;
  Function(String)? onNetworkChange;
  Function(int? userId, bool isSpeaking)? onSpeakingChanged;

  MediaStream? get localStream => _localStream;

  bool get isMicrophoneMuted => !_microphoneEnabled;

  bool get isCameraOff => _currentCallType != 'video' || !_cameraEnabled;

  Future<String> initiateAudioCall(int groupId) async {
    return _initiateCall(groupId, 'audio');
  }

  Future<String> initiateVideoCall(int groupId) async {
    return _initiateCall(groupId, 'video');
  }

  Future<void> joinCall(String callId, String callType) async {
    try {
      _currentCallType = callType;
      _microphoneEnabled = true;
      _cameraEnabled = callType == 'video';
      currentCallId = callId;

      await _ensureMediaPermissions(callType);
      await _configureAudioSession();
      await _ensureCurrentUserProfile();

      await apiService.joinGroupCall(callId);
      await _connectToLiveKit(callId, callType);

      _startPolling();
    } catch (_) {
      await cleanup();
      rethrow;
    }
  }

  Future<void> leaveCall() async {
    try {
      if (currentCallId != null) {
        await apiService.leaveGroupCall(currentCallId!);
      }
    } catch (e) {
      debugPrint('[LiveKit][group] leave API failed: $e');
    } finally {
      await cleanup();
    }
  }

  Future<void> cleanup() async {
    _isCleaningUp = true;

    _pollTimer?.cancel();
    _pollTimer = null;

    final roomListener = _roomListener;
    _roomListener = null;
    await roomListener?.dispose();

    final room = _room;
    _room = null;
    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {}
      await room.dispose();
    }

    for (final stream in _remoteStreams.values) {
      await stream.dispose();
    }
    _remoteStreams.clear();
    _remoteTracks.clear();

    await _localStream?.dispose();
    _localStream = null;

    _setSpeaking(null, false);

    currentCallId = null;
    currentGroupId = null;
    _lastPollTime = null;

    await _restoreAudioSession();
    _isCleaningUp = false;
  }

  Future<void> switchCamera() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks.first);
  }

  void toggleMicrophone() {
    final room = _room;
    final localParticipant = room?.localParticipant;
    if (localParticipant == null) return;

    final next = !_microphoneEnabled;
    _microphoneEnabled = next;
    localParticipant.setMicrophoneEnabled(next).then((_) {
      _ensureLocalAggregateStream();
    });
    _syncLocalTrackEnabledStates();
  }

  void toggleCamera() {
    if (_currentCallType != 'video') return;

    final room = _room;
    final localParticipant = room?.localParticipant;
    if (localParticipant == null) return;

    final next = !_cameraEnabled;
    _cameraEnabled = next;
    localParticipant.setCameraEnabled(next).then((_) {
      _ensureLocalAggregateStream();
    });
    _syncLocalTrackEnabledStates();
  }

  Future<String> _initiateCall(int groupId, String callType) async {
    try {
      _currentCallType = callType;
      _microphoneEnabled = true;
      _cameraEnabled = callType == 'video';
      currentGroupId = groupId;

      await _ensureMediaPermissions(callType);
      await _configureAudioSession();
      await _ensureCurrentUserProfile();

      final response = await apiService.initiateGroupCall(
        groupId,
        callType,
        _createPlaceholderOffer(),
      );

      final callId = response['call_id']?.toString().trim() ?? '';
      if (callId.isEmpty) {
        throw Exception('call_id manquant pour l appel de groupe');
      }

      currentCallId = callId;
      unawaited(_publishGroupCallMessage(callId, callType));
      await _connectToLiveKit(callId, callType);
      _startPolling();

      return callId;
    } catch (_) {
      await cleanup();
      rethrow;
    }
  }

  Future<void> _ensureCurrentUserProfile() async {
    final profile = await apiService.getProfile();
    currentUserId ??= int.tryParse(profile['id']?.toString() ?? '');

    final username = profile['username']?.toString().trim() ?? '';
    final displayName = profile['display_name']?.toString().trim() ?? '';
    _currentDisplayName = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? username : 'Militant');
  }

  String _createPlaceholderOffer() {
    return 'v=0\r\n';
  }

  Future<void> _ensureMediaPermissions(String callType) async {
    if (kIsWeb) return;

    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw Exception('Autorisation microphone refusee pour l appel de groupe');
    }

    if (callType != 'video') return;

    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      throw Exception(
        'Autorisation camera refusee pour l appel video de groupe',
      );
    }
  }

  Future<void> _connectToLiveKit(String callId, String callType) async {
    final roomName = 'group-call-$callId';
    final identity = _buildIdentity(_currentDisplayName, userId: currentUserId);

    final creds = await LiveKitTokenService.issueJoinCredentials(
      roomName: roomName,
      identity: identity,
      displayName: _currentDisplayName,
      canPublish: true,
      useDeviceOverrides: false,
    );

    final wsUrl = await LiveKitRuntimeConfig.effectiveServerUrl(
      fromApi: creds.serverUrlFromApi,
      useDeviceOverrides: false,
    );
    if (wsUrl.trim().isEmpty) {
      throw Exception('URL LiveKit introuvable');
    }

    final room = Room(
      // Group calls render LiveKit tracks through RTCVideoView, not LiveKit's
      // visibility-aware video widget. Keep streams active to avoid server-side
      // pauses that can look like a frozen remote image.
      roomOptions: const RoomOptions(adaptiveStream: false, dynacast: false),
    );
    await room.connect(wsUrl, creds.token);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    _room = room;
    _installRoomListeners(room);

    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      throw Exception('Participant local LiveKit indisponible');
    }

    await _publishMicrophone(localParticipant);
    if (callType == 'video') {
      await _publishCamera(localParticipant);
    }

    await _ensureLocalAggregateStream();
    await _syncExistingParticipantTracks(room);
  }

  Future<void> _publishMicrophone(LocalParticipant localParticipant) async {
    try {
      await _runWithRetry(
        () => localParticipant.setMicrophoneEnabled(true),
        label: 'microphone publish',
      );
      _microphoneEnabled = true;
    } catch (e) {
      _microphoneEnabled = false;
      debugPrint('[LiveKit][group] microphone publish failed: $e');
      throw Exception('Impossible d activer le micro pour l appel de groupe');
    }
  }

  Future<void> _publishCamera(LocalParticipant localParticipant) async {
    try {
      await _runWithRetry(
        () => localParticipant.setCameraEnabled(true),
        label: 'camera publish',
      );
      _cameraEnabled = true;
    } catch (e) {
      _cameraEnabled = false;
      onNetworkChange?.call('Camera indisponible, appel poursuit sans video');
      debugPrint('[LiveKit][group] camera publish failed, fallback audio: $e');
    }
  }

  Future<T?> _runWithRetry<T>(
    Future<T?> Function() action, {
    required String label,
  }) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('[LiveKit][group] $label failed, retrying: $e');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return action();
    }
  }

  void _installRoomListeners(Room room) {
    final listener = room.createListener();

    listener.on<RoomReconnectingEvent>((_) {
      onNetworkChange?.call('Reconnexion en cours...');
    });

    listener.on<RoomReconnectedEvent>((_) {
      onNetworkChange?.call('');
    });

    listener.on<RoomDisconnectedEvent>((_) async {
      if (_isCleaningUp) return;
      onCallEnded?.call('Call ended');
      await cleanup();
    });

    listener.on<ParticipantConnectedEvent>((event) async {
      await _attachPublishedTracks(event.participant);
    });

    listener.on<ParticipantDisconnectedEvent>((event) async {
      final userId = _parseUserIdFromIdentity(event.participant.identity);
      if (userId != null) {
        await _removeRemoteParticipant(userId);
      }
    });

    listener.on<LocalTrackPublishedEvent>((_) async {
      await _ensureLocalAggregateStream();
    });

    listener.on<TrackSubscribedEvent>((event) async {
      await _attachRemoteTrack(event.participant, event.track);
    });

    listener.on<TrackUnsubscribedEvent>((event) async {
      final userId = _parseUserIdFromIdentity(event.participant.identity);
      if (userId == null) return;
      await _detachRemoteTrack(userId, event.track.mediaStreamTrack);
    });

    listener.on<TrackUnmutedEvent>((event) async {
      final track = event.publication.track;
      if (track != null) {
        await _attachRemoteTrack(event.participant, track);
      }
    });

    listener.on<TrackStreamStateUpdatedEvent>((event) async {
      if (event.streamState != StreamState.active) return;
      final track = event.publication.track;
      if (track != null) {
        await _attachRemoteTrack(event.participant, track);
      }
    });

    listener.on<ActiveSpeakersChangedEvent>((event) {
      final activeIds = <int?>{};
      for (final speaker in event.speakers) {
        final userId = _parseUserIdFromIdentity(speaker.identity);
        if (userId == currentUserId) {
          activeIds.add(null);
        } else {
          activeIds.add(userId);
        }
      }

      _setSpeaking(null, activeIds.contains(null));

      final knownRemoteUserIds = _remoteStreams.keys.toList();
      for (final userId in knownRemoteUserIds) {
        _setSpeaking(userId, activeIds.contains(userId));
      }
    });

    _roomListener = listener;
  }

  Future<void> _syncExistingParticipantTracks(Room room) async {
    await _ensureLocalAggregateStream();
    for (final participant in room.remoteParticipants.values) {
      await _attachPublishedTracks(participant);
    }
  }

  Future<void> _ensureLocalAggregateStream() async {
    final room = _room;
    final localParticipant = room?.localParticipant;
    if (localParticipant == null) return;

    _localStream ??= await createLocalMediaStream('group-local-livekit');

    await _replaceAggregateTracks(
      stream: _localStream!,
      nextTracks: <MediaStreamTrack>[
        ...localParticipant.audioTrackPublications
            .map((publication) => publication.track?.mediaStreamTrack)
            .whereType<MediaStreamTrack>(),
        ...localParticipant.videoTrackPublications
            .map((publication) => publication.track?.mediaStreamTrack)
            .whereType<MediaStreamTrack>(),
      ],
    );

    _syncLocalTrackEnabledStates();
    onLocalStream?.call(_localStream!);
  }

  Future<void> _attachPublishedTracks(RemoteParticipant participant) async {
    for (final publication in participant.audioTrackPublications) {
      final track = publication.track;
      if (track != null) {
        await _attachRemoteTrack(participant, track);
      }
    }
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track != null) {
        await _attachRemoteTrack(participant, track);
      }
    }
  }

  Future<void> _attachRemoteTrack(Participant participant, Track track) async {
    final userId = _parseUserIdFromIdentity(participant.identity);
    if (userId == null || userId == currentUserId) return;

    final stream =
        _remoteStreams[userId] ??
        await createLocalMediaStream('group-remote-livekit-$userId');
    final tracks = _remoteTracks.putIfAbsent(
      userId,
      () => <MediaStreamTrack>[],
    );

    final mediaTrack = track.mediaStreamTrack;
    if (!tracks.any((existing) => existing.id == mediaTrack.id)) {
      stream.addTrack(mediaTrack);
      tracks.add(mediaTrack);
    }

    _remoteStreams[userId] = stream;
    onRemoteStreamAdded?.call(userId, stream);
  }

  Future<void> _detachRemoteTrack(int userId, MediaStreamTrack track) async {
    final stream = _remoteStreams[userId];
    final tracks = _remoteTracks[userId];
    if (stream == null || tracks == null) return;

    tracks.removeWhere((existing) => existing.id == track.id);
    await _safeRemoveTrack(stream, track);

    if (tracks.isEmpty) {
      await _removeRemoteParticipant(userId);
      return;
    }

    onRemoteStreamAdded?.call(userId, stream);
  }

  Future<void> _removeRemoteParticipant(int userId) async {
    _setSpeaking(userId, false);

    final stream = _remoteStreams.remove(userId);
    _remoteTracks.remove(userId);
    if (stream != null) {
      await stream.dispose();
    }

    onRemoteStreamRemoved?.call(userId);
  }

  void _syncLocalTrackEnabledStates() {
    final audioTracks =
        _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in audioTracks) {
      track.enabled = _microphoneEnabled;
    }

    final videoTracks =
        _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    for (final track in videoTracks) {
      track.enabled = _cameraEnabled;
    }
  }

  Future<void> _replaceAggregateTracks({
    required MediaStream stream,
    required List<MediaStreamTrack> nextTracks,
  }) async {
    final existingTracks = stream.getTracks().toList();
    final nextIds = nextTracks.map((track) => track.id).toSet();

    for (final track in existingTracks) {
      if (!nextIds.contains(track.id)) {
        await _safeRemoveTrack(stream, track);
      }
    }

    for (final track in nextTracks) {
      final alreadyPresent = stream.getTracks().any(
        (existing) => existing.id == track.id,
      );
      if (!alreadyPresent) {
        stream.addTrack(track);
      }
    }
  }

  Future<void> _safeRemoveTrack(
    MediaStream stream,
    MediaStreamTrack track,
  ) async {
    try {
      await stream.removeTrack(track);
    } catch (e) {
      debugPrint(
        '[LiveKit][group] ignore removeTrack failure stream=${stream.id} track=${track.id} error=$e',
      );
    }
  }

  int? _parseUserIdFromIdentity(String? identity) {
    final raw = identity?.trim() ?? '';
    if (raw.isEmpty) return null;

    final direct = int.tryParse(raw);
    if (direct != null) return direct;

    final prefixedMatch = RegExp(r'^u(\d+)(?:-|$)').firstMatch(raw);
    if (prefixedMatch != null) {
      return int.tryParse(prefixedMatch.group(1)!);
    }

    final match = RegExp(r'(\d+)$').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String _buildIdentity(String displayName, {int? userId}) {
    final slug = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = slug.isEmpty ? 'militant' : slug;
    if (userId != null && userId > 0) {
      return 'u$userId-$base';
    }
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$base-$suffix';
  }

  void _setSpeaking(int? userId, bool isSpeaking) {
    onSpeakingChanged?.call(userId, isSpeaking);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollCall();
    });
    _pollCall();
  }

  Future<void> _pollCall() async {
    final callId = currentCallId;
    if (callId == null) return;

    try {
      final updates = await apiService.pollCallUpdates(callId, _lastPollTime);
      if (currentCallId != callId) return;

      _lastPollTime = updates['timestamp']?.toString();

      final call = updates['call'];
      if (call is Map<String, dynamic>) {
        final status = call['status']?.toString();
        if (status == 'ended') {
          onCallEnded?.call('Call ended');
          await cleanup();
          return;
        }
      }

      final participantsRaw = updates['participants'];
      if (participantsRaw is List) {
        onParticipantsChanged?.call(
          participantsRaw
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('[LiveKit][group] poll failed call=$callId error=$e');
    }
  }

  Future<void> _publishGroupCallMessage(String callId, String callType) async {
    final groupId = currentGroupId;
    if (groupId == null) return;

    final payload = <String, String>{
      'call_id': callId,
      'call_type': callType,
      'group_id': '$groupId',
      'group_name': '',
      'v': '1',
    };

    final encoded = payload.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');

    try {
      await apiService.sendGroupMessage(
        groupId,
        '$kGroupCallMessagePrefix$encoded',
      );
    } catch (e) {
      debugPrint('[LiveKit][group] failed to publish call message: $e');
    }
  }

  Future<void> _configureAudioSession() async {
    if (kIsWeb) return;

    try {
      if (WebRTC.platformIsAndroid) {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      } else if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true,
        );
        await Helper.ensureAudioSession();
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      }
    } catch (e) {
      debugPrint('[LiveKit][group] audio session config failed: $e');
    }
  }

  Future<void> _restoreAudioSession() async {
    if (kIsWeb) return;

    try {
      if (WebRTC.platformIsAndroid) {
        await Helper.clearAndroidCommunicationDevice();
      } else if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(AppleAudioIOMode.none);
      }
    } catch (e) {
      debugPrint('[LiveKit][group] audio session restore failed: $e');
    }
  }
}
