import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/video_player_widget.dart';
import '../widgets/file_video_player.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/full_screen_image_page.dart';
import '../utils/date_formatter.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'call_screen.dart';
import '../widgets/linkable_text.dart';
import '../widgets/incoming_call_banner.dart';
import '../widgets/signal_typing_indicator.dart';
import '../utils/error_helper.dart';

const Duration _privateChatPollInterval = Duration(seconds: 10);
const Duration _privateTypingPollInterval = Duration(seconds: 6);
const List<String> _messageReactionChoices = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];

class ChatScreen extends StatefulWidget {
  final int userId;
  final String username;
  final String? avatar;

  const ChatScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<dynamic> _messages = [];
  String? _backgroundImagePath;
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  bool _isRefreshing = false;
  bool _isTypingSent = false;
  Map<String, dynamic>? _currentUser;
  ApiService? _api;
  StreamSubscription<IncomingCallData?>? _callEndSub;
  Timer? _pollTimer;
  Timer? _typingPollTimer;
  Timer? _typingIdleTimer;
  DateTime? _lastTypingHeartbeatAt;
  List<Map<String, dynamic>> _typingUsers = [];
  int _autoDeleteTime = 0;
  Map<String, dynamic>? _replyingTo;
  late String _contactUsername;
  String? _contactAvatar;

