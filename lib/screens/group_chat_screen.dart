import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../config/feature_flags.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'group_call_screen.dart';
import 'group_settings_screen.dart';
import '../widgets/linkable_text.dart';
import '../widgets/incoming_call_banner.dart';
import '../widgets/signal_typing_indicator.dart';

const String _groupCallMessagePrefix = '__militant_group_call__:';
const Duration _groupChatPollInterval = Duration(seconds: 10);
const Duration _groupTypingPollInterval = Duration(seconds: 6);
const List<String> _groupMessageReactionChoices = [
  'like',
  'love',
  'haha',
  'wow',
  'sad',
  'angry',
];

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? groupAvatar;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupAvatar,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isRefreshing = false;
  bool _isTypingSent = false;
  ApiService? _api;
  Map<String, dynamic>? _groupDetails;
  Timer? _pollTimer;
  Timer? _typingPollTimer;
  Timer? _typingIdleTimer;
  DateTime? _lastTypingHeartbeatAt;
  List<Map<String, dynamic>> _typingUsers = [];
  Map<String, String>? _activeGroupCall;
  Map<String, dynamic>? _replyingTo;
  final Set<int> _expiredGroupCallMessageIds = <int>{};
  final Set<int> _deletingExpiredGroupCallMessageIds = <int>{};

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
    _loadMessages(showLoader: true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_groupChatPollInterval, (_) {
      _loadMessages();
    });

    _typingPollTimer?.cancel();
    _typingPollTimer = Timer.periodic(_groupTypingPollInterval, (_) {
      _refreshTypingUsers();
    });
  }

  void _handleMessageChanged() {
    if (mounted) {
      setState(() {});
    }
    _syncTypingState();
  }

  Future<void> _loadMessages({bool showLoader = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (showLoader && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      _api ??= await ApiService.getInstance();
      final messages = await _api!.getGroupMessages(widget.groupId);
      final typingUsers = await _api!.getGroupTypingUsers(widget.groupId);
      final groupDetails = _groupDetails == null || showLoader
          ? await _api!.getGroupDetails(widget.groupId)
          : _groupDetails;
      final activeGroupCall = await _resolveActiveGroupCall(messages);
      final visibleMessages = messages.where((message) {
        if (message is! Map) return true;
        final messageId = _messageId(message);
        return messageId == null ||
            !_expiredGroupCallMessageIds.contains(messageId);
      }).toList();
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(visibleMessages.reversed);
        _typingUsers = typingUsers;
        _groupDetails = groupDetails;
        _activeGroupCall = activeGroupCall;
      });
    } catch (e) {
      if (mounted && showLoader) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error')}: ${e.toString()}'),
          ),
        );
      }
    } finally {
      _isRefreshing = false;
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final lang = LanguageService.instance;
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    // Optimistic UI: Add message locally
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = {
      'id': tempId,
      'sender_id': 0, // Will be replaced by server data
      'content': content,
      'is_mine': true,
      'username': lang.translate('me_label'), // Placeholder
      'created_at': DateTime.now().toIso8601String(),
      if (_replyingTo != null) 'parent_id': _replyingTo!['id'],
      if (_replyingTo != null)
        'parent_username':
            _replyingTo!['username'] ?? lang.translate('me_label'),
      if (_replyingTo != null) 'parent_content': _replyingTo!['content'] ?? '',
    };

    setState(() {
      _isSending = true;
      _messages.insert(0, tempMessage);
    });
    _messageController.clear();
    unawaited(_setTyping(false, force: true));

    try {
      final api = await ApiService.getInstance();
      await api.sendGroupMessage(
        widget.groupId,
        content,
        parentId: _replyingTo?['id'] is int
            ? _replyingTo!['id'] as int
            : int.tryParse('${_replyingTo?['id'] ?? ''}'),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      await _loadMessages(); // Refresh
    } catch (e) {
      setState(() {
        _messages.removeAt(0); // Remove local message
      });
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error')}: ${e.toString()}'),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _syncTypingState() {
    final hasText = _messageController.text.trim().isNotEmpty;

    if (!hasText) {
      _typingIdleTimer?.cancel();
      unawaited(_setTyping(false, force: true));
      return;
    }

    final lastHeartbeat = _lastTypingHeartbeatAt;
    if (!_isTypingSent ||
        lastHeartbeat == null ||
        DateTime.now().difference(lastHeartbeat) >=
            const Duration(seconds: 4)) {
      unawaited(_setTyping(true));
    }

    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_setTyping(false, force: true));
    });
  }

  Future<void> _setTyping(bool isTyping, {bool force = false}) async {
    if (!force && _isTypingSent == isTyping) {
      return;
    }

    try {
      _api ??= await ApiService.getInstance();
      await _api!.setGroupTyping(widget.groupId, isTyping);
      _isTypingSent = isTyping;
      _lastTypingHeartbeatAt = isTyping ? DateTime.now() : null;
    } catch (_) {
      // Non bloquant: le typing ne doit pas casser le chat.
    }
  }

  Future<void> _refreshTypingUsers() async {
    if (_isRefreshing || !mounted) return;

    try {
      _api ??= await ApiService.getInstance();
      final typingUsers = await _api!.getGroupTypingUsers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _typingUsers = typingUsers;
      });
    } catch (_) {
      // Non bloquant: le typing ne doit pas casser le chat.
    }
  }

  String? _buildTypingText() {
    if (_typingUsers.isEmpty) return null;
    final lang = LanguageService.instance;

    final names = _typingUsers
        .map((user) => (user['username'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return lang.translate('typing_people');
    }

    if (names.length == 1) {
      return lang
          .translate('typing_single')
          .replaceAll('{username}', names.first);
    }

    if (names.length == 2) {
      return lang
          .translate('typing_dual')
          .replaceAll('{username1}', names[0])
          .replaceAll('{username2}', names[1]);
    }

    return lang
        .translate('typing_multiple')
        .replaceAll('{username1}', names[0])
        .replaceAll('{username2}', names[1])
        .replaceAll('{count}', '${names.length - 2}');
  }

  Widget _buildTypingIndicator() {
    final text = _buildTypingText();
    if (text == null) {
      return const SizedBox.shrink();
    }
    return SignalTypingIndicator(text: text);
  }

  Future<Map<String, String>?> _resolveActiveGroupCall(
    List<dynamic> messages,
  ) async {
    for (final rawMessage in messages) {
      if (rawMessage is! Map) continue;
      final message = Map<String, dynamic>.from(rawMessage);
      final parsed = _parseGroupCallMessage(
        (message['content'] ?? '').toString(),
      );
      if (parsed == null) continue;

      final callId = parsed['call_id']?.trim() ?? '';
      if (callId.isEmpty) continue;

      try {
        _api ??= await ApiService.getInstance();
        final callInfo = await _api!.getCallInfo(callId);
        final status = callInfo['status']?.toString().trim() ?? '';
        if (_isFinishedCallStatus(status)) {
          unawaited(_autoDeleteEndedGroupCallMessage(message));
          continue;
        }
        return parsed;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  bool _isFinishedCallStatus(String status) {
    return {
      'ended',
      'rejected',
      'missed',
      'finished',
      'completed',
      'cancelled',
      'canceled',
      'failed',
    }.contains(status.toLowerCase());
  }

  int? _messageId(Map<dynamic, dynamic> message) {
    final value = message['id'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _autoDeleteEndedGroupCallMessage(
    Map<String, dynamic> message,
  ) async {
    final messageId = _messageId(message);
    if (messageId == null) return;

    _expiredGroupCallMessageIds.add(messageId);
    if (!_deletingExpiredGroupCallMessageIds.add(messageId)) return;

    try {
      _api ??= await ApiService.getInstance();
      await _api!.deleteGroupMessage(messageId);
    } catch (e) {
      debugPrint(
        '[GroupChat] unable to auto-delete ended group call message $messageId: $e',
      );
    } finally {
      _deletingExpiredGroupCallMessageIds.remove(messageId);
    }
  }

  Future<void> _openGroupCallScreen({
    String? callId,
    required bool isVideo,
    required bool isIncoming,
  }) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCallScreen(
          callId: callId,
          groupId: widget.groupId,
          groupName: widget.groupName,
          isVideo: isVideo,
          isIncoming: isIncoming,
        ),
      ),
    );

    if (!mounted) return;
    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _groupDetails?['name'] ?? widget.groupName,
                    maxLines: 1,
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_groupDetails?['auto_delete_time'] != null &&
                      _groupDetails!['auto_delete_time'] > 0)
                    Text(
                      lang
                          .translate('ephemeral_minutes')
                          .replaceAll(
                            '{minutes}',
                            _groupDetails!['auto_delete_time'].toString(),
                          ),
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (AppFeatureFlags.showGroupCallButtons &&
              _activeGroupCall == null) ...[
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                _openGroupCallScreen(isVideo: false, isIncoming: false);
              },
              tooltip: LanguageService.instance.translate('call_group_audio'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () {
                _openGroupCallScreen(isVideo: true, isIncoming: false);
              },
              tooltip: LanguageService.instance.translate('call_group_video'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupSettingsScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                  ),
                ),
              );
              if (result == true) {
                _loadMessages();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isLoading && _messages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBE1E1E),
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Text(
                          lang.translate('no_group_messages'),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageBubble(message);
                        },
                      ),
              ),
              _buildTypingIndicator(),
              _buildMessageInput(),
            ],
          ),
          // Évite le doublon avec la bannière d'appel de groupe active du chat.
          if (_activeGroupCall == null)
            IncomingCallBanner(groupId: widget.groupId),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = _api?.getImageUrl(widget.groupAvatar);
    if (url != null && url.endsWith('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SvgPicture.network(
          url,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholderBuilder: (_) =>
              const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (url != null) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url));
    } else {
      return ClipOval(
        child: SizedBox(
          width: 32,
          height: 32,
          child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.cover),
        ),
      );
    }
  }

  void _showOptions(dynamic message) {
    final lang = LanguageService.instance;
    final isMine = message['is_mine'] == true || message['is_mine'] == 1;
    // We can allow admins to delete other people's messages if needed,
    // but the backend only checks for role if it's an admin anyway.

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _groupMessageReactionChoices.map((reactionType) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await _toggleReaction(
                        Map<String, dynamic>.from(message as Map),
                        reactionType,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        _reactionEmoji(reactionType),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white),
              title: Text(
                lang.translate('reply'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingTo = Map<String, dynamic>.from(message as Map);
                });
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: Text(
                  lang.translate('edit'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFBE1E1E)),
              title: Text(
                lang.translate('delete'),
                style: const TextStyle(color: Color(0xFFBE1E1E)),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: Text(
                      lang.translate('delete_question'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      lang.translate('delete_message_confirm'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(lang.translate('cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          lang.translate('delete'),
                          style: const TextStyle(color: Color(0xFFBE1E1E)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await _api!.deleteGroupMessage(message['id']);
                    _loadMessages();
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(dynamic message) async {
    final lang = LanguageService.instance;
    final controller = TextEditingController(text: message['content']);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('edit_message'),
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(border: OutlineInputBorder()),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(
              lang.translate('save'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (newContent != null &&
        newContent.isNotEmpty &&
        newContent != message['content']) {
      try {
        await _api!.editGroupMessage(message['id'], newContent);
        _loadMessages();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _reactionEmoji(String reactionType) {
    switch (reactionType) {
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      case 'like':
      default:
        return '👍';
    }
  }

  String _messagePreviewText(dynamic rawContent) {
    final content = (rawContent ?? '').toString().trim();
    if (content.isNotEmpty) {
      return content;
    }
    return LanguageService.instance.translate('reply_preview_empty');
  }

  Map<String, int> _reactionCounts(dynamic rawValue) {
    if (rawValue is Map) {
      return rawValue.map(
        (key, value) =>
            MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
      )..removeWhere((key, value) => value <= 0);
    }
    if (rawValue is List) {
      final counts = <String, int>{};
      for (final item in rawValue) {
        if (item is Map) {
          final type =
              item['reaction_type']?.toString() ??
              item['type']?.toString() ??
              '';
          final count = int.tryParse('${item['count'] ?? 0}') ?? 0;
          if (type.isNotEmpty && count > 0) {
            counts[type] = count;
          }
        }
      }
      return counts;
    }
    return <String, int>{};
  }

  Future<void> _toggleReaction(
    Map<String, dynamic> message,
    String reactionType,
  ) async {
    final messageId = int.tryParse('${message['id'] ?? ''}');
    if (messageId == null) return;
    final targetMessage = _messages.cast<dynamic>().firstWhere(
      (item) => '${item['id'] ?? ''}' == '$messageId',
      orElse: () => message,
    );
    final currentReaction = (targetMessage['user_reaction'] ?? '').toString();
    final counts = Map<String, int>.from(
      _reactionCounts(targetMessage['reactions_summary']),
    );

    setState(() {
      if (currentReaction == reactionType) {
        targetMessage['user_reaction'] = '';
        final currentCount = counts[reactionType] ?? 0;
        if (currentCount > 1) {
          counts[reactionType] = currentCount - 1;
        } else {
          counts.remove(reactionType);
        }
      } else {
        if (currentReaction.isNotEmpty) {
          final previousCount = counts[currentReaction] ?? 0;
          if (previousCount > 1) {
            counts[currentReaction] = previousCount - 1;
          } else {
            counts.remove(currentReaction);
          }
        }
        targetMessage['user_reaction'] = reactionType;
        counts[reactionType] = (counts[reactionType] ?? 0) + 1;
      }
      targetMessage['reactions_summary'] = counts;
    });

    try {
      if (currentReaction == reactionType) {
        await _api!.removeGroupMessageReaction(messageId);
      } else {
        await _api!.reactToGroupMessage(messageId, reactionType);
      }
    } catch (_) {
      if (!mounted) return;
      await _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.instance.translate('reaction_failed')),
        ),
      );
    }
  }

  Widget _buildMessageBubble(dynamic message) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = message['content'] ?? '';
    final groupCallMessage = _parseGroupCallMessage(content.toString());
    final media = message['media'];
    final username = message['username'] ?? lang.translate('anonymous_user');
    final isMine = message['is_mine'] == true || message['is_mine'] == 1;
    final createdAt = message['created_at'] ?? '';
    final editedAt = message['edited_at'];
    final replyAuthor = (message['parent_username'] ?? '').toString();
    final replyContent = message['parent_content'];
    final reactionCounts = _reactionCounts(message['reactions_summary']);
    final userReaction = (message['user_reaction'] ?? '').toString();

    // État de traduction pour ce message
    final isTranslated = message['_isTranslated'] == true;
    final translatedText = message['_translatedText'];

    // Debug skipped

    final bubbleColor = isMine
        ? const Color(0xFFBE1E1E)
        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]);

    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : Colors.black);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(message),
        onSecondaryTap: () => _showOptions(message),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 2),
                child: Text(
                  username,
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message['parent_id'] != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: isMine ? 0.16 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: isMine
                                ? Colors.white70
                                : const Color(0xFFBE1E1E),
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyAuthor.isNotEmpty
                                ? replyAuthor
                                : lang.translate('anonymous_user'),
                            style: TextStyle(
                              color: textColor.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _messagePreviewText(replyContent),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor.withOpacity(0.72),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (media != null && media.toString().isNotEmpty)
                    _buildMedia(media, isMine),
                  if (groupCallMessage != null)
                    _buildGroupCallMessageCard(groupCallMessage)
                  else if (content.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinkableText(
                          text: isTranslated && translatedText != null
                              ? translatedText
                              : content,
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                        if (content.isNotEmpty)
                          Builder(
                            builder: (context) {
                              final urlPattern = RegExp(
                                r'https?://[^\s]+|www\.[^\s]+',
                                caseSensitive: false,
                              );
                              final matches = urlPattern.allMatches(content);
                              if (matches.isNotEmpty) {
                                return Column(
                                  children: matches
                                      .map(
                                        (match) => Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: LinkPreviewCard(
                                            url: match.group(0)!,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        // Afficher le bouton traduire pour tous les messages
                        GestureDetector(
                          onTap: () => _toggleTranslation(message),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 14,
                                  color: textColor.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isTranslated
                                      ? lang.translate('original_label')
                                      : lang.translate('translate_action'),
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (editedAt != null)
                        Text(
                          '${lang.translate('edited_label')} ',
                          style: TextStyle(
                            color: textColor.withOpacity(0.5),
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (reactionCounts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: reactionCounts.entries.map((entry) {
                          final isSelected = userReaction == entry.key;
                          return InkWell(
                            onTap: () => _toggleReaction(
                              Map<String, dynamic>.from(message as Map),
                              entry.key,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isMine
                                          ? Colors.white
                                          : const Color(0xFFFFE5E5))
                                    : (isMine
                                          ? Colors.white.withOpacity(0.16)
                                          : Colors.black.withOpacity(0.08)),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFBE1E1E)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                '${_reactionEmoji(entry.key)} ${entry.value}',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFBE1E1E)
                                      : textColor,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String>? _parseGroupCallMessage(String content) {
    if (!content.startsWith(_groupCallMessagePrefix)) return null;
    final rawPayload = content.substring(_groupCallMessagePrefix.length).trim();
    if (rawPayload.isEmpty) return null;

    final values = <String, String>{};
    for (final segment in rawPayload.split('&')) {
      if (segment.isEmpty) continue;
      final separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0) continue;
      final key = Uri.decodeQueryComponent(
        segment.substring(0, separatorIndex),
      );
      final value = Uri.decodeQueryComponent(
        segment.substring(separatorIndex + 1),
      );
      values[key] = value;
    }

    final callId = values['call_id']?.trim() ?? '';
    if (callId.isEmpty) return null;
    return values;
  }

  Widget _buildGroupCallMessageCard(Map<String, String> data) {
    final isVideo = (data['call_type'] ?? 'audio') == 'video';
    final label = isVideo ? 'Appel video de groupe' : 'Appel audio de groupe';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.call,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Touchez pour rejoindre depuis le groupe.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _joinGroupCallFromMessage(data),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Rejoindre'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFBE1E1E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroupCallFromMessage(Map<String, String> data) async {
    final callId = data['call_id']?.trim() ?? '';
    if (callId.isEmpty) return;

    try {
      _api ??= await ApiService.getInstance();
      final callInfo = await _api!.getCallInfo(callId);
      final status = callInfo['status']?.toString().trim() ?? '';
      if (status == 'ended' || status == 'rejected' || status == 'missed') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cet appel de groupe est termine.')),
        );
        return;
      }

      if (!mounted) return;
      await _openGroupCallScreen(
        callId: callId,
        isVideo: (data['call_type'] ?? 'audio') == 'video',
        isIncoming: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de rejoindre l appel: $e')),
      );
    }
  }

  Future<void> _toggleTranslation(dynamic message) async {
    final isTranslated = message['_isTranslated'] == true;

    if (isTranslated) {
      // Afficher l'original
      setState(() {
        message['_isTranslated'] = false;
      });
      return;
    }

    // Traduire
    if (message['_translatedText'] == null) {
      try {
        final api = await ApiService.getInstance();
        final result = await api.translateText(message['content'] ?? '');

        if (result['success'] == true) {
          setState(() {
            message['_translatedText'] = result['translated'];
            message['_isTranslated'] = true;
          });
        }
      } catch (e) {
        if (mounted) {
          final lang = LanguageService.instance;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${lang.translate('error_translation')}: $e'),
            ),
          );
        }
      }
    } else {
      setState(() {
        message['_isTranslated'] = true;
      });
    }
  }

  Widget _buildMedia(String mediaPath, bool isMine) {
    final lang = LanguageService.instance;
    print('DEBUG _buildMedia called with: $mediaPath');
    if (_api == null) {
      print('DEBUG _buildMedia: _api is null');
      return const SizedBox.shrink();
    }
    final url = _api!.getImageUrl(mediaPath);
    print('DEBUG _buildMedia: url=$url');
    if (url == null || url.isEmpty) {
      print('DEBUG _buildMedia: url is null or empty');
      return const SizedBox.shrink();
    }

    final lower = url.toLowerCase();
    final isVideo =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.contains('video');

    final isAudio =
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac');

    if (isAudio) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: AudioPlayerWidget(audioUrl: url, isMine: isMine),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isVideo
            ? SizedBox(height: 200, child: VideoPlayerWidget(videoUrl: url))
            : ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 100,
                  maxHeight: 300,
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Erreur chargement image: $url - $error');
                    return Container(
                      height: 100,
                      color: Colors.grey[800],
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.translate('loading_error'),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

    if (_isRecording) {
      return AudioRecorderWidget(
        onRecordingComplete: (audioFile) async {
          setState(() => _isRecording = false);
          await _uploadAndSend(audioFile.path);
        },
        onCancel: () {
          setState(() => _isRecording = false);
        },
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 6,
        bottom: 6 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBE1E1E),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang
                              .translate('replying_to_message')
                              .replaceAll(
                                '{username}',
                                (_replyingTo!['username'] ??
                                        lang.translate('anonymous_user'))
                                    .toString(),
                              ),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _messagePreviewText(_replyingTo!['content']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _replyingTo = null),
                    icon: Icon(Icons.close, color: theme.hintColor, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Color(0xFFBE1E1E)),
                onPressed: _pickMedia,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 42,
                    maxHeight: 120,
                  ),
                  decoration: BoxDecoration(
                    color:
                        theme.inputDecorationTheme.fillColor ??
                        theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    textAlignVertical: TextAlignVertical.center,
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? lang.translate('reply_to_message_hint')
                          : lang.translate('message_group_hint'),
                      hintStyle: TextStyle(color: theme.hintColor),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              if (_messageController.text.trim().isEmpty)
                IconButton(
                  icon: const Icon(Icons.mic, color: Color(0xFFBE1E1E)),
                  onPressed: () {
                    setState(() => _isRecording = true);
                  },
                )
              else
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFBE1E1E),
                          ),
                        )
                      : const Icon(Icons.send, color: Color(0xFFBE1E1E)),
                  onPressed: () => _isSending ? null : _sendMessage(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia() async {
    final lang = LanguageService.instance;
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(
                lang.translate('gallery'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(
                lang.translate('camera'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white),
              title: Text(
                lang.translate('audio'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.audio,
                );
                if (result != null && result.files.single.path != null) {
                  _uploadAndSend(result.files.single.path!);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.white),
              title: Text(
                lang.translate('link'),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final controller = TextEditingController();
                final url = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: Text(
                      lang.translate('share_link'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(lang.translate('cancel')),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: Text(lang.translate('share')),
                      ),
                    ],
                  ),
                );
                if (url != null && url.isNotEmpty) {
                  _messageController.text = url;
                  _sendMessage();
                }
              },
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickMedia();
      if (picked != null) {
        _uploadAndSend(picked.path);
      }
    }
  }

  Future<void> _uploadAndSend(String path) async {
    setState(() => _isSending = true);
    try {
      final mediaPath = await _api!.uploadFile(path, type: 'messages');
      print('DEBUG: Media uploaded to: $mediaPath');

      // Détecter le type de média
      final lower = path.toLowerCase();
      String mediaType = 'image';
      if (lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.ogg') ||
          lower.endsWith('.avi') ||
          lower.endsWith('.mkv')) {
        mediaType = 'video';
      } else if (lower.endsWith('.mp3') ||
          lower.endsWith('.wav') ||
          lower.endsWith('.ogg') ||
          lower.endsWith('.m4a')) {
        mediaType = 'audio';
      }

      print('DEBUG: Sending message with media: $mediaPath, type: $mediaType');
      await _api!.sendGroupMessage(
        widget.groupId,
        '',
        media: mediaPath,
        mediaType: mediaType,
        parentId: _replyingTo?['id'] is int
            ? _replyingTo!['id'] as int
            : int.tryParse('${_replyingTo?['id'] ?? ''}'),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      _loadMessages();
    } catch (e) {
      print('DEBUG: Error in _uploadAndSend: $e');
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('error_upload')}: ${e.toString()}'),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _typingPollTimer?.cancel();
    _typingIdleTimer?.cancel();
    unawaited(_setTyping(false, force: true));
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }
}
