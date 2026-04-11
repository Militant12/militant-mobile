import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/livekit_config.dart';
import '../services/api_service.dart';
import '../services/livekit_runtime_config.dart';
import '../services/livekit_token_service.dart';
import '../services/language_service.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

enum _LiveMode { viewer, creator }

class _LiveScreenState extends State<LiveScreen> {
  static const String _livekitChatTopic = 'militant-live-chat';
  static const String _livekitControlTopic = 'militant-live-control';

  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _livekitUrlController = TextEditingController();
  final TextEditingController _livekitTokenEndpointController =
      TextEditingController();
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  Room? _room;
  bool _isConnecting = false;
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  bool _sessionCanPublish = false;
  String? _sessionIdentity;
  File? _liveBackgroundImageFile;
  String? _liveBackgroundImageUrl;
  String? _errorMessage;
  String? _currentLiveTitle;
  _LiveMode _mode = _LiveMode.viewer;
  bool _isMilitantTechnician = false;
  bool _isElectedModerator = false;
  int? _currentUserId;
  int? _streamingLiveId;
  List<_LiveKitChatEntry> _livekitChatMessages = [];
  final Set<String> _chatDedupKeys = <String>{};
  final Set<String> _deletedChatKeys = <String>{};
  final Set<String> _blockedParticipantIdentities = <String>{};
  final Set<String> _blockedParticipantNames = <String>{};
  final Set<int> _blockedParticipantUserIds = <int>{};
  final Set<String> _sessionModeratorIdentities = <String>{};
  final Set<int> _sessionModeratorUserIds = <int>{};
  CancelListenFunc? _livekitDataCancel;
  int _reportCount = 0;
  bool _isSuspendedByConsensus = false;
  List<Map<String, dynamic>> _discoveryLives = [];
  bool _loadingDiscovery = false;
  Timer? _liveCommentsPollTimer;
  Timer? _livePingTimer;
  bool _isSendingChat = false;
  ApiService? _api;
  bool _isUpdatingLiveBackground = false;
  bool _hasPendingJoinRequest = false;
  bool _isPromotingToSpeaker = false;
  bool _isReportingLive = false;
  List<_LiveGuestRequest> _guestRequests = [];
  List<dynamic> _moderationReports = [];
  bool _loadingModeration = false;

  @override
  void initState() {
    super.initState();
    _bootstrapLiveScreen();
  }

  Future<void> _bootstrapLiveScreen() async {
    await _hydrateProfile();
    await _loadLiveKitOverrides();
    await _loadDiscoveryLives();
    if (_isMilitantTechnician || _isElectedModerator) {
      await _loadModerationReports();
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    _displayNameController.dispose();
    _livekitUrlController.dispose();
    _livekitTokenEndpointController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    unawaited(_detachLivekitChatListener());
    _stopLiveCommentsPolling();
    _stopLivePing();
    unawaited(_disconnectRoom());
    super.dispose();
  }

  Future<void> _loadDiscoveryLives() async {
    setState(() => _loadingDiscovery = true);
    try {
      final api = await ApiService.getInstance();
      final list = await api.fetchActiveLives();
      if (!mounted) return;
      setState(() {
        _api = api;
        _discoveryLives = list;
        _loadingDiscovery = false;
      });
      // Update report count if current live in discovery
      if (_streamingLiveId != null) {
        final current = _discoveryLives.firstWhere(
          (l) => l['id'] == _streamingLiveId,
          orElse: () => {},
        );
        if (current.isNotEmpty) {
          _applyConsensusStateFromPayload(current);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDiscovery = false);
      }
    }
  }

  Future<void> _loadModerationReports() async {
    if (!_isMilitantTechnician && !_isElectedModerator) return;
    setState(() => _loadingModeration = true);
    try {
      final api = await ApiService.getInstance();
      final list = await api.getLiveReports();
      if (!mounted) return;
      setState(() {
        _moderationReports = list;
        _loadingModeration = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingModeration = false);
      }
    }
  }

  Future<void> _refreshCurrentLiveConsensusState() async {
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      _api ??= await ApiService.getInstance();
      final live = await _api!.fetchLiveDetails(liveId);
      _applyConsensusStateFromPayload(live);
    } catch (_) {}
  }

  void _applyConsensusStateFromPayload(Map<String, dynamic> payload) {
    if (!mounted) return;
    final nextReportCount =
        int.tryParse(payload['report_count']?.toString() ?? '') ?? _reportCount;
    final isSuspended =
        payload['is_suspended'] == true || payload['is_suspended'] == 1;

    setState(() {
      _reportCount = nextReportCount;
      if (isSuspended) {
        _isSuspendedByConsensus = true;
      }
      // Update title as well if present in payload
      final remoteTitle = payload['title']?.toString().trim();
      if (remoteTitle != null && remoteTitle.isNotEmpty) {
        _currentLiveTitle = remoteTitle;
      }
    });

    if (isSuspended && _room != null) {
      unawaited(_disconnectRoom());
    }
  }

