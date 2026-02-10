import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../screens/post_detail_screen.dart';
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
          color: const Color(0xFF1E1E1E),
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête (avatar + nom + date)
              Row(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _formatDate(widget.post.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF888888)),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
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
                            : const Color(0xFF888888),
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
                              : const Color(0xFF888888),
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
                            color: const Color(0xFF2A2A2A),
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
                            color: const Color(0xFF2A2A2A),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    color: Color(0xFF888888),
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image non disponible',
                                    style: TextStyle(
                                      color: Colors.grey[600],
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
                        : const Color(0xFF888888),
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    label: widget.post.commentsCount.toString(),
                    color: const Color(0xFF888888),
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
                    color: const Color(0xFF888888),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_border, color: Colors.white),
              title: const Text(
                'Sauvegarder',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _savePost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text(
                'Modifier',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _editPost(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text(
                'Signaler',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _reportPost(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
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

  Future<void> _sharePost(BuildContext context) async {
    try {
      final api = await ApiService.getInstance();
      await api.sharePost(widget.post.id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post partagé !')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post sauvegardé !')));
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
    // TODO: Implémenter l'édition de post
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fonctionnalité à venir')));
  }

  void _reportPost(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Signaler ce post',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Voulez-vous signaler ce post aux modérateurs ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
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
                    const SnackBar(
                      content: Text('Post signalé aux modérateurs'),
                    ),
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
            child: const Text(
              'Signaler',
              style: TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Supprimer le post',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce post ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
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
          ).showSnackBar(const SnackBar(content: Text('Post supprimé')));
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
