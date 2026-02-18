import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../widgets/video_player_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/audio_recorder_widget.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'group_settings_screen.dart';
import '../widgets/linkable_text.dart';
import 'call_screen.dart';
import 'group_call_screen.dart';

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
  ApiService? _api;
  Map<String, dynamic>? _groupDetails;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {}); // Rebuild pour afficher/cacher le bouton micro
    });
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final messages = await _api!.getGroupMessages(widget.groupId);
      print('DEBUG: Loaded ${messages.length} messages');
      if (messages.isNotEmpty) {
        print('DEBUG: First message: ${messages.first}');
      }
      _groupDetails = await _api!.getGroupDetails(widget.groupId);
      setState(() {
        _messages.clear();
        _messages.addAll(messages.reversed);
      });
    } catch (e) {
      print('DEBUG: Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
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
      'sender_id': 0, // Will be replaced by server data
      'content': content,
      'is_mine': true,
      'username': 'Moi', // Placeholder
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _isSending = true;
      _messages.insert(0, tempMessage);
    });
    _messageController.clear();

    try {
      final api = await ApiService.getInstance();
      await api.sendGroupMessage(widget.groupId, content);
      await _loadMessages(); // Refresh
    } catch (e) {
      setState(() {
        _messages.removeAt(0); // Remove local message
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_groupDetails?['auto_delete_time'] != null &&
                      _groupDetails!['auto_delete_time'] > 0)
                    Text(
                      'Éphémère: ${_groupDetails!['auto_delete_time']} min',
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
          // Bouton appel audio de groupe
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCallScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    isVideo: false,
                    isIncoming: false,
                  ),
                ),
              );
            },
            tooltip: LanguageService.instance.translate('call_group_audio'),
          ),
          // Bouton appel vidéo de groupe
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCallScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    isVideo: true,
                    isIncoming: false,
                  ),
                ),
              );
            },
            tooltip: LanguageService.instance.translate('call_group_video'),
          ),
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      'Aucun message dans ce groupe',
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
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Modifier',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFBE1E1E)),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Color(0xFFBE1E1E)),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text(
                      'Supprimer ?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Voulez-vous supprimer ce message ?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Supprimer',
                          style: TextStyle(color: Color(0xFFBE1E1E)),
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
    final controller = TextEditingController(text: message['content']);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Modifier le message',
          style: TextStyle(color: Colors.white),
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
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(
              'Enregistrer',
              style: TextStyle(color: Color(0xFFBE1E1E)),
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

  Widget _buildMessageBubble(dynamic message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = message['content'] ?? '';
    final media = message['media'];
    final username = message['username'] ?? 'Anonyme';
    final isMine = message['is_mine'] == true || message['is_mine'] == 1;
    final createdAt = message['created_at'] ?? '';
    final editedAt = message['edited_at'];

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
                                  isTranslated ? 'Original' : 'Traduire',
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
                          'Modifié ',
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
          ],
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur de traduction: $e')));
        }
      }
    } else {
      setState(() {
        message['_isTranslated'] = true;
      });
    }
  }

  Widget _buildMedia(String mediaPath, bool isMine) {
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
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(color: Colors.white54),
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
                hintText: 'Message au groupe...',
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
              title: const Text(
                'Galerie',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Appareil photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.audiotrack, color: Colors.white),
              title: const Text('Audio', style: TextStyle(color: Colors.white)),
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
              title: const Text('Lien', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final controller = TextEditingController();
                final url = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text(
                      'Partager un lien',
                      style: TextStyle(color: Colors.white),
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
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text('Partager'),
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
      );
      _loadMessages();
    } catch (e) {
      print('DEBUG: Error in _uploadAndSend: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload: ${e.toString()}')),
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
    _messageController.dispose();
    super.dispose();
  }
}