  @override
  void initState() {
    super.initState();
    _contactUsername = widget.username;
    _contactAvatar = widget.avatar;
    _messageController.addListener(_handleMessageChanged);
    _loadConversationDetails();
    _loadContactProfile();
    _loadMessages(showLoader: true);
    _startPolling();
    _loadPreferences();
    // Rafraîchir le chat quand un appel se termine (pour afficher le message système)
    _callEndSub = IncomingCallController.instance.stream.listen((event) {
      if (event == null && mounted) {
        // null = appel terminé/rejeté — recharger après 1s (laisse le temps au serveur)
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _loadMessages();
        });
      }
    });
  }

  Future<void> _loadContactProfile() async {
    try {
      _api ??= await ApiService.getInstance();
      final profile = await _api!.getProfile(userId: widget.userId);
      if (!mounted) return;
      final serverUsername = (profile['username'] ?? '').toString().trim();
      final serverAvatar = profile['avatar']?.toString().trim();

      setState(() {
        if (serverUsername.isNotEmpty &&
            (_contactUsername.isEmpty ||
             _contactUsername.startsWith('Utilisateur #') ||
             _contactUsername == 'TestUserColdStart' ||
             _contactUsername != serverUsername)) {
          _contactUsername = serverUsername;
        }
        if (serverAvatar != null && serverAvatar.isNotEmpty) {
          _contactAvatar = serverAvatar;
        }
      });
    } catch (_) {
      // Non bloquant: conservation des valeurs initiales si profil inaccessible
    }
  }

  Future<void> _loadConversationDetails() async {
    try {
      _api ??= await ApiService.getInstance();
      final details = await _api!.getPrivateConversationDetails(widget.userId);
      if (!mounted) return;
      final serverUsername = (details['username'] ?? '').toString().trim();
      final serverAvatar = details['avatar']?.toString().trim();

      setState(() {
        _autoDeleteTime =
            int.tryParse('${details['auto_delete_time'] ?? 0}') ?? 0;
        if (serverUsername.isNotEmpty &&
            (_contactUsername.isEmpty ||
             _contactUsername.startsWith('Utilisateur #') ||
             _contactUsername == 'TestUserColdStart' ||
             _contactUsername != serverUsername)) {
          _contactUsername = serverUsername;
        }
        if (serverAvatar != null && serverAvatar.isNotEmpty) {
          _contactAvatar = serverAvatar;
        }
      });
    } catch (_) {
      // Non bloquant: l'option reste masquée si l'API ne répond pas.
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final path = prefs.getString('chat_${widget.userId}_background');
        _backgroundImagePath = (path == 'none') ? null : path;
      });
    }
  }

  Future<void> _removeWallpaper() async {
    setState(() => _isSending = true);
    try {
      _api ??= await ApiService.getInstance();
      
      // Send a hidden message with 'none' to reset the wallpaper for both peers
      await _api!.sendMessage(
        widget.userId,
        '__militant_wallpaper__:none',
      );
      
      // Update local settings
      setState(() {
        _backgroundImagePath = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_${widget.userId}_background');
      
      _loadMessages();
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, lang)),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showWallpaperBottomSheet() {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasWallpaper = _backgroundImagePath != null &&
                _backgroundImagePath!.isNotEmpty &&
                _backgroundImagePath != 'none';
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    lang.translate('wallpaper_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Preview box
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF121212)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      image: hasWallpaper
                          ? DecorationImage(
                              image: (_backgroundImagePath!.startsWith('/') ||
                                      _backgroundImagePath!.startsWith('file://'))
                                  ? FileImage(File(_backgroundImagePath!))
                                  : NetworkImage(_api?.getImageUrl(_backgroundImagePath!) ?? '')
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasWallpaper
                        ? Center(
                            child: Text(
                              lang.translate('wallpaper_none'),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  
                  // Select button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE1E1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: Text(lang.translate('wallpaper_choose')),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _pickAndSendWallpaper();
                    },
                  ),
                  
                  if (hasWallpaper) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFBE1E1E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.delete),
                      label: Text(lang.translate('wallpaper_remove')),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _removeWallpaper();
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndSendWallpaper() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isSending = true);
      try {
        _api ??= await ApiService.getInstance();
        final remotePath = await _api!.uploadFile(picked.path, type: 'messages');
        
        // Send a hidden message with the wallpaper path
        await _api!.sendMessage(
          widget.userId,
          '__militant_wallpaper__:$remotePath',
        );
        
        // Update local setting
        setState(() {
          _backgroundImagePath = remotePath;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_${widget.userId}_background', remotePath);
        
        _loadMessages();
      } catch (e) {
        if (mounted) {
          final lang = LanguageService.instance;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(getFriendlyErrorMessage(e, lang)),
            ),
          );
        }
      } finally {
        setState(() => _isSending = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_privateChatPollInterval, (_) {
      _loadMessages();
    });

    _typingPollTimer?.cancel();
    _typingPollTimer = Timer.periodic(_privateTypingPollInterval, (_) {
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
      _currentUser ??= await _api!.getProfile();
      final messages = await _api!.getMessages(userId: widget.userId);
      final typingUsers = await _api!.getPrivateTypingUsers(widget.userId);

      // Scan for wallpaper sync message
      String? remoteWallpaperPath;
      for (final msg in messages) {
        final content = (msg['content'] ?? '').toString();
        if (content.startsWith('__militant_wallpaper__:')) {
          remoteWallpaperPath = content.substring('__militant_wallpaper__:'.length);
          break; // Since list is newest first, the first one found is the latest
        }
      }

      if (remoteWallpaperPath != null && remoteWallpaperPath != _backgroundImagePath) {
        _backgroundImagePath = remoteWallpaperPath;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('chat_${widget.userId}_background', remoteWallpaperPath);
      }

      // Filter out wallpaper sync messages from the rendered messages list
      final filteredMessages = messages.where((msg) {
        final content = (msg['content'] ?? '').toString();
        return !content.startsWith('__militant_wallpaper__:');
      }).toList();

      // Extraire nom et avatar de l'interlocuteur depuis les messages reçus si non résolus
      String? foundUsername;
      String? foundAvatar;
      for (final msg in messages) {
        final senderId = int.tryParse(msg['sender_id']?.toString() ?? '');
        if (senderId == widget.userId) {
          final u = msg['sender_username']?.toString().trim();
          final a = msg['sender_avatar']?.toString().trim();
          if (u != null && u.isNotEmpty) foundUsername ??= u;
          if (a != null && a.isNotEmpty) foundAvatar ??= a;
          if (foundUsername != null && foundAvatar != null) break;
        }
      }

      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(
          filteredMessages,
        ); // API returns newest first, correct for ListView(reverse:true)
        _typingUsers = typingUsers;
        if (foundUsername != null &&
            (_contactUsername.isEmpty ||
             _contactUsername.startsWith('Utilisateur #') ||
             _contactUsername == 'TestUserColdStart')) {
          _contactUsername = foundUsername;
        }
        if (foundAvatar != null && (_contactAvatar == null || _contactAvatar!.isEmpty)) {
          _contactAvatar = foundAvatar;
        }
      });
    } catch (e) {
      if (mounted && showLoader) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, lang)),
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
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    // Optimistic UI: Add message locally
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = {
      'id': tempId,
      'sender_id': _currentUser?['id'],
      'receiver_id': widget.userId,
      'content': content,
      'is_mine': true,
      'created_at': DateTime.now().toIso8601String(),
      if (_replyingTo != null) 'parent_id': _replyingTo!['id'],
      if (_replyingTo != null)
        'parent_sender_username': _replyingTo!['sender_username'] ?? _contactUsername,
      if (_replyingTo != null) 'parent_content': _replyingTo!['content'] ?? '',
    };

    setState(() {
      _isSending = true;
      _messages.insert(
        0,
        tempMessage,
      ); // Add at the beginning (bottom of the UI)
    });
    _messageController.clear();
    unawaited(_setTyping(false, force: true));

    try {
      final api = await ApiService.getInstance();
      await api.sendMessage(
        widget.userId,
        content,
        parentId: _replyingTo?['id'] is int
            ? _replyingTo!['id'] as int
            : int.tryParse('${_replyingTo?['id'] ?? ''}'),
      );
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      await _loadMessages(); // Refresh to get official data and server timestamps
    } catch (e) {
      setState(() {
        _messages.removeAt(0); // Remove optimistic message on error
      });
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, lang)),
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
      await _api!.setPrivateTyping(widget.userId, isTyping);
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
      final typingUsers = await _api!.getPrivateTypingUsers(widget.userId);
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
    final username = (_typingUsers.first['username'] ?? _contactUsername)
        .toString()
        .trim();
    if (username.isEmpty) {
      return lang.translate('typing_someone');
    }
    return lang.translate('typing_single').replaceAll('{username}', username);
  }

  Widget _buildTypingIndicator() {
    final text = _buildTypingText();
    if (text == null) {
      return const SizedBox.shrink();
    }
    return SignalTypingIndicator(text: text);
  }

  String _autoDeleteSubtitle() {
    final lang = LanguageService.instance;
    final disabled = lang.translate('disabled');
    final template = lang.translate('ephemeral_delete_after');

    if (_autoDeleteTime <= 0) {
      return disabled;
    }
    if (_autoDeleteTime == 1) {
      return template.replaceAll(
        '{duration}',
        lang.translate('duration_1_minute'),
      );
    }
    if (_autoDeleteTime == 5) {
      return template.replaceAll(
        '{duration}',
        lang.translate('duration_5_minutes'),
      );
    }
    if (_autoDeleteTime < 60) {
      return template.replaceAll('{duration}', '$_autoDeleteTime minutes');
    }
    if (_autoDeleteTime == 60) {
      return template.replaceAll('{duration}', lang.translate('duration_1_hour'));
    }
    if (_autoDeleteTime == 1440) {
      return template.replaceAll(
        '{duration}',
        lang.translate('duration_24_hours'),
      );
    }
    if (_autoDeleteTime == 10080) {
      return template.replaceAll('{duration}', lang.translate('duration_1_week'));
    }
    return template.replaceAll('{duration}', '$_autoDeleteTime min');
  }

  Future<void> _showConversationSettings() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(LanguageService.instance.translate('ephemeral_messages')),
        children: [
          _timeOption(0, LanguageService.instance.translate('disabled')),
          _timeOption(1, LanguageService.instance.translate('duration_1_minute')),
          _timeOption(
            5,
            LanguageService.instance.translate('duration_5_minutes'),
          ),
          _timeOption(60, LanguageService.instance.translate('duration_1_hour')),
          _timeOption(
            1440,
            LanguageService.instance.translate('duration_24_hours'),
          ),
          _timeOption(
            10080,
            LanguageService.instance.translate('duration_1_week'),
          ),
        ],
      ),
    );

    if (selected == null || selected == _autoDeleteTime) {
      return;
    }

    try {
      _api ??= await ApiService.getInstance();
      final result = await _api!.updatePrivateConversationSettings(
        widget.userId,
        autoDeleteTime: selected,
      );
      if (!mounted) return;
      setState(() {
        _autoDeleteTime = int.tryParse(
              '${result['conversation']?['auto_delete_time'] ?? selected}',
            ) ??
            selected;
      });
      await _loadMessages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_autoDeleteSubtitle())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
    }
  }

  Widget _timeOption(int value, String label) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context, value),
      child: Row(
        children: [
          Icon(
            _autoDeleteTime == value ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: const Color(0xFFBE1E1E),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildAutoDeleteBanner() {
    if (_autoDeleteTime <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFBE1E1E).withValues(alpha: 0.10),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: Color(0xFFBE1E1E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _autoDeleteSubtitle(),
              style: const TextStyle(
                color: Color(0xFFBE1E1E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
              child: Text(
                _contactUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textTheme.titleLarge?.color),
              ),
            ),
          ],
        ),
        actions: [
          // Bouton appel audio
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    recipientId: widget.userId,
                    recipientName: _contactUsername,
                    recipientAvatar: _api?.getImageUrl(_contactAvatar),
                    isVideo: false,
                    isIncoming: false,
                  ),
                ),
              ).then(
                (_) => _loadMessages(),
              ); // Rafraîchir le chat après l'appel
            },
            tooltip: LanguageService.instance.translate('call_audio'),
          ),

          // Bouton appel vidéo
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    recipientId: widget.userId,
                    recipientName: _contactUsername,
                    recipientAvatar: _api?.getImageUrl(_contactAvatar),
                    isVideo: true,
                    isIncoming: false,
                  ),
                ),
              ).then(
                (_) => _loadMessages(),
              ); // Rafraîchir le chat après l'appel
            },
            tooltip: LanguageService.instance.translate('call_video'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'ephemeral') {
                _showConversationSettings();
              } else if (value == 'wallpaper') {
                _showWallpaperBottomSheet();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'ephemeral',
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined),
                    const SizedBox(width: 12),
                    Text(LanguageService.instance.translate('ephemeral_messages')),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'wallpaper',
                child: Row(
                  children: [
                    const Icon(Icons.wallpaper),
                    const SizedBox(width: 12),
                    Text(LanguageService.instance.translate('wallpaper_label') ?? 'Fond d\'écran'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: _backgroundImagePath != null &&
                _backgroundImagePath!.isNotEmpty &&
                _backgroundImagePath != 'none'
            ? BoxDecoration(
                image: DecorationImage(
                  image: (_backgroundImagePath!.startsWith('/') ||
                          _backgroundImagePath!.startsWith('file://'))
                      ? FileImage(File(_backgroundImagePath!))
                      : NetworkImage(_api?.getImageUrl(_backgroundImagePath!) ?? '')
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: Stack(
          children: [
          Column(
            children: [
              _buildAutoDeleteBanner(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBE1E1E),
                        ),
                      )
                    : _messages.isEmpty
                    ? Center(
                        child: Text(
                          lang.translate('no_messages'),
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
          // Bannière d'appel entrant (affichée au-dessus du chat)
          IncomingCallBanner(peerId: widget.userId),
        ],
      ),
    ),
  );
  }

  Widget _buildAvatar() {
    return FutureBuilder<ApiService>(
      future: ApiService.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircleAvatar(radius: 16);
        final api = snapshot.data!;
        final url = api.getImageUrl(_contactAvatar);

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
          return CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFBE1E1E),
            child: Text(
              _contactUsername.isNotEmpty
                  ? _contactUsername[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          );
        }
      },
    );
  }

  void _showOptions(dynamic message) {
    final messageMap = Map<String, dynamic>.from(message as Map);
    bool isMine = message['is_mine'] == true || message['is_mine'] == 1;

    // Fallback if is_mine is missing (e.g. from local update or specific API response)
    if (!isMine && _currentUser != null && message['sender_id'] != null) {
      isMine =
          message['sender_id'].toString() == _currentUser!['id'].toString();
    }

    final lang = LanguageService.instance;

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
                children: _messageReactionChoices.map((reactionType) {
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await _toggleReaction(messageMap, reactionType);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                _prepareReply(messageMap);
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
            if (isMine)
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
                      final api = await ApiService.getInstance();
                      await api.deleteMessage(message['id']);
                      _loadMessages();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
                      }
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
        final api = await ApiService.getInstance();
        await api.editMessage(message['id'], newContent);
        _loadMessages();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  void _prepareReply(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = Map<String, dynamic>.from(message);
    });
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
        (key, value) => MapEntry(
          key.toString(),
          int.tryParse(value.toString()) ?? 0,
        ),
      )..removeWhere((key, value) => value <= 0);
    }
    if (rawValue is List) {
      final counts = <String, int>{};
      for (final item in rawValue) {
        if (item is Map) {
          final type = item['reaction_type']?.toString() ?? item['type']?.toString() ?? '';
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
      final api = await ApiService.getInstance();
      if (currentReaction == reactionType) {
        await api.removePrivateMessageReaction(messageId);
      } else {
        await api.reactToPrivateMessage(messageId, reactionType);
      }
    } catch (e) {
      if (!mounted) return;
      await _loadMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.instance.translate('reaction_failed'))),
      );
    }
  }

  Widget _buildMessageBubble(dynamic message) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = message['content'] ?? '';
    final media = message['media'];
    final isMine = message['is_mine'] == true || message['is_mine'] == 1;
    final createdAt = message['created_at'] ?? '';
    final editedAt = message['edited_at'];
    final replyAuthor = (message['parent_sender_username'] ?? message['parent_username'] ?? '').toString();
    final replyContent = message['parent_content'];
    final reactionCounts = _reactionCounts(message['reactions_summary']);
    final userReaction = (message['user_reaction'] ?? '').toString();

    // État de traduction pour ce message
    final isTranslated = message['_isTranslated'] == true;
    final translatedText = message['_translatedText'];

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
        child: Container(
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
                    color: Colors.black.withValues(alpha: isMine ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: isMine ? Colors.white70 : const Color(0xFFBE1E1E),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyAuthor.isNotEmpty ? replyAuthor : _contactUsername,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.85),
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
                          color: textColor.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              if (media != null && media.toString().isNotEmpty)
                _buildMedia(media, message['media_type']?.toString(), isMine),
              if (content.isNotEmpty)
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
                                      padding: const EdgeInsets.only(top: 8.0),
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
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isTranslated
                                  ? lang.translate('original_label')
                                  : lang.translate('translate_action'),
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
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
                        color: textColor.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      (message['is_read'] == 1 ||
                              message['is_read'] == '1' ||
                              message['is_read'] == true)
                          ? Icons.done_all
                          : Icons.done,
                      size: 14,
                      color: (message['is_read'] == 1 ||
                              message['is_read'] == '1' ||
                              message['is_read'] == true)
                          ? Colors.white
                          : textColor.withValues(alpha: 0.5),
                    ),
                  ],
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isMine
                                      ? Colors.white
                                      : const Color(0xFFFFE5E5))
                                : (isMine
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : Colors.black.withValues(alpha: 0.08)),
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
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      ),
    );
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

  Widget _buildMedia(String mediaPath, String? mediaType, bool isMine) {
    final lang = LanguageService.instance;
    if (_api == null) return const SizedBox.shrink();
    final url = _api!.getImageUrl(mediaPath);
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    final lower = url.toLowerCase();
    
    final isAudio =
        mediaType == 'audio' ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac');

    final isVideo =
        !isAudio && (
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ogg') ||
        lower.contains('video'));

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
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImagePage(imageUrl: url),
                    ),
                  );
                },
                child: Hero(
                  tag: url,
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
                    errorBuilder: (context, error, stackTrace) => Container(
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
                    ),
                  ),
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                          lang.translate('replying_to_message').replaceAll(
                            '{username}',
                            (_replyingTo!['sender_username'] ?? _contactUsername).toString(),
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
                          style: TextStyle(color: theme.hintColor, fontSize: 12),
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
              constraints: const BoxConstraints(minHeight: 42, maxHeight: 120),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor ??
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
                      : lang.translate('message_hint'),
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
        final mediaFile = File(picked.path);
        final lower = picked.path.toLowerCase();
        final isVideo =
            lower.endsWith('.mp4') ||
            lower.endsWith('.mov') ||
            lower.endsWith('.webm') ||
            lower.endsWith('.ogg') ||
            lower.endsWith('.avi') ||
            lower.endsWith('.mkv');

        // Afficher l'aperçu avant l'envoi
        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(
                lang.translate('preview_label'),
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isVideo
                        ? SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: FileVideoPlayer(file: mediaFile),
                          )
                        : Image.file(mediaFile, fit: BoxFit.contain),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(lang.translate('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    lang.translate('send'),
                    style: const TextStyle(color: Color(0xFFBE1E1E)),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            _uploadAndSend(picked.path);
          }
        }
      }
    }
  }

  Future<void> _uploadAndSend(String path) async {
    setState(() => _isSending = true);
    try {
      final api = await ApiService.getInstance();
      final mediaPath = await api.uploadFile(path, type: 'messages');

      // Détecter le type de média
      final lower = path.toLowerCase();
      String? mediaType;
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

      await api.sendMessage(
        widget.userId,
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
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, lang)),
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateFormatter.parseApiDate(dateStr);
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
    _callEndSub?.cancel();
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }
}