  void _showSuspensionWarning() {
    if (!mounted) return;
    final translate = LanguageService.instance.translate;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131313),
        title: Text(
          translate('live_suspended_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          translate('live_suspended_message'),
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              translate('live_suspended_ack'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );
  }

  int? _parseLiveIdFromRoom(String room) {
    final m = RegExp(
      r'^live-(\d+)$',
      caseSensitive: false,
    ).firstMatch(room.trim());
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  int? _parseUserIdFromIdentity(String? identity) {
    if (identity == null) return null;
    final match = RegExp(r'^u(\d+)-', caseSensitive: false).firstMatch(identity);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _detachLivekitChatListener() async {
    final c = _livekitDataCancel;
    _livekitDataCancel = null;
    if (c != null) await c();
  }

  bool _isModeratorIdentity(String? identity) {
    return identity != null && _sessionModeratorIdentities.contains(identity);
  }

  bool _isModeratorUserId(int? userId) {
    return userId != null && _sessionModeratorUserIds.contains(userId);
  }

  _LiveKitChatEntry? _buildChatEntryFromEvent(
    DataReceivedEvent event,
    String raw,
  ) {
    final participant = event.participant;
    final participantIdentity = participant?.identity;
    final participantName = participant?.name.trim() ?? '';
    final fallbackName = participantName.isNotEmpty
        ? participantName
        : (participantIdentity ?? '?');

    var displayAuthor = fallbackName;
    var message = raw;
    int? authorUserId = _parseUserIdFromIdentity(participantIdentity);
    int? commentId;
    final trimmed = raw.trim();

    if (trimmed.startsWith('{')) {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        message = map['m']?.toString() ?? raw;
        final embeddedName = map['n']?.toString().trim() ?? '';
        if (embeddedName.isNotEmpty) {
          displayAuthor = embeddedName;
        }
        authorUserId ??= int.tryParse(map['uid']?.toString() ?? '');
        commentId = int.tryParse(map['cid']?.toString() ?? '');
      }
    }

    if (message.trim().isEmpty) {
      return null;
    }

    final dedupeKey = commentId != null && commentId > 0
        ? 'server:$commentId'
        : _chatKey(displayAuthor, message);

    return _LiveKitChatEntry(
      author: displayAuthor,
      text: message,
      dedupeKey: dedupeKey,
      authorIdentity: participantIdentity,
      authorUserId: authorUserId,
      commentId: commentId,
      isModerator:
          _isModeratorIdentity(participantIdentity) ||
          _isModeratorUserId(authorUserId),
    );
  }

  Future<void> _attachLivekitChatListener(Room room) async {
    await _detachLivekitChatListener();
    if (!mounted) return;
    _livekitDataCancel = room.events.on<DataReceivedEvent>((event) async {
      final topic = event.topic;
      if (topic == _livekitChatTopic) {
        try {
          final raw = utf8.decode(event.data);
          final entry = _buildChatEntryFromEvent(event, raw);
          if (entry != null) {
            _appendChatEntry(entry);
          }
        } catch (_) {}
        return;
      }

      if (topic == _livekitControlTopic) {
        await _handleLiveControlEvent(event);
        return;
      }

      if (topic != null) return;
      try {
        final raw = utf8.decode(event.data);
        final entry = _buildChatEntryFromEvent(event, raw);
        if (entry != null) {
          _appendChatEntry(entry);
        }
      } catch (_) {}
    });
  }

  Future<void> _sendLivekitChatMessage() async {
    final translate = LanguageService.instance.translate;
    final room = _room;
    final local = room?.localParticipant;
    if (local == null || _isSendingChat) return;
    if (_isLocalBlockedFromChat) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate('live_chat_blocked_self'))),
        );
      }
      return;
    }
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    final nick = _displayNameController.text.trim();
    final liveId = _streamingLiveId;
    _chatInputController.clear();
    setState(() => _isSendingChat = true);
    try {
      int? commentId;
      if (liveId != null) {
        final api = await ApiService.getInstance();
        commentId = await api.postLiveComment(liveId, text);
      }
      final payload = jsonEncode({
        'v': 1,
        'n': nick,
        'm': text,
        if (_currentUserId != null) 'uid': _currentUserId,
        if (commentId != null) 'cid': commentId,
      });
      _appendChatEntry(
        _LiveKitChatEntry(
          author: nick.isNotEmpty ? nick : 'Moi',
          text: text,
          dedupeKey: commentId != null
              ? 'server:$commentId'
              : _chatKey(nick, text),
          authorIdentity: local.identity,
          authorUserId: _currentUserId,
          commentId: commentId,
          isModerator: _canModerateLive,
        ),
      );
      await local.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: _livekitChatTopic,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingChat = false);
      }
    }
  }

  Future<void> _handleLiveControlEvent(DataReceivedEvent event) async {
    try {
      final translate = LanguageService.instance.translate;
      final raw = utf8.decode(event.data);
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      final type = data['t']?.toString() ?? '';
      final senderIdentity = event.participant?.identity ?? '';
      final participant = event.participant;
      final participantName = participant?.name.trim() ?? '';
      final senderName = data['n']?.toString().trim().isNotEmpty == true
          ? data['n']!.toString().trim()
          : (participantName.isNotEmpty ? participantName : senderIdentity);

      if (type == 'join-request' && _isCreator) {
        if (senderIdentity.isEmpty) return;
        final senderUserId = int.tryParse(data['uid']?.toString() ?? '');
        if (_blockedParticipantIdentities.contains(senderIdentity) ||
            (senderUserId != null &&
                _blockedParticipantUserIds.contains(senderUserId))) {
          return;
        }
        if (senderUserId == null || senderUserId <= 0) {
          unawaited(_loadPendingGuestRequests());
          return;
        }
        final existingIndex = _guestRequests.indexWhere(
          (request) =>
              request.identity == senderIdentity ||
              request.userId == senderUserId,
        );
        if (existingIndex != -1) {
          final existing = _guestRequests[existingIndex];
          if (existing.identity == null && mounted) {
            setState(() {
              final next = List<_LiveGuestRequest>.from(_guestRequests);
              next[existingIndex] = _LiveGuestRequest(
                identity: senderIdentity,
                userId: existing.userId,
                name: existing.name,
              );
              _guestRequests = next;
            });
          }
          return;
        }
        if (!mounted) return;
        setState(() {
          _guestRequests = [
            ..._guestRequests,
            _LiveGuestRequest(
              identity: senderIdentity,
              userId: senderUserId,
              name: senderName,
            ),
          ];
        });
        return;
      }

      if (type == 'join-approved' && !_isCreator) {
        if (mounted) {
          setState(() => _hasPendingJoinRequest = false);
        }
        await _promoteViewerToSpeaker();
        return;
      }

      if (type == 'join-rejected' && !_isCreator) {
        if (!mounted) return;
        setState(() => _hasPendingJoinRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translate('live_join_request_rejected'))),
        );
        return;
      }

      if (type == 'moderator-assigned') {
        final targetIdentity = data['targetIdentity']?.toString() ?? '';
        final targetUserId = int.tryParse(data['targetUserId']?.toString() ?? '');
        if (targetIdentity.isEmpty || !mounted) return;
        setState(() {
          _sessionModeratorIdentities.add(targetIdentity);
          if (targetUserId != null && targetUserId > 0) {
            _sessionModeratorUserIds.add(targetUserId);
          }
          _livekitChatMessages = _livekitChatMessages
              .map(
                (entry) => entry.authorIdentity == targetIdentity ||
                        (targetUserId != null && entry.authorUserId == targetUserId)
                    ? entry.copyWith(isModerator: true)
                    : entry,
              )
              .toList();
        });
        if (_sessionIdentity == targetIdentity ||
            (_currentUserId != null && _currentUserId == targetUserId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translate('live_moderator_assigned_self'))),
          );
        }
        return;
      }

      if (type == 'chat-blocked') {
        final targetIdentity = data['targetIdentity']?.toString() ?? '';
        final targetName = data['targetName']?.toString().trim() ?? '';
        final targetUserId = int.tryParse(data['targetUserId']?.toString() ?? '');
        if (!mounted) return;
        setState(() {
          if (targetIdentity.isNotEmpty) {
            _blockedParticipantIdentities.add(targetIdentity);
          }
          if (targetName.isNotEmpty) {
            _blockedParticipantNames.add(targetName.toLowerCase());
          }
          if (targetUserId != null && targetUserId > 0) {
            _blockedParticipantUserIds.add(targetUserId);
          }
          _guestRequests = _guestRequests
              .where(
                (request) =>
                    request.identity != targetIdentity &&
                    (targetUserId == null || request.userId != targetUserId),
              )
              .toList();
          _livekitChatMessages = _livekitChatMessages
              .where((entry) => !_isChatEntryBlocked(entry))
              .toList();
          _chatDedupKeys
            ..clear()
            ..addAll(_livekitChatMessages.map((entry) => entry.dedupeKey));
        });
        if (_sessionIdentity == targetIdentity ||
            (_currentUserId != null && _currentUserId == targetUserId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translate('live_chat_blocked_self'))),
          );
        }
        return;
      }

      if (type == 'chat-message-deleted') {
        final dedupeKey = data['dedupeKey']?.toString() ?? '';
        final commentId = int.tryParse(data['commentId']?.toString() ?? '');
        final effectiveDedupeKey = commentId != null && commentId > 0
            ? 'server:$commentId'
            : dedupeKey;
        if (effectiveDedupeKey.isEmpty || !mounted) return;
        setState(() {
          _deletedChatKeys.add(effectiveDedupeKey);
          _livekitChatMessages = _livekitChatMessages
              .where((entry) => entry.dedupeKey != effectiveDedupeKey)
              .toList();
          _chatDedupKeys.remove(effectiveDedupeKey);
        });
        return;
      }

      if (type == 'live-background-set') {
        final imageUrl = data['imageUrl']?.toString().trim() ?? '';
        if (imageUrl.isEmpty || !mounted) return;
        setState(() {
          _liveBackgroundImageUrl = imageUrl;
        });
        return;
      }

      if (type == 'live-background-cleared') {
        if (!mounted) return;
        setState(() {
          _liveBackgroundImageUrl = null;
        });
      }
    } catch (_) {}
  }

  void _appendChatEntry(_LiveKitChatEntry entry) {
    if (!mounted) return;
    if (_deletedChatKeys.contains(entry.dedupeKey)) {
      return;
    }
    if (_isChatEntryBlocked(entry)) {
      return;
    }
    if (_chatDedupKeys.contains(entry.dedupeKey)) {
      return;
    }
    setState(() {
      _chatDedupKeys.add(entry.dedupeKey);
      _livekitChatMessages.add(entry);
      while (_livekitChatMessages.length > 300) {
        final removed = _livekitChatMessages.removeAt(0);
        _chatDedupKeys.remove(removed.dedupeKey);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  String _chatKey(String author, String text) {
    return '${author.trim().toLowerCase()}|${text.trim().toLowerCase()}';
  }

  bool _isChatEntryBlocked(_LiveKitChatEntry entry) {
    if (entry.authorUserId != null &&
        _blockedParticipantUserIds.contains(entry.authorUserId)) {
      return true;
    }
    if (entry.authorIdentity != null &&
        _blockedParticipantIdentities.contains(entry.authorIdentity)) {
      return true;
    }
    return _blockedParticipantNames.contains(entry.author.trim().toLowerCase());
  }

  bool get _isLocalBlockedFromChat {
    if (_currentUserId != null &&
        _blockedParticipantUserIds.contains(_currentUserId)) {
      return true;
    }
    return _sessionIdentity != null &&
        _blockedParticipantIdentities.contains(_sessionIdentity);
  }

  Future<void> _loadLiveComments() async {
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      final api = await ApiService.getInstance();
      final comments = await api.fetchLiveComments(liveId);
      for (final comment in comments) {
        final author = comment['username']?.toString().trim().isNotEmpty == true
            ? comment['username']!.toString().trim()
            : (comment['name']?.toString().trim().isNotEmpty == true
                  ? comment['name']!.toString().trim()
                  : 'Militant');
        final text =
            comment['content']?.toString() ??
            comment['comment']?.toString() ??
            comment['message']?.toString() ??
            '';
        if (text.trim().isEmpty) continue;
        final serverId = int.tryParse(comment['id']?.toString() ?? '');
        final authorUserId = int.tryParse(comment['user_id']?.toString() ?? '');
        _appendChatEntry(
          _LiveKitChatEntry(
            author: author,
            text: text,
            dedupeKey: serverId != null && serverId > 0
                ? 'server:$serverId'
                : _chatKey(author, text),
            authorIdentity: null,
            authorUserId: authorUserId,
            commentId: serverId,
            isModerator: _isModeratorUserId(authorUserId),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _loadPersistedLiveBackground() async {
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      final api = await ApiService.getInstance();
      final live = await api.fetchLiveDetails(liveId);
      final rawPath = live['background_image']?.toString().trim();
      final resolvedUrl = api.getImageUrl(rawPath);
      final nextUrl = resolvedUrl ?? rawPath;
      if (!mounted) return;
      setState(() {
        _liveBackgroundImageUrl = nextUrl != null && nextUrl.isNotEmpty
            ? nextUrl
            : null;
      });
    } catch (_) {}
  }

  void _startLiveCommentsPolling() {
    _stopLiveCommentsPolling();
    if (_streamingLiveId == null) return;
    _liveCommentsPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_loadLiveComments());
      if (_isCreator && mounted) {
        unawaited(_loadPendingGuestRequests());
      }
      unawaited(_loadModerationState());
      unawaited(_refreshCurrentLiveConsensusState());
      if ((_isMilitantTechnician || _isElectedModerator) && mounted) {
        unawaited(_loadModerationReports());
      }
      unawaited(_loadDiscoveryLives());
    });
  }

  void _stopLiveCommentsPolling() {
    _liveCommentsPollTimer?.cancel();
    _liveCommentsPollTimer = null;
  }

  void _startLivePing() {
    _stopLivePing();
    if (_streamingLiveId == null) return;
    // Send ping every 60 seconds to keep the live active
    _livePingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_sendLivePing());
    });
  }

  void _stopLivePing() {
    _livePingTimer?.cancel();
    _livePingTimer = null;
  }

  Future<void> _sendLivePing() async {
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      final api = await ApiService.getInstance();
      await api.joinLivePing(liveId);
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('suspended') || err.contains('423')) {
        if (!mounted) return;
        setState(() {
          _isSuspendedByConsensus = true;
        });
        unawaited(_disconnectRoom());
      }
    }
  }

  Future<void> _loadPendingGuestRequests() async {
    final liveId = _streamingLiveId;
    if (!_isCreator || liveId == null) return;
    try {
      _api ??= await ApiService.getInstance();
      final guests = await _api!.fetchLiveGuests(liveId, status: 'pending');
      if (!mounted) return;
      setState(() {
        _guestRequests = guests
            .map(
              (guest) => _LiveGuestRequest(
                userId:
                    int.tryParse(guest['user_id']?.toString() ?? '') ?? 0,
                name: guest['username']?.toString().trim().isNotEmpty == true
                    ? guest['username'].toString().trim()
                    : 'Militant',
              ),
            )
            .where((guest) => guest.userId > 0)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading pending guest requests: $e');
    }
  }

  Future<void> _loadModerationState() async {
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      _api ??= await ApiService.getInstance();
      final state = await _api!.fetchLiveModerationState(liveId);
      if (!mounted) return;

      final moderatorIds = ((state['moderator_user_ids'] as List?) ?? const [])
          .map((value) => int.tryParse(value.toString()))
          .whereType<int>()
          .toSet();
      final blockedIds = ((state['blocked_user_ids'] as List?) ?? const [])
          .map((value) => int.tryParse(value.toString()))
          .whereType<int>()
          .toSet();
      final myIsModerator =
          state['my_is_moderator'] == true ||
          state['my_is_moderator'] == 1 ||
          state['my_is_moderator'] == '1';
      final myChatBlocked =
          state['my_chat_blocked'] == true ||
          state['my_chat_blocked'] == 1 ||
          state['my_chat_blocked'] == '1';

      setState(() {
        _sessionModeratorUserIds
          ..clear()
          ..addAll(moderatorIds);
        if (myIsModerator && _currentUserId != null) {
          _sessionModeratorUserIds.add(_currentUserId!);
        }
        _blockedParticipantUserIds
          ..clear()
          ..addAll(blockedIds);
        if (myChatBlocked && _currentUserId != null) {
          _blockedParticipantUserIds.add(_currentUserId!);
        }
        _livekitChatMessages = _livekitChatMessages
            .where((entry) => !_isChatEntryBlocked(entry))
            .map(
              (entry) => entry.copyWith(
                isModerator:
                    _isModeratorIdentity(entry.authorIdentity) ||
                    _isModeratorUserId(entry.authorUserId),
              ),
            )
            .toList();
        _chatDedupKeys
          ..clear()
          ..addAll(_livekitChatMessages.map((entry) => entry.dedupeKey));
      });
    } catch (_) {}
  }

  Future<void> _loadLiveKitOverrides() async {
    if (!mounted) return;
    if (!_isMilitantTechnician) {
      _livekitUrlController.clear();
      _livekitTokenEndpointController.clear();
      setState(() {});
      return;
    }
    final su = await LiveKitRuntimeConfig.getStoredServerUrl();
    final te = await LiveKitRuntimeConfig.getStoredTokenEndpoint();
    if (!mounted) return;
    if (su != null) {
      _livekitUrlController.text = su;
    }
    if (te != null) {
      _livekitTokenEndpointController.text = te;
    } else {
      _livekitTokenEndpointController.text = LiveKitConfig.tokenEndpoint;
    }
    setState(() {});
  }

  Future<void> _hydrateProfile() async {
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();
      if (!mounted) return;

      final tech = profile['is_militant_technician'];
      _isMilitantTechnician = tech == true || tech == 1 || tech == '1';
      _isElectedModerator = await api.checkIfModerator();
      _currentUserId = await api.getCurrentUserId();

      final username =
          profile['username']?.toString().trim() ??
          profile['name']?.toString().trim() ??
          '';

      if (username.isNotEmpty) {
        _displayNameController.text = username;
        // Pre-fill room title automatically
        final translate = LanguageService.instance.translate;
        _roomController.text = translate(
          'live_default_title',
        ).replaceFirst('{name}', username);
      }
      setState(() {});
    } catch (_) {
      if (_displayNameController.text.trim().isEmpty) {
        _displayNameController.text = 'militant';
      }
    }
  }

  bool get _isConnected => _room != null;
  bool get _isCreator => _mode == _LiveMode.creator;
  bool get _canControlBroadcast => _sessionCanPublish;
  bool get _isSessionModerator =>
      _isModeratorIdentity(_sessionIdentity) ||
      _isModeratorUserId(_currentUserId);
  bool get _canModerateLive => _isCreator || _isSessionModerator;

  Future<void> _joinLive({bool? canPublishOverride}) async {
    if (_isConnecting) return;
    final translate = LanguageService.instance.translate;
    final roomName = _roomController.text.trim();
    final displayName = _displayNameController.text.trim();
    final wantsPublish = canPublishOverride ?? _isCreator;
    if (_currentUserId == null) {
      try {
        _api ??= await ApiService.getInstance();
        _currentUserId = await _api!.getCurrentUserId();
      } catch (_) {}
    }

    if (_isMilitantTechnician) {
      await LiveKitRuntimeConfig.setServerUrlOverride(
        _livekitUrlController.text,
      );
      await LiveKitRuntimeConfig.setTokenEndpointOverride(
        _livekitTokenEndpointController.text,
      );
    }

    final hasTokenEndpoint =
        await LiveKitRuntimeConfig.hasEffectiveTokenEndpoint(
          useDeviceOverrides: _isMilitantTechnician,
        );
    if (!hasTokenEndpoint && !LiveKitConfig.canGenerateTokenOnDevice) {
      setState(() {
        _errorMessage = translate('live_error_missing_token_endpoint');
      });
      return;
    }

    if (roomName.isEmpty || displayName.isEmpty) {
      setState(() {
        _errorMessage = translate('live_error_missing_room_or_name');
      });
      return;
    }

    if (_isCreator) {
      final granted = await _requestBroadcastPermissions();
      if (!granted) {
        setState(() {
          _errorMessage = translate('live_error_missing_broadcast_permissions');
        });
        return;
      }
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    int? createdLiveId;

    try {
      await _disconnectRoom();

      String effectiveRoom = roomName;
      int? liveIdForToken;

      if (_isCreator) {
        final api = await ApiService.getInstance();
        try {
          // even for technicians, we register in CMS unless the room name starts with 'test-'
          if (!_isMilitantTechnician || !roomName.startsWith('test-')) {
            final newId = await api.createLiveSession(title: roomName);
            liveIdForToken = newId;
            createdLiveId = newId;
            effectiveRoom = 'live-$newId';
          } else {
            effectiveRoom = roomName;
            liveIdForToken = null;
          }
        } catch (e) {
          if (!_isMilitantTechnician) rethrow;
          // Technicians can fallback to direct room name if CMS fails
          effectiveRoom = roomName;
          liveIdForToken = null;
        }
      }

      final creds = await LiveKitTokenService.issueJoinCredentials(
        roomName: effectiveRoom,
        identity: _buildIdentity(displayName, userId: _currentUserId),
        displayName: displayName,
        canPublish: wantsPublish,
        useDeviceOverrides: _isMilitantTechnician,
        liveId: liveIdForToken,
      );

      final wsUrl = await LiveKitRuntimeConfig.effectiveServerUrl(
        fromApi: creds.serverUrlFromApi,
        useDeviceOverrides: _isMilitantTechnician,
      );
      if (wsUrl.isEmpty) {
        setState(() {
          _errorMessage = translate('live_error_missing_server_url');
        });
        return;
      }

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      room.addListener(_handleRoomChanged);
      await room.connect(wsUrl, creds.token);

      if (wantsPublish) {
        final localParticipant = room.localParticipant;
        if (localParticipant != null) {
          await localParticipant.setCameraEnabled(_cameraEnabled);
          await localParticipant.setMicrophoneEnabled(_microphoneEnabled);
        }
      }

      if (!mounted) {
        await room.disconnect();
        await room.dispose();
        return;
      }

      final streamLiveId = _parseLiveIdFromRoom(effectiveRoom);
      if (streamLiveId != null) {
        try {
          final api = await ApiService.getInstance();
          await api.joinLivePing(streamLiveId);
          if (_isCreator) {
            unawaited(_loadDiscoveryLives());
          }
        } catch (_) {}
      }

      if (!mounted) return;

      final localIdentity = room.localParticipant?.identity;

      setState(() {
        _room = room;
        _streamingLiveId = streamLiveId;
        _livekitChatMessages = [];
        _chatDedupKeys.clear();
        _deletedChatKeys.clear();
        _blockedParticipantIdentities.clear();
        _blockedParticipantNames.clear();
        _blockedParticipantUserIds.clear();
        _sessionModeratorIdentities.clear();
        _sessionModeratorUserIds.clear();
        _liveBackgroundImageFile = null;
        _liveBackgroundImageUrl = null;
        _guestRequests = [];
        _sessionCanPublish = wantsPublish;
        _sessionIdentity = localIdentity;
        // Optimization: DO NOT overwrite _roomController.text if it was typed by user
        // Instead, use _currentLiveTitle for display
        _currentLiveTitle = _currentLiveTitle ?? effectiveRoom;
      });

      await _attachLivekitChatListener(room);
      await _loadPersistedLiveBackground();
      await _refreshCurrentLiveConsensusState();
      await _loadModerationState();
      await _loadLiveComments();
      await _loadPendingGuestRequests();
      _startLiveCommentsPolling();
      _startLivePing();
    } catch (error) {
      if (_isCreator && createdLiveId != null) {
        try {
          final api = await ApiService.getInstance();
          await api.endLiveSession(createdLiveId);
        } catch (cleanupError) {
          debugPrint('Error cleaning up failed live session: $cleanupError');
        }
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<bool> _requestBroadcastPermissions() async {
    final camera = await Permission.camera.request();
    final microphone = await Permission.microphone.request();
    return camera.isGranted && microphone.isGranted;
  }

  Future<void> _disconnectRoom() async {
    final liveId = _streamingLiveId;
    final isCreator = _isCreator;

    await _detachLivekitChatListener();
    _stopLiveCommentsPolling();

    if (isCreator && liveId != null) {
      try {
        final api = await ApiService.getInstance();
        await api.endLiveSession(liveId);
      } catch (e) {
        debugPrint('Error ending live session: $e');
      }
    }

    if (mounted) {
      setState(() {
        _streamingLiveId = null;
        _livekitChatMessages = [];
        _chatDedupKeys.clear();
        _deletedChatKeys.clear();
        _blockedParticipantIdentities.clear();
        _blockedParticipantNames.clear();
        _blockedParticipantUserIds.clear();
        _sessionModeratorIdentities.clear();
        _sessionModeratorUserIds.clear();
        _liveBackgroundImageFile = null;
        _sessionCanPublish = false;
        _sessionIdentity = null;
        _liveBackgroundImageUrl = null;
        _guestRequests = [];
        _hasPendingJoinRequest = false;
        _currentLiveTitle = null;
      });
    }

    final room = _room;
    if (room == null) return;

    room.removeListener(_handleRoomChanged);
    try {
      await room.disconnect();
    } catch (_) {}

    try {
      await room.dispose();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _room = null;
      });
      if (_isSuspendedByConsensus) {
        _showSuspensionWarning();
        _isSuspendedByConsensus = false;
      }
      unawaited(_loadDiscoveryLives());
    }
  }

  void _handleRoomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _buildIdentity(String displayName, {int? userId}) {
    final slug = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final base = slug.isEmpty ? 'militant' : slug;
    if (userId != null && userId > 0) {
      return 'u$userId-$base-$suffix';
    }
    return '$base-$suffix';
  }

  Future<void> _toggleCamera() async {
    final room = _room;
    if (room == null || !_canControlBroadcast) return;
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    final next = !_cameraEnabled;
    await localParticipant.setCameraEnabled(next);
    if (!mounted) return;
    setState(() {
      _cameraEnabled = next;
    });
  }

  Future<void> _toggleMicrophone() async {
    final room = _room;
    if (room == null || !_canControlBroadcast) return;
    final localParticipant = room.localParticipant;
    if (localParticipant == null) return;

    final next = !_microphoneEnabled;
    await localParticipant.setMicrophoneEnabled(next);
    if (!mounted) return;
    setState(() {
      _microphoneEnabled = next;
    });
  }

  Future<void> _pickLiveBackgroundImage() async {
    final translate = LanguageService.instance.translate;
    if (!_canControlBroadcast || _isUpdatingLiveBackground) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 88,
    );
    if (pickedFile == null || !mounted) return;

    final file = File(pickedFile.path);
    setState(() {
      _liveBackgroundImageFile = file;
      _isUpdatingLiveBackground = true;
    });

    try {
      final api = await ApiService.getInstance();
      final uploadedPath = await api.uploadFile(file.path, type: 'posts');
      final imageUrl = api.getImageUrl(uploadedPath) ?? uploadedPath;
      final liveId = _streamingLiveId;
      if (liveId != null) {
        await api.updateLiveBackground(liveId, backgroundImage: uploadedPath);
      }
      await _sendControlMessage({
        'v': 1,
        't': 'live-background-set',
        'imageUrl': imageUrl,
      });
      if (!mounted) return;
      setState(() {
        _liveBackgroundImageUrl = imageUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_background_enabled'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translate('live_background_add_error')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLiveBackground = false;
        });
      }
    }
  }

  Future<void> _clearLiveBackgroundImage() async {
    final translate = LanguageService.instance.translate;
    if (!_canControlBroadcast || _isUpdatingLiveBackground) return;
    setState(() => _isUpdatingLiveBackground = true);
    try {
      final liveId = _streamingLiveId;
      if (liveId != null) {
        final api = await ApiService.getInstance();
        await api.updateLiveBackground(liveId, backgroundImage: null);
      }
      await _sendControlMessage({'v': 1, 't': 'live-background-cleared'});
      if (!mounted) return;
      setState(() {
        _liveBackgroundImageFile = null;
        _liveBackgroundImageUrl = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_background_removed'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translate('live_background_remove_error')}: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLiveBackground = false);
      }
    }
  }

  Future<void> _openLiveBackgroundSheet() async {
    final translate = LanguageService.instance.translate;
    if (!_canControlBroadcast) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131313),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: Text(
                  translate('live_background_pick'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  translate('live_background_pick_subtitle'),
                  style: const TextStyle(color: Colors.white60),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickLiveBackgroundImage();
                },
              ),
              if (_liveBackgroundImageUrl != null ||
                  _liveBackgroundImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    translate('live_background_remove'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _clearLiveBackgroundImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<VideoTrack> _participantTracks() {
    final room = _room;
    if (room == null) return [];
    final tracks = <VideoTrack>[];

    final local = room.localParticipant;
    if (local != null) {
      for (final pub in local.videoTrackPublications) {
        final t = pub.track;
        if (t is VideoTrack && !pub.muted) {
          tracks.add(t as VideoTrack);
        }
      }
    }

    for (final p in room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final t = pub.track;
        if (t is VideoTrack && !pub.muted) {
          tracks.add(t as VideoTrack);
        }
      }
    }
    return tracks;
  }

  Widget _buildLiveBackdrop(String displayName) {
    final localFile = _liveBackgroundImageFile;
    final remoteImageUrl = _liveBackgroundImageUrl;

    if (localFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(localFile, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.28)),
          _buildLiveBackdropOverlay(displayName),
        ],
      );
    }

    if (remoteImageUrl != null && remoteImageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            remoteImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultLiveBackdrop(),
          ),
          Container(color: Colors.black.withValues(alpha: 0.28)),
          _buildLiveBackdropOverlay(displayName),
        ],
      );
    }

    return _buildDefaultLiveBackdrop();
  }

  Widget _buildDefaultLiveBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF6A1111), Color(0xFF120606), Colors.black],
          radius: 1.2,
        ),
      ),
      child: const Center(
        child: Icon(Icons.live_tv_rounded, color: Colors.white24, size: 96),
      ),
    );
  }

  Widget _buildLiveBackdropOverlay(String displayName) {
    final trimmedName = displayName.trim();
    final initial = trimmedName.isEmpty
        ? 'M'
        : trimmedName.substring(0, 1).toUpperCase();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName.isEmpty ? 'Militant' : displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService.instance.translate('live_camera_off_state'),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  int _viewerCount() {
    final room = _room;
    if (room == null) return 0;
    return room.remoteParticipants.length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final translate = LanguageService.instance.translate;
    final theme = Theme.of(context);

    if (_isConnected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: _buildLiveRoom(context)),
      );
    }

    return DefaultTabController(
      length: (_isMilitantTechnician || _isElectedModerator) ? 3 : 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(translate('live_title')),
          elevation: 0,
          backgroundColor: theme.appBarTheme.backgroundColor,
          bottom: TabBar(
            indicatorColor: const Color(0xFFBE1E1E),
            labelColor: const Color(0xFFBE1E1E),
            unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withValues(
              alpha: 0.6,
            ),
            tabs: [
              Tab(text: translate('live_tab_discover')),
              Tab(text: translate('live_tab_create')),
              if (_isMilitantTechnician || _isElectedModerator)
                Tab(text: translate('live_tab_moderation')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDiscoveryTab(context),
            _buildCreateTab(context),
            if (_isMilitantTechnician || _isElectedModerator) _buildModerationTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryTab(BuildContext context) {
    final theme = Theme.of(context);
    final translate = LanguageService.instance.translate;
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadDiscoveryLives,
      child: _loadingDiscovery && _discoveryLives.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _discoveryLives.isEmpty
          ? _buildEmptyDiscovery(translate, theme)
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: _discoveryLives.length,
              itemBuilder: (context, index) {
                final live = _discoveryLives[index];
                return _buildDiscoveryCard(
                  context,
                  live,
                  isDark,
                  translate,
                  theme,
                );
              },
            ),
    );
  }

  Widget _buildModerationTab(BuildContext context) {
    final theme = Theme.of(context);
    final translate = LanguageService.instance.translate;

    return RefreshIndicator(
      onRefresh: _loadModerationReports,
      child: _loadingModeration && _moderationReports.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _moderationReports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 64,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    translate('live_moderation_empty_reports'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _moderationReports.length,
              itemBuilder: (context, index) {
                final report = _moderationReports[index];
                final liveTitle =
                    report['title'] ?? translate('live_moderation_untitled');
                final creator = report['creator_name'] ?? '?';
                final reporter =
                    report['reporter_name'] ??
                    translate('live_moderation_anonymous');
                final reason =
                    report['reason'] ??
                    translate('live_moderation_other_reason');
                final desc = report['description'] ?? '';
                final isEnded = report['live_status'] == 'ended';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isEnded ? Colors.grey : const Color(0xFFBE1E1E),
                      child: Icon(
                        isEnded ? Icons.stop_rounded : Icons.live_tv_rounded,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      liveTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translate(
                            'live_moderation_creator_label',
                          ).replaceFirst('{name}', creator.toString()),
                        ),
                        Text(
                          translate(
                            'live_moderation_reporter_label',
                          ).replaceFirst('{name}', reporter.toString()),
                        ),
                        Text(
                          translate(
                            'live_moderation_reason_label',
                          ).replaceFirst('{reason}', reason.toString()),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        if (desc.isNotEmpty)
                          Text(
                            translate(
                              'live_moderation_detail_label',
                            ).replaceFirst('{detail}', desc.toString()),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Optionnel: Ouvrir le live ou le détail
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyDiscovery(Function translate, ThemeData theme) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Icon(Icons.live_tv_rounded, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                translate('live_discovery_empty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.disabledColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryCard(
    BuildContext context,
    Map<String, dynamic> live,
    bool isDark,
    Function translate,
    ThemeData theme,
  ) {
    final id = live['id'];
    final title = live['title']?.toString() ?? 'Live';
    final user = live['username']?.toString() ?? 'Militant';
    final avatarUrl = _api?.getImageUrl(live['avatar']?.toString());
    final viewers = live['current_viewers']?.toString() ?? '0';
    final backgroundUrl = _api?.getImageUrl(live['background_image']?.toString());

    bool isValidUrl(String? url) => url != null && url.startsWith('http');

    return InkWell(
      onTap: () => _joinDirectly(id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
          image: isValidUrl(backgroundUrl)
              ? DecorationImage(
                  image: NetworkImage(backgroundUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Lightweight discovery card: never open a LiveKit room here.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isValidUrl(backgroundUrl)
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFBE1E1E), Color(0xFF131313)],
                        ),
                ),
                child: isValidUrl(backgroundUrl)
                    ? const SizedBox.shrink()
                    : Center(
                        child: Opacity(
                          opacity: 0.28,
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: SvgPicture.asset(
                              'assets/logo.svg',
                              width: 72,
                              height: 72,
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // GRADIENT OVERLAY
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.2, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // LIVE TAG
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE1E1E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'DIRECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // VIEWER COUNT
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.remove_red_eye, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      viewers,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTTOM INFO
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white24,
                        backgroundImage: isValidUrl(avatarUrl)
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: !isValidUrl(avatarUrl)
                            ? const Icon(Icons.person, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          user,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final translate = LanguageService.instance.translate;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          translate('live_setup_subtitle'),
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _roomController,
                decoration: _fieldDecoration(
                  translate('live_field_title_label'),
                  translate('live_field_title_hint'),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile.adaptive(
                value: _cameraEnabled,
                activeThumbColor: const Color(0xFFBE1E1E),
                activeTrackColor: const Color(
                  0xFFBE1E1E,
                ).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                title: Text(translate('live_camera_label')),
                subtitle: Text(translate('live_camera_subtitle')),
                onChanged: (v) => setState(() => _cameraEnabled = v),
              ),
              SwitchListTile.adaptive(
                value: _microphoneEnabled,
                activeThumbColor: const Color(0xFFBE1E1E),
                activeTrackColor: const Color(
                  0xFFBE1E1E,
                ).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                title: Text(translate('live_mic_label')),
                subtitle: Text(translate('live_mic_subtitle')),
                onChanged: (v) => setState(() => _microphoneEnabled = v),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isConnecting ? null : _startAsCreator,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBE1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isConnecting
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          translate('live_button_start'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_isMilitantTechnician) _buildConfigHints(),
      ],
    );
  }

  void _joinDirectly(dynamic id) {
    if (id == null) return;
    setState(() {
      _mode = _LiveMode.viewer;
      _roomController.text = 'live-$id';
    });
    _joinLive();
  }

  void _startAsCreator() {
    setState(() => _mode = _LiveMode.creator);
    _joinLive();
  }

  Future<void> _sendControlMessage(
    Map<String, dynamic> payload, {
    List<String>? destinationIdentities,
  }) async {
    final local = _room?.localParticipant;
    if (local == null) {
      throw Exception(
        LanguageService.instance.translate('live_local_participant_unavailable'),
      );
    }
    await local.publishData(
      utf8.encode(jsonEncode(payload)),
      reliable: true,
      destinationIdentities: destinationIdentities,
      topic: _livekitControlTopic,
    );
  }

  Future<void> _requestToJoinBroadcast() async {
    final translate = LanguageService.instance.translate;
    if (_hasPendingJoinRequest || _isPromotingToSpeaker) return;
    final liveId = _streamingLiveId;
    if (liveId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_not_found_for_request'))),
      );
      return;
    }
    if (_isLocalBlockedFromChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_join_blocked_from_chat'))),
      );
      return;
    }
    try {
      _api ??= await ApiService.getInstance();
      _currentUserId ??= await _api!.getCurrentUserId();
      if (_currentUserId == null || _currentUserId! <= 0) {
        throw Exception(translate('live_user_not_found'));
      }
      final requestResult = await _api!.requestLiveGuestAccess(liveId);
      if ((requestResult['status']?.toString() ?? '') == 'accepted') {
        if (mounted) {
          setState(() => _hasPendingJoinRequest = false);
        }
        await _promoteViewerToSpeaker();
        return;
      }
      await _sendControlMessage({
        'v': 1,
        't': 'join-request',
        'n': _displayNameController.text.trim(),
        'uid': _currentUserId,
      });
      if (!mounted) return;
      setState(() => _hasPendingJoinRequest = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_join_request_sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translate('live_guest_request_error')}: $e'),
        ),
      );
    }
  }

  Future<void> _approveGuestRequest(_LiveGuestRequest request) async {
    final translate = LanguageService.instance.translate;
    if (!_isCreator) return;
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.approveLiveGuestRequest(liveId, request.userId);
      if (request.identity != null && request.identity!.isNotEmpty) {
        await _sendControlMessage(
          {'v': 1, 't': 'join-approved'},
          destinationIdentities: [request.identity!],
        );
      }
      if (!mounted) return;
      setState(() {
        _guestRequests = _guestRequests
            .where((entry) => entry.userId != request.userId)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('${translate('live_guest_approve_error')}: $e')),
      );
    }
  }

  Future<void> _rejectGuestRequest(_LiveGuestRequest request) async {
    final translate = LanguageService.instance.translate;
    if (!_isCreator) return;
    final liveId = _streamingLiveId;
    if (liveId == null) return;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.rejectLiveGuestRequest(liveId, request.userId);
      if (request.identity != null && request.identity!.isNotEmpty) {
        await _sendControlMessage(
          {'v': 1, 't': 'join-rejected'},
          destinationIdentities: [request.identity!],
        );
      }
      if (!mounted) return;
      setState(() {
        _guestRequests = _guestRequests
            .where((entry) => entry.userId != request.userId)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text('${translate('live_guest_reject_error')}: $e')),
      );
    }
  }

  Future<void> _promoteViewerToSpeaker() async {
    final translate = LanguageService.instance.translate;
    if (_isPromotingToSpeaker) return;
    final granted = await _requestBroadcastPermissions();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(translate('live_guest_promotion_requires_media')),
        ),
      );
      return;
    }
    if (mounted) {
      setState(() => _isPromotingToSpeaker = true);
    }
    try {
      await _joinLive(canPublishOverride: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_guest_promoted'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isPromotingToSpeaker = false);
      }
    }
  }

  List<_LiveViewer> _currentViewers() {
    final room = _room;
    if (room == null) return const <_LiveViewer>[];
    return room.remoteParticipants.values
        .map((participant) {
          final identity = participant.identity;
          final name = participant.name.trim().isNotEmpty
              ? participant.name.trim()
              : identity;
          return _LiveViewer(
            identity: identity,
            userId: _parseUserIdFromIdentity(identity),
            name: name,
          );
        })
        .where((viewer) => viewer.identity.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _assignModerator(_LiveViewer viewer) async {
    final translate = LanguageService.instance.translate;
    if (!_isCreator) return;
    final liveId = _streamingLiveId;
    if (liveId == null || viewer.userId == null || viewer.userId! <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_user_not_found'))),
      );
      return;
    }
    try {
      _api ??= await ApiService.getInstance();
      await _api!.assignLiveModerator(liveId, viewer.userId!);
      await _sendControlMessage({
        'v': 1,
        't': 'moderator-assigned',
        'targetIdentity': viewer.identity,
        'targetUserId': viewer.userId,
      });
      if (!mounted) return;
      setState(() {
        _sessionModeratorIdentities.add(viewer.identity);
        _sessionModeratorUserIds.add(viewer.userId!);
        _livekitChatMessages = _livekitChatMessages
            .map(
              (entry) => entry.authorIdentity == viewer.identity ||
                      entry.authorUserId == viewer.userId
                  ? entry.copyWith(isModerator: true)
                  : entry,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(
              'live_moderator_assigned_other',
            ).replaceFirst('{name}', viewer.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translate('live_assign_moderator_error')}: $e'),
        ),
      );
    }
  }

  Future<void> _blockViewerFromChat(_LiveViewer viewer) async {
    final translate = LanguageService.instance.translate;
    if (!_canModerateLive) return;
    final liveId = _streamingLiveId;
    if (liveId == null || viewer.userId == null || viewer.userId! <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_user_not_found'))),
      );
      return;
    }
    try {
      _api ??= await ApiService.getInstance();
      await _api!.blockLiveChatUser(liveId, viewer.userId!);
      await _sendControlMessage({
        'v': 1,
        't': 'chat-blocked',
        'targetIdentity': viewer.identity,
        'targetUserId': viewer.userId,
        'targetName': viewer.name,
      });
      if (!mounted) return;
      setState(() {
        _blockedParticipantIdentities.add(viewer.identity);
        _blockedParticipantUserIds.add(viewer.userId!);
        _blockedParticipantNames.add(viewer.name.trim().toLowerCase());
        _guestRequests = _guestRequests
            .where(
              (request) =>
                  request.identity != viewer.identity &&
                  request.userId != viewer.userId,
            )
            .toList();
        _livekitChatMessages = _livekitChatMessages
            .where((entry) => !_isChatEntryBlocked(entry))
            .toList();
        _chatDedupKeys
          ..clear()
          ..addAll(_livekitChatMessages.map((entry) => entry.dedupeKey));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            translate(
              'live_chat_blocked_other',
            ).replaceFirst('{name}', viewer.name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${translate('live_block_user_error')}: $e')),
      );
    }
  }

  Future<void> _deleteChatMessage(_LiveKitChatEntry entry) async {
    final translate = LanguageService.instance.translate;
    if (!_canModerateLive) return;
    try {
      final liveId = _streamingLiveId;
      if (liveId != null && entry.commentId != null && entry.commentId! > 0) {
        _api ??= await ApiService.getInstance();
        await _api!.deleteLiveComment(liveId, entry.commentId!);
      }
      await _sendControlMessage({
        'v': 1,
        't': 'chat-message-deleted',
        if (entry.commentId != null) 'commentId': entry.commentId,
        'dedupeKey': entry.dedupeKey,
      });
      if (!mounted) return;
      setState(() {
        _deletedChatKeys.add(entry.dedupeKey);
        _livekitChatMessages = _livekitChatMessages
            .where((message) => message.dedupeKey != entry.dedupeKey)
            .toList();
        _chatDedupKeys.remove(entry.dedupeKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate('live_delete_message_success'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translate('live_delete_message_error')}: $e'),
        ),
      );
    }
  }

  Future<void> _reportCurrentLive() async {
    final translate = LanguageService.instance.translate;
    final liveId = _streamingLiveId;
    if (_isCreator || liveId == null || _isReportingLive) return;
    const reasons = <String>[
      'inappropriate',
      'harassment',
      'violence',
      'spam',
    ];
    var selectedReason = reasons.first;
    final descriptionController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF131313),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate('live_report_live_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    dropdownColor: const Color(0xFF1D1D1D),
                    decoration: InputDecoration(
                      labelText: translate('live_report_reason_label'),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: reasons
                        .map(
                          (reason) => DropdownMenuItem<String>(
                            value: reason,
                            child: Text(
                              translate('live_report_reason_$reason'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedReason = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: translate('live_report_details_label'),
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFBE1E1E),
                      ),
                      child: Text(translate('live_report_submit')),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      descriptionController.dispose();
      return;
    }

    setState(() => _isReportingLive = true);
    try {
      _api ??= await ApiService.getInstance();
      final result = await _api!.reportLive(
        liveId,
        reason: selectedReason,
        description: descriptionController.text.trim(),
      );
      _applyConsensusStateFromPayload(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (result['is_suspended'] == true || result['is_suspended'] == 1)
                ? translate('live_report_threshold_reached')
                : translate('live_report_success'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${translate('live_report_error')}: $e')),
      );
    } finally {
      descriptionController.dispose();
      if (mounted) {
        setState(() => _isReportingLive = false);
      }
    }
  }

  Future<void> _openModerationSheet() async {
    if (!_canModerateLive) return;
    final translate = LanguageService.instance.translate;
    final viewers = _currentViewers();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131313),
      showDragHandle: true,
      builder: (sheetContext) {
        if (viewers.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Text(
              translate('live_moderation_empty_viewers'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: viewers.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (context, index) {
              final viewer = viewers[index];
              final isModerator =
                  _sessionModeratorIdentities.contains(viewer.identity) ||
                  (viewer.userId != null &&
                      _sessionModeratorUserIds.contains(viewer.userId));
              final isBlocked =
                  _blockedParticipantIdentities.contains(viewer.identity) ||
                  (viewer.userId != null &&
                      _blockedParticipantUserIds.contains(viewer.userId));
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  viewer.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  isModerator
                      ? translate('live_viewer_role_moderator')
                      : isBlocked
                      ? translate('live_viewer_role_chat_blocked')
                      : translate('live_viewer_role_viewer'),
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (_isCreator && !isModerator)
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _assignModerator(viewer);
                        },
                        child: Text(translate('live_action_assign_moderator')),
                      ),
                    if (!isBlocked)
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _blockViewerFromChat(viewer);
                        },
                        child: Text(translate('live_action_block_chat')),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openChatMessageActions(_LiveKitChatEntry entry) async {
    if (!_canModerateLive) return;
    if (!mounted) return;
    final translate = LanguageService.instance.translate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF131313),
      showDragHandle: true,
      builder: (sheetContext) {
        final authorIdentity = entry.authorIdentity;
        final authorUserId = entry.authorUserId;
        final canBlockAuthor =
            (authorIdentity != null || authorUserId != null) &&
            (authorIdentity == null ||
                !_blockedParticipantIdentities.contains(authorIdentity)) &&
            (authorUserId == null ||
                !_blockedParticipantUserIds.contains(authorUserId));
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: Text(
                  translate('live_action_delete_message'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _deleteChatMessage(entry);
                },
              ),
              if (canBlockAuthor)
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: Text(
                    translate(
                      'live_action_block_author_from_chat',
                    ).replaceFirst('{name}', entry.author),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _blockViewerFromChat(
                      _LiveViewer(
                        identity: authorIdentity ?? '',
                        userId: authorUserId,
                        name: entry.author,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCommunityVoteSheet() async {
    final theme = Theme.of(context);
    final translate = LanguageService.instance.translate;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131313),
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  translate('live_community_vote_title'),
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  translate('live_community_vote_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                title: Text(
                  translate('live_community_vote_action'),
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  translate('live_community_vote_reason'),
                  style: const TextStyle(color: Colors.white60),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    final api = await ApiService.getInstance();
                    if (_streamingLiveId != null) {
                      final result = await api.reportLive(
                        _streamingLiveId!,
                        reason: 'Community Vote',
                      );
                      _applyConsensusStateFromPayload(result);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              (result['is_suspended'] == true ||
                                      result['is_suspended'] == 1)
                                  ? translate(
                                      'live_community_vote_threshold_reached',
                                    )
                                  : translate('live_community_vote_success'),
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${translate('live_community_vote_error')}: $e',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConfigHints() {
    final translate = LanguageService.instance.translate;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final credentialsMode = LiveKitConfig.hasTokenEndpoint
        ? translate('live_config_mode_endpoint')
        : LiveKitConfig.canGenerateTokenOnDevice
        ? translate('live_config_mode_dev')
        : translate('live_config_mode_none');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isMilitantTechnician) ...[
            Text(
              translate('live_config_tech_title'),
              style: TextStyle(
                color: theme.textTheme.titleSmall?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translate('live_config_tech_desc'),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _livekitUrlController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: _fieldDecoration(
                translate('live_config_url_label'),
                'wss://...',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _livekitTokenEndpointController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: _fieldDecoration(
                translate('live_config_token_label'),
                '.../v1/lives.php?path=token',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 14),
          ] else ...[
            Text(
              'LiveKit',
              style: TextStyle(
                color: theme.textTheme.titleSmall?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translate('live_config_auto_desc'),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            translate(
              'live_config_mode_label',
            ).replaceFirst('{mode}', credentialsMode),
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LiveKitConfig.hasTokenEndpoint
                ? (_isMilitantTechnician
                      ? translate('live_config_token_desc_sur')
                      : translate('live_config_token_desc_fixed'))
                : translate('live_config_token_desc_none'),
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              height: 1.35,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LiveKitConfig.hasServerUrl
                ? translate(
                    'live_config_url_compile',
                  ).replaceFirst('{url}', LiveKitConfig.serverUrl)
                : (_isMilitantTechnician
                      ? translate('live_config_url_none_tech')
                      : translate('live_config_url_none_user')),
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRoom(BuildContext context) {
    final translate = LanguageService.instance.translate;
    final tracks = _participantTracks();
    final viewerCount = _viewerCount();
    final displayName = _displayNameController.text.trim();
    final displayedTitle = _currentLiveTitle ?? _roomController.text.trim();
    final isChatBlocked = _isLocalBlockedFromChat;

    return Stack(
      key: const ValueKey('live-room'),
      fit: StackFit.expand,
      children: [
        if (tracks.length > 1)
          _buildMultiVideoGrid(tracks)
        else if (tracks.length == 1)
          VideoTrackRenderer(tracks.first, fit: VideoViewFit.cover)
        else
          _buildLiveBackdrop(displayName),
        Positioned(
          top: 18,
          left: 16,
          right: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE1E1E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'LIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayedTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@$displayName · $viewerCount personnes',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _disconnectRoom,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (_canModerateLive)
          Positioned(
            top: 86,
            left: 16,
            child: IconButton.filledTonal(
              onPressed: _openModerationSheet,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.shield_outlined),
            ),
          ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 180,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withValues(alpha: 0.35),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        itemCount: _livekitChatMessages.length,
                        itemBuilder: (context, i) {
                          final c = _livekitChatMessages[i];
                          final authorLabel = c.isModerator
                              ? '${c.author} [MODO] '
                              : '${c.author} ';
                          return GestureDetector(
                            onLongPress: _canModerateLive
                                ? () => _openChatMessageActions(c)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.25,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: authorLabel,
                                      style: TextStyle(
                                        color: c.isModerator
                                            ? Colors.amber.shade200
                                            : Colors.red.shade200,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: c.text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      enabled: !isChatBlocked,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isChatBlocked
                            ? translate('live_chat_blocked_hint')
                            : translate('live_chat_hint'),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black54,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendLivekitChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFBE1E1E),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (_isSendingChat || isChatBlocked)
                        ? null
                        : _sendLivekitChatMessage,
                    icon: _isSendingChat
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
              if (!_isCreator && !_canControlBroadcast) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: (_hasPendingJoinRequest || _isPromotingToSpeaker)
                        ? null
                        : _requestToJoinBroadcast,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(
                      _hasPendingJoinRequest
                          ? translate('live_join_request_pending')
                          : _isPromotingToSpeaker
                          ? translate('live_join_request_connecting')
                          : translate('live_join_request_cta'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Removed TikTok-style action bubbles per request
        Positioned(
          top: 86,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isCreator)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconButton.filledTonal(
                    onPressed: _isReportingLive ? null : _reportCurrentLive,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isReportingLive
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.flag_outlined),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _openCommunityVoteSheet,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.how_to_vote),
                    ),
                    if (_reportCount > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "$_reportCount/5",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              if (_canControlBroadcast) ...[
                const SizedBox(height: 12),
                _buildMicroSideButton(),
                const SizedBox(height: 8),
                _buildCamSideButton(),
                const SizedBox(height: 8),
                _buildBackdropSideButton(),
              ],
            ],
          ),
        ),
        if (_isCreator && _guestRequests.isNotEmpty)
          Positioned(
            top: 146,
            right: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('live_guest_requests_title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final request in _guestRequests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  request.name,
                                  style: const TextStyle(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _approveGuestRequest(request),
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _rejectGuestRequest(request),
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
      ),
      hintStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFBE1E1E), width: 1.5),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.03),
    );
  }

  Widget _buildMicroSideButton() {
    return IconButton.filled(
      onPressed: _toggleMicrophone,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(12),
      ),
      icon: Icon(_microphoneEnabled ? Icons.mic : Icons.mic_off),
    );
  }

  Widget _buildCamSideButton() {
    return IconButton.filled(
      onPressed: _toggleCamera,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(12),
      ),
      icon: Icon(_cameraEnabled ? Icons.videocam : Icons.videocam_off),
    );
  }

  Widget _buildBackdropSideButton() {
    final hasBackdrop =
        _liveBackgroundImageUrl != null || _liveBackgroundImageFile != null;
    return IconButton.filled(
      onPressed: _isUpdatingLiveBackground ? null : _openLiveBackgroundSheet,
      style: IconButton.styleFrom(
        backgroundColor: hasBackdrop ? const Color(0xFFBE1E1E) : Colors.black45,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(12),
      ),
      icon: _isUpdatingLiveBackground
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.photo_library_outlined),
    );
  }
}

class _LiveKitChatEntry {
  _LiveKitChatEntry({
    required this.author,
    required this.text,
    required this.dedupeKey,
    required this.authorIdentity,
    this.authorUserId,
    this.commentId,
    this.isModerator = false,
  });

  final String author;
  final String text;
  final String dedupeKey;
  final String? authorIdentity;
  final int? authorUserId;
  final int? commentId;
  final bool isModerator;

  _LiveKitChatEntry copyWith({
    String? author,
    String? text,
    String? dedupeKey,
    Object? authorIdentity = _sentinel,
    Object? authorUserId = _sentinel,
    Object? commentId = _sentinel,
    bool? isModerator,
  }) {
    return _LiveKitChatEntry(
      author: author ?? this.author,
      text: text ?? this.text,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      authorIdentity: identical(authorIdentity, _sentinel)
          ? this.authorIdentity
          : authorIdentity as String?,
      authorUserId: identical(authorUserId, _sentinel)
          ? this.authorUserId
          : authorUserId as int?,
      commentId: identical(commentId, _sentinel)
          ? this.commentId
          : commentId as int?,
      isModerator: isModerator ?? this.isModerator,
    );
  }
}

class _LiveGuestRequest {
  const _LiveGuestRequest({
    this.identity,
    required this.userId,
    required this.name,
  });

  final String? identity;
  final int userId;
  final String name;
}

class _LiveViewer {
  const _LiveViewer({
    required this.identity,
    required this.name,
    this.userId,
  });

  final String identity;
  final String name;
  final int? userId;
}

const Object _sentinel = Object();

  Widget _buildMultiVideoGrid(List<VideoTrack> tracks) {
    if (tracks.length == 2) {
      return Column(
        children: [
          Expanded(child: VideoTrackRenderer(tracks[0], fit: VideoViewFit.cover)),
          Expanded(child: VideoTrackRenderer(tracks[1], fit: VideoViewFit.cover)),
        ],
      );
    }
    
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: tracks.length <= 4 ? 2 : 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        return VideoTrackRenderer(tracks[index], fit: VideoViewFit.cover);
      },
    );
  }
