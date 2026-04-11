import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/video_player_widget.dart';
import '../widgets/file_video_player.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../utils/date_formatter.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/linkable_text.dart';
import '../widgets/incoming_call_banner.dart';

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
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _isRecording = false;
  Map<String, dynamic>? _currentUser;
  ApiService? _api;
  StreamSubscription<IncomingCallData?>? _callEndSub;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {}); // Rebuild pour afficher/cacher le bouton micro
    });
    _loadMessages();
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

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      _currentUser = await _api!.getProfile();
      final messages = await _api!.getMessages(userId: widget.userId);
      setState(() {
        _messages.clear();
        _messages.addAll(
          messages,
        ); // API returns newest first, correct for ListView(reverse:true)
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
    };

    setState(() {
      _isSending = true;
      _messages.insert(
        0,
        tempMessage,
      ); // Add at the beginning (bottom of the UI)
    });
    _messageController.clear();

    try {
      final api = await ApiService.getInstance();
      await api.sendMessage(widget.userId, content);
      await _loadMessages(); // Refresh to get official data and server timestamps
    } catch (e) {
      setState(() {
        _messages.removeAt(0); // Remove optimistic message on error
      });
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
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
            Text(
              widget.username,
              style: TextStyle(color: theme.textTheme.titleLarge?.color),
            ),
          ],
        ),
        actions: [
          /* Boutons d'appels temporairement désactivés
          // Bouton appel audio
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    recipientId: widget.userId,
                    recipientName: widget.username,
                    recipientAvatar: _api?.getImageUrl(widget.avatar),
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
                    recipientName: widget.username,
                    recipientAvatar: _api?.getImageUrl(widget.avatar),
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
          */
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
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
              _buildMessageInput(),
            ],
          ),
          // Bannière d'appel entrant (affichée au-dessus du chat)
          IncomingCallBanner(peerId: widget.userId),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return FutureBuilder<ApiService>(
      future: ApiService.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircleAvatar(radius: 16);
        final api = snapshot.data!;
        final url = api.getImageUrl(widget.avatar);

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
              widget.username.isNotEmpty
                  ? widget.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          );
        }
      },
    );
  }

  void _showOptions(dynamic message) {
    bool isMine = message['is_mine'] == true || message['is_mine'] == 1;

    // Fallback if is_mine is missing (e.g. from local update or specific API response)
    if (!isMine && _currentUser != null && message['sender_id'] != null) {
      isMine =
          message['sender_id'].toString() == _currentUser!['id'].toString();
    }

    // Private chat: never allow edit/delete options on received messages.
    if (!isMine) {
      return;
    }

    final lang = LanguageService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    final api = await ApiService.getInstance();
                    await api.deleteMessage(message['id']);
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
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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
        onLongPress: isMine ? () => _showOptions(message) : null,
        onSecondaryTap: isMine ? () => _showOptions(message) : null,
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
              if (media != null && media.toString().isNotEmpty)
                _buildMedia(media, isMine),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
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
    if (_api == null) return const SizedBox.shrink();
    final url = _api!.getImageUrl(mediaPath);
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    final lower = url.toLowerCase();
    final isVideo =
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ogg') ||
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
            : Image.network(
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
        left: 16,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: Color(0xFFBE1E1E)),
            onPressed: _pickMedia,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: lang.translate('message_hint'),
                hintStyle: TextStyle(color: theme.hintColor),
                border: InputBorder.none,
              ),
              maxLines: null,
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
                      decoration: const InputDecoration(
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
        final isVideo = lower.endsWith('.mp4') ||
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
      );
      _loadMessages();
    } catch (e) {
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
      final date = DateFormatter.parseApiDate(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  @override
  void dispose() {
    _callEndSub?.cancel();
    _messageController.dispose();
    super.dispose();
  }
}
