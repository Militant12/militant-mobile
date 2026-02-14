import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/stories_screen.dart';
import 'package:image_picker/image_picker.dart';

class ProfileStories extends StatefulWidget {
  final int userId;
  final bool isMe;

  const ProfileStories({super.key, required this.userId, this.isMe = false});

  @override
  State<ProfileStories> createState() => _ProfileStoriesState();
}

class _ProfileStoriesState extends State<ProfileStories> {
  List<dynamic> _stories = [];
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
      final stories = await api.getUserStories(widget.userId);
      // print('DEBUG ProfileStories: Loaded ${stories.length} stories');
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG ProfileStories: Error loading stories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createStory() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload en cours...'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFBE1E1E),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Story créée avec succès!'),
              backgroundColor: Colors.green,
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFBE1E1E),
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Cas 1: Pas de story
    if (_stories.isEmpty) {
      if (!widget.isMe) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2C2C2C)),
            bottom: BorderSide(color: Color(0xFF2C2C2C)),
          ),
        ),
        child: GestureDetector(
          onTap: _createStory,
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBE1E1E), width: 2),
                  color: const Color(0xFF1E1E1E),
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFFBE1E1E),
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajouter une story',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Partagez un moment avec vos abonnés',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Cas 2: Il y a des stories -> Afficher UNE seule bulle
    final story = _stories.first;
    final media = story['media'] ?? '';
    final count = _stories.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C2C)),
          bottom: BorderSide(color: Color(0xFF2C2C2C)),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoriesScreen(stories: _stories, initialIndex: 0),
            ),
          ).then((_) => _loadStories());
        },
        child: Row(
          children: [
            Stack(
              children: [
                // Avatar / Thumbnail
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFBE1E1E),
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: FutureBuilder<String>(
                      future: _getMediaUrl(media),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(color: const Color(0xFF1E1E1E));
                        }
                        return Image.network(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF1E1E1E)),
                        );
                      },
                    ),
                  ),
                ),
                // Icone Play
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                // Badge nombre
                if (count > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBE1E1E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isMe ? 'Vos stories' : 'Stories à la une',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isMe
                      ? '$count story${count > 1 ? 's' : ''} visible${count > 1 ? 's' : ''}'
                      : 'Regarder les stories',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            if (widget.isMe)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                onPressed: _createStory,
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<String> _getMediaUrl(String media) async {
    final api = await ApiService.getInstance();
    final url = api.getImageUrl(media) ?? media;
    return url;
  }
}
