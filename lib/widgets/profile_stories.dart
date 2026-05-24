import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
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
      if (mounted) {
        setState(() {
          _stories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG ProfileStories: Error loading stories: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createStory() async {
    final lang = LanguageService.instance;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.translate('stories_uploading')),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFBE1E1E),
          ),
        );
      }

      try {
        final api = await ApiService.getInstance();
        debugPrint('DEBUG: Uploading file: ${image.path}');
        final mediaUrl = await api.uploadFile(image.path, type: 'stories');
        debugPrint('DEBUG: Upload successful, mediaUrl: $mediaUrl');

        await api.createStory(media: mediaUrl);
        debugPrint('DEBUG: Story created successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.translate('stories_created')),
              backgroundColor: Colors.green,
            ),
          );
          _loadStories();
        }
      } catch (e) {
        debugPrint('DEBUG: Error creating story: $e');
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

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
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerColor),
            bottom: BorderSide(color: theme.dividerColor),
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
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFFBE1E1E),
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.translate('stories_add'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      lang.translate('profile_stories_add_subtitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ),
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
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
                          return Container(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey[100],
                          );
                        }
                        return Image.network(
                          snapshot.data!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey[100],
                          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isMe
                        ? lang.translate('profile_stories_yours')
                        : lang.translate('profile_stories_featured'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isMe
                        ? lang
                              .translate(
                                count > 1
                                    ? 'profile_stories_visible_plural'
                                    : 'profile_stories_visible_singular',
                              )
                              .replaceAll('{count}', '$count')
                        : lang.translate('profile_stories_watch'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (widget.isMe)
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: theme.iconTheme.color,
                ),
                onPressed: _createStory,
              )
            else
              Icon(Icons.chevron_right, color: subtitleColor),
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
