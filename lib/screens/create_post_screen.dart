import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/file_video_player.dart';

class CreatePostScreen extends StatefulWidget {
  final int? groupId;
  const CreatePostScreen({super.key, this.groupId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  File? _mediaFile;
  final ImagePicker _picker = ImagePicker();
  Timer? _mentionDebounce;
  bool _isMentionLoading = false;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  int _mentionRequestId = 0;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    final query = _extractMentionQuery(
      _contentController.text,
      _contentController.selection.baseOffset,
    );
    _scheduleMentionSearch(query);
  }

  String? _extractMentionQuery(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    final beforeCursor = text.substring(0, cursor);
    final match = RegExp(r'(^|[\s\n])@([A-Za-z0-9_]*)$').firstMatch(beforeCursor);
    if (match == null) return null;
    final query = match.group(2) ?? '';
    if (query.isEmpty) return null;
    return query;
  }

  void _scheduleMentionSearch(String? query) {
    _mentionDebounce?.cancel();
    if (query == null || query.isEmpty) {
      if (_mentionSuggestions.isNotEmpty || _isMentionLoading) {
        setState(() {
          _mentionSuggestions = [];
          _isMentionLoading = false;
        });
      }
      return;
    }

    _mentionDebounce = Timer(const Duration(milliseconds: 220), () {
      _searchMentionUsers(query);
    });
  }

  Future<void> _searchMentionUsers(String query) async {
    final requestId = ++_mentionRequestId;
    setState(() => _isMentionLoading = true);
    try {
      final api = await ApiService.getInstance();
      final data = await api.search(query, type: 'users', page: 1);
      final raw = data['data'] is List
          ? data['data'] as List
          : (data['items'] is List ? data['items'] as List : <dynamic>[]);
      final suggestions = raw
          .whereType<Map>()
          .map((u) => Map<String, dynamic>.from(u))
          .where((u) => (u['username'] ?? '').toString().trim().isNotEmpty)
          .take(6)
          .toList();

      if (!mounted || requestId != _mentionRequestId) return;
      setState(() {
        _mentionSuggestions = suggestions;
        _isMentionLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _mentionRequestId) return;
      setState(() {
        _mentionSuggestions = [];
        _isMentionLoading = false;
      });
    }
  }

  void _insertMention(String username) {
    final value = _contentController.value;
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) return;

    final beforeCursor = value.text.substring(0, cursor);
    final match = RegExp(r'(^|[\s\n])@([A-Za-z0-9_]*)$').firstMatch(beforeCursor);
    if (match == null) return;

    final prefix = match.group(1) ?? '';
    final start = match.start + prefix.length;
    final replacement = '@$username ';
    final newText = value.text.replaceRange(start, cursor, replacement);
    final newCursor = start + replacement.length;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _mentionSuggestions = [];
      _isMentionLoading = false;
    });
  }

  Future<void> _pickMedia() async {
    // Retourne un Map avec 'source' et 'isVideo'
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Text(LanguageService.instance.translate('choose_media')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFBE1E1E),
              ),
              title: Text(LanguageService.instance.translate('image_from_gallery')),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFBE1E1E)),
              title: Text(LanguageService.instance.translate('video_from_gallery')),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': true,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFBE1E1E)),
              title: Text(LanguageService.instance.translate('take_photo')),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.camera,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFBE1E1E)),
              title: Text(LanguageService.instance.translate('record_video')),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.camera,
                'isVideo': true,
              }),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final ImageSource source = result['source'];
      final bool isVideo = result['isVideo'];

      try {
        print('=== PICK MEDIA: Source: $source, isVideo: $isVideo ===');

        XFile? pickedFile;
        if (isVideo) {
          pickedFile = await _picker.pickVideo(source: source);
        } else {
          pickedFile = await _picker.pickImage(source: source);
        }

        print('=== PICK MEDIA: Fichier sélectionné: ${pickedFile?.path} ===');

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final fileSize = await file.length();
          print(
            '=== PICK MEDIA: Taille: $fileSize bytes, Extension: ${pickedFile.path.split('.').last} ===',
          );

          setState(() {
            _mediaFile = file;
          });
        } else {
          print('=== PICK MEDIA: Aucun fichier sélectionné ===');
        }
      } catch (e) {
        print('=== PICK MEDIA: Erreur: $e ===');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _createPost() async {
    final lang = LanguageService.instance;
    print('=== CREATE POST: Début ===');
    print('=== CREATE POST: Contenu: ${_contentController.text.trim()} ===');
    print('=== CREATE POST: Média file: ${_mediaFile?.path} ===');

    if (_contentController.text.trim().isEmpty && _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('add_content_or_media'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = await ApiService.getInstance();

      String? mediaUrl;
      String? mediaType;

      if (_mediaFile != null) {
        print('=== CREATE POST: Upload du média ===');
        // Upload media
        final ext = _mediaFile!.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'webm', 'mov', 'avi'].contains(ext);
        mediaType = isVideo ? 'video' : 'image';

        print('=== CREATE POST: Extension: $ext, Type: $mediaType ===');

        mediaUrl = await api.uploadFile(_mediaFile!.path, type: 'posts');

        print('=== CREATE POST: URL retournée: $mediaUrl ===');

        // Extract just the filename from the returned path
        if (mediaUrl.contains('/')) {
          mediaUrl = mediaUrl.split('/').last;
        }

        print('=== CREATE POST: URL finale: $mediaUrl ===');
      }

      if (widget.groupId != null) {
        await api.createGroupPost(
          widget.groupId!,
          _contentController.text.trim(),
          media: mediaUrl != null ? [mediaUrl] : null,
          mediaType: mediaType,
        );
      } else {
        await api.createPost(
          _contentController.text.trim(),
          mediaUrls: mediaUrl != null ? [mediaUrl] : null,
          mediaType: mediaType,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.translate('error_generic')}: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang.translate('create_post_title'),
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isLoading ? null : _createPost,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBE1E1E),
                      ),
                    )
                  : Text(
                      lang.translate('publish_button'),
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _contentController,
                    autofocus: true,
                    maxLines: null,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: lang.translate('create_post_hint'),
                      hintStyle: TextStyle(color: theme.hintColor),
                      border: InputBorder.none,
                    ),
                  ),
                  if (_isMentionLoading || _mentionSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: _isMentionLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _mentionSuggestions.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: theme.dividerColor,
                                ),
                                itemBuilder: (context, index) {
                                  final user = _mentionSuggestions[index];
                                  final username =
                                      (user['username'] ?? '').toString();
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 0,
                                    ),
                                    leading: const CircleAvatar(
                                      radius: 14,
                                      child: Icon(Icons.person, size: 14),
                                    ),
                                    title: Text(
                                      '@$username',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    onTap: () => _insertMention(username),
                                  );
                                },
                              ),
                            ),
                    ),
                  if (_mediaFile != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isVideo(_mediaFile!.path)
                              ? SizedBox(
                                  height: 300,
                                  width: double.infinity,
                                  child: FileVideoPlayer(file: _mediaFile!),
                                )
                              : Image.file(
                                  _mediaFile!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                _mediaFile = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey[200],
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo, color: Color(0xFFBE1E1E)),
                  onPressed: _pickMedia,
                  tooltip: 'Ajouter une image ou vidéo',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isVideo(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'webm', 'mov', 'avi'].contains(ext);
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _contentController.removeListener(_onContentChanged);
    _contentController.dispose();
    super.dispose();
  }
}
