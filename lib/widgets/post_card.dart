import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import 'video_player_widget.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onDeleted;

  const PostCard({super.key, required this.post, this.onDeleted});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likesCount;
  String? _avatarUrl;
  String? _mediaUrl;
  String? _translatedContent;
  bool _showTranslation = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _resolveUrls();
  }

  Future<void> _resolveUrls() async {
    final api = await ApiService.getInstance();
    if (mounted) {
      setState(() {
        _avatarUrl = api.getImageUrl(widget.post.userAvatar);
        if (widget.post.mediaUrls.isNotEmpty) {
          _mediaUrl = api.getImageUrl(widget.post.mediaUrls.first);
        }
      });
    }
  }

  Future<void> _toggleLike() async {
    final bool previouslyLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      final api = await ApiService.getInstance();
      if (previouslyLiked) {
        await api.unlikePost(widget.post.id);
      } else {
        await api.likePost(widget.post.id);
      }
    } catch (e) {
      // Annuler en cas d'erreur
      if (mounted) {
        setState(() {
          _isLiked = previouslyLiked;
          _likesCount += previouslyLiked
              ? 0
              : 0; // It's safer to just reload or handle properly
          // Let's just reset to previous state
        });
        _likesCount = previouslyLiked
            ? widget.post.likesCount
            : widget.post.likesCount;
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = isDark ? const Color(0xFF888888) : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: widget.post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 1),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête (avatar + nom + date)
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userId: widget.post.userId),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFBE1E1E),
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? Text(
                                  widget.post.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        if (widget.post.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF1E1E1E),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(userId: widget.post.userId),
                              ),
                            );
                          },
                          child: Text(
                            widget.post.username,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(widget.post.createdAt),
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: subtitleColor),
                    onPressed: () => _showPostMenu(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Contenu
              Text(
                _showTranslation && _translatedContent != null
                    ? _translatedContent!
                    : widget.post.content,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
              ),

              // Bouton traduire
              if (widget.post.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: _isTranslating ? null : _toggleTranslation,
                  child: Row(
                    children: [
                      Icon(
                        Icons.translate,
                        size: 16,
                        color: _showTranslation
                            ? const Color(0xFFBE1E1E)
                            : subtitleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isTranslating
                            ? 'Traduction...'
                            : _showTranslation
                            ? 'Voir l\'original'
                            : 'Traduire',
                        style: TextStyle(
                          color: _showTranslation
                              ? const Color(0xFFBE1E1E)
                              : subtitleColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Médias
              if (_mediaUrl != null) ...[
                const SizedBox(height: 12),
                if (_isVideoUrl(_mediaUrl!))
                  VideoPlayerWidget(videoUrl: _mediaUrl!)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: Image.network(
                        _mediaUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                color: const Color(0xFFBE1E1E),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Erreur chargement image: $error');
                          print('URL: $_mediaUrl');
                          return Container(
                            height: 200,
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey[200],
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: subtitleColor,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image non disponible',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 12),

              // Actions (like, comment, share)
              Row(
                children: [
                  _buildActionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: _likesCount.toString(),
                    color: _isLiked
                        ? const Color(0xFFBE1E1E)
                        : (subtitleColor ?? Colors.grey),
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    label: widget.post.commentsCount.toString(),
                    color: subtitleColor ?? Colors.grey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PostDetailScreen(post: widget.post),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.share_outlined,
                    label: widget.post.sharesCount.toString(),
                    color: subtitleColor ?? Colors.grey,
                    onTap: () => _sharePost(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showPostMenu(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final textColor = theme.textTheme.bodyLarge?.color;
    final iconColor = theme.iconTheme.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.bookmark_border, color: iconColor),
              title: Text(
                lang.translate('save'),
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _savePost();
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: iconColor),
              title: Text(
                lang.translate('edit'),
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _editPost(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag, color: iconColor),
              title: Text(
                lang.translate('report'),
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportPost(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                lang.translate('delete'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deletePost(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ... (keep _sharePost and _savePost and _editPost unchanged for now)

  Future<void> _sharePost(BuildContext context) async {
    try {
      final api = await ApiService.getInstance();
      await api.sharePost(widget.post.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.instance.translate('success')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _savePost() async {
    try {
      final api = await ApiService.getInstance();
      await api.bookmarkPost(widget.post.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.instance.translate('success')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  void _editPost(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
  }

  void _reportPost(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          lang.translate('report_post_title'),
          style: TextStyle(color: textColor),
        ),
        content: Text(
          lang.translate('report_reason_hint'), // Using hint as prompt
          style: TextStyle(color: subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lang.translate('cancel'),
              style: TextStyle(color: subtitleColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final api = await ApiService.getInstance();
                await api.reportContent(
                  postId: widget.post.id,
                  reason: 'other',
                  description: 'Contenu inapproprié',
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lang.translate('success'))),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text(
              lang.translate('report'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          lang.translate('delete'),
          style: TextStyle(color: textColor),
        ),
        content: Text(
          lang.translate('delete_post_confirm'),
          style: TextStyle(color: subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.translate('cancel'),
              style: TextStyle(color: subtitleColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final api = await ApiService.getInstance();
        await api.deletePost(widget.post.id);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lang.translate('success'))));
          // Call the onDeleted callback if provided
          widget.onDeleted?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    const videoExtensions = [
      '.mp4',
      '.webm',
      '.avi',
      '.mov',
      '.mkv',
      '.m4v',
      '.ogg',
      '.ogv',
    ];
    // Check file extension (strip query params first)
    final path = Uri.tryParse(lower)?.path ?? lower;
    return videoExtensions.any((ext) => path.endsWith(ext));
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      // Afficher l'original
      setState(() => _showTranslation = false);
      return;
    }

    // Si déjà traduit, juste afficher
    if (_translatedContent != null) {
      setState(() => _showTranslation = true);
      return;
    }

    // Traduire
    setState(() => _isTranslating = true);

    try {
      final api = await ApiService.getInstance();
      final result = await api.translateText(widget.post.content);

      if (result['success'] == true) {
        setState(() {
          _translatedContent = result['translated'];
          _showTranslation = true;
          _isTranslating = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Erreur de traduction');
      }
    } catch (e) {
      setState(() => _isTranslating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de traduction: ${e.toString()}')),
        );
      }
    }
  }
}
