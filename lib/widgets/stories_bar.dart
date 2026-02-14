import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../screens/stories_screen.dart';

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
      // print('DEBUG StoriesBar: Loaded ${allStories.length} raw stories');

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
      print('DEBUG StoriesBar: Error loading stories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createStory() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // Afficher un indicateur de chargement
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload en cours...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final api = await ApiService.getInstance();
      print('DEBUG: Uploading file: ${image.path}');
      final mediaUrl = await api.uploadFile(image.path, type: 'stories');
      print('DEBUG: Upload successful, mediaUrl: $mediaUrl');

      await api.createStory(media: mediaUrl);
      print('DEBUG: Story created successfully');

      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('stories_created'))),
        );
        _loadStories();
      }
    } catch (e) {
      print('DEBUG: Error creating story: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
