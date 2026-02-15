import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  Future<void> _pickMedia() async {
    // Retourne un Map avec 'source' et 'isVideo'
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Choisir un média'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFBE1E1E),
              ),
              title: const Text('Image de la galerie'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFBE1E1E)),
              title: const Text('Vidéo de la galerie'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': true,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFBE1E1E)),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.camera,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFBE1E1E)),
              title: const Text('Filmer une vidéo'),
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
    print('=== CREATE POST: Début ===');
    print('=== CREATE POST: Contenu: ${_contentController.text.trim()} ===');
    print('=== CREATE POST: Média file: ${_mediaFile?.path} ===');

    if (_contentController.text.trim().isEmpty && _mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez du contenu ou un média')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
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
                  if (_mediaFile != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isVideo(_mediaFile!.path)
                              ? Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                  ),
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
    _contentController.dispose();
    super.dispose();
  }
}
