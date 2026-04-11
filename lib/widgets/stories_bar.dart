import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../screens/stories_screen.dart';
import '../widgets/file_video_player.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  // Liste des utilisateurs ayant des stories.
  // Chaque élément est une Map : {'user': 'user_data', 'stories': [list_of_stories]}
  List<Map<String, dynamic>> _userStories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final allStories = await api.getStories(); // Récupère la liste brute
      // debugPrint('DEBUG StoriesBar: Loaded ${allStories.length} raw stories');

      // Regrouper par utilisateur
      final Map<int, Map<String, dynamic>> grouped = {};

      for (var story in allStories) {
        final userId = story['user_id'];
        if (userId == null) continue;

        if (!grouped.containsKey(userId)) {
          grouped[userId] = {
            'user': {
              'id': userId,
              'username': story['username'] ?? 'Utilisateur',
              'avatar': story['avatar'],
            },
            'stories': <dynamic>[],
            'hasUnseen': false,
          };
        }
        grouped[userId]!['stories'].add(story);

        // Vérifier si non vue (simplifié ici, idéalement basé sur 'is_viewed')
        final isViewed = story['is_viewed'] == 1 || story['is_viewed'] == true;
        if (!isViewed) {
          grouped[userId]!['hasUnseen'] = true;
        }
      }

      if (mounted) {
        setState(() {
          _userStories = grouped.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG StoriesBar: Error loading stories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createStory() async {
    final lang = LanguageService.instance;
    final picker = ImagePicker();

    // Demander Image ou Vidéo
    final selection = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: Text(lang.translate('image'), style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, {'type': 'image'}),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: Text(lang.translate('video'), style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, {'type': 'video'}),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return;

    XFile? file;
    if (selection['type'] == 'image') {
      file = await picker.pickImage(source: ImageSource.gallery);
    } else {
      file = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (file == null) return;
    final mediaFile = File(file.path);
    final isVideo = selection['type'] == 'video';

    // Afficher l'aperçu avant l'upload
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(lang.translate('stories_preview'), style: const TextStyle(color: Colors.white)),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBE1E1E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.translate('publish_button'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Afficher un indicateur de chargement
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.translate('stories_uploading')),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    try {
      final api = await ApiService.getInstance();
      final mediaUrl = await api.uploadFile(mediaFile.path, type: 'stories');
      await api.createStory(media: mediaUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('stories_created'))),
        );
        _loadStories();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('stories_error')}: $e'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    // Toujours afficher au moins le bouton "+"
    // if (_userStories.isEmpty) ... pas nécessaire car on veut le bouton "+"

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        itemCount: _userStories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildAddStoryButton();
          }
          final userStoryGroup = _userStories[index - 1];
          return _buildStoryItem(userStoryGroup);
        },
      ),
    );
  }

  Widget _buildAddStoryButton() {
    final lang = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: _createStory,
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBE1E1E), width: 2),
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFFBE1E1E),
                  size: 30,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lang.translate('stories_add'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> group) {
    final user = group['user'];
    final List<dynamic> stories = group['stories'];
    final bool hasUnseen = group['hasUnseen'] ?? false;

    final username = user['username'] ?? 'Utilisateur';
    final avatar = user['avatar'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoriesScreen(stories: stories, initialIndex: 0),
            ),
          ).then((_) => _loadStories());
        },
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(2), // Espace pour la bordure
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasUnseen
                        ? const Color(0xFFBE1E1E) // Rouge si non vu
                        : const Color(0xFF888888), // Gris si tout vu
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: avatar != null
                      ? FutureBuilder<String>(
                          future: _getAvatarUrl(avatar),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Container(
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF888888),
                                ),
                              );
                            }
                            return Image.network(
                              snapshot.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFF1E1E1E),
                          child: Center(
                            child: Text(
                              (username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                username,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _getAvatarUrl(String avatar) async {
    final api = await ApiService.getInstance();
    final url = api.getImageUrl(avatar) ?? avatar;
    return url;
  }
}
