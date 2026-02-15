import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import 'video_player_widget.dart';
import 'linkable_text.dart';
import 'militant_badge.dart';
import 'package:share_plus/share_plus.dart';

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
  late String _currentContent;
  final Set<String> _detectedUrls = {};

  @override
  void initState() {
    super.initState();
    _currentContent = widget.post.content;
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _resolveUrls();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si l'objet Post change (ex: recyclage dans ListView), on doit tout mettre à jour
    if (widget.post.id != oldWidget.post.id) {
      _currentContent = widget.post.content;
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
      _translatedContent = null;
      _showTranslation = false;
      _detectedUrls.clear();
      _resolveUrls();
    } else if (widget.post.content != oldWidget.post.content) {
      // Si c'est le même post mais contenu édité
      _currentContent = widget.post.content;
    }
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
              // Bandeau de partage
              if (widget.post.sharedByUsername != null) ...[
                Row(
                  children: [
                    const Icon(Icons.repeat, size: 16, color: Colors.white38),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.post.sharedByUsername} a partagé',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

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
                          backgroundColor: Colors.transparent,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: SvgPicture.asset(
                                    'assets/logo.svg',
                                    width: 40,
                                    height: 40,
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.post.username,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (widget.post.militantBadge != null) ...[
                                const SizedBox(width: 6),
                                MilitantBadge(
                                  badgeId: widget.post.militantBadge,
                                  size: 20,
                                ),
                              ],
                              if (widget.post.isModerator) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: 'Modérateur·ice élu·e',
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFBE1E1E,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.shield,
                                      size: 16,
                                      color: Color(0xFFBE1E1E),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          _formatDate(widget.post.feedDate),
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

              // Contenu avec liens cliquables
              LinkableText(
                text: _showTranslation && _translatedContent != null
                    ? _translatedContent!
                    : _currentContent,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
                onLinksDetected: (urls) {
                  // Filtrer les nouvelles URLs pour éviter les rebuilds inutiles
                  final newUrls = urls
                      .where((u) => !_detectedUrls.contains(u))
                      .toList();

                  if (newUrls.isNotEmpty) {
                    // Reporter le setState après le build pour éviter l'erreur
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        // Double check inside callback
                        final urlsToAdd = newUrls
                            .where((u) => !_detectedUrls.contains(u))
                            .toList();
                        if (urlsToAdd.isNotEmpty) {
                          setState(() {
                            _detectedUrls.addAll(urlsToAdd);
                          });
                        }
                      }
                    });
                  }
                },
              ),

              // Cartes de preview pour les liens réseaux sociaux
              if (_detectedUrls.isNotEmpty) ...[
                ..._detectedUrls.map((url) => LinkPreviewCard(url: url)),
              ],

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
                if (widget.post.mediaType == 'video' || _isVideoUrl(_mediaUrl!))
                  VideoPlayerWidget(videoUrl: _mediaUrl!)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _mediaUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
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
              ],

              const SizedBox(height: 12),

              // Actions (like, comment, share)
              Row(
                children: [
                  _buildActionButton(
                    icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_off_alt,
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
                _deletePost();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              leading: Icon(
                Icons.share,
                color: isDark ? Colors.white : Colors.black,
              ),
              title: Text(
                'Partager via...',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              onTap: () async {
                Navigator.pop(context);
                final api = await ApiService.getInstance();
                String baseUrl = api.baseUrl;
                if (baseUrl.endsWith('/api')) {
                  baseUrl = baseUrl.substring(0, baseUrl.length - 4);
                } else if (baseUrl.contains('api.')) {
                  baseUrl = baseUrl.replaceAll('api.', '');
                }

                String url;
                if (widget.post.type == 'group') {
                  url =
                      '$baseUrl/group_detail.php?id=${widget.post.groupId}#post-${widget.post.id}';
                } else {
                  url = '$baseUrl/post.php?id=${widget.post.id}';
                }

                await Share.share('Regarde ce post sur Militant !\n$url');
              },
            ),
            if (widget.post.type != 'group')
              ListTile(
                leading: Icon(
                  Icons.repeat,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Republier sur mon mur',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  _repostInternal(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _repostInternal(BuildContext context) async {
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

  void _editPost(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final controller = TextEditingController(text: widget.post.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          lang.translate('edit'),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: lang.translate('whats_new'),
            hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              lang.translate('cancel'),
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
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
        newContent != widget.post.content) {
      try {
        final api = await ApiService.getInstance();
        if (widget.post.type == 'group') {
          await api.updateGroupPost(widget.post.id, newContent);
        } else {
          await api.updatePost(widget.post.id, newContent);
        }

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(lang.translate('success'))),
          );

          setState(() {
            _currentContent = newContent;
          });
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
        }
      }
    }
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

  Future<void> _deletePost() async {
    final messenger = ScaffoldMessenger.of(
      context,
    ); // Capture context safe reference immediately
    final lang = LanguageService.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('delete'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('delete_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.translate('cancel'),
              style: const TextStyle(color: Colors.white70),
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
        if (widget.post.type == 'group') {
          await api.deleteGroupPost(widget.post.id);
        } else {
          await api.deletePost(widget.post.id);
        }

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(lang.translate('success'))),
          );
          // Call the onDeleted callback if provided
          widget.onDeleted?.call();
        }
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
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
