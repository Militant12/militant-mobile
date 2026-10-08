import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import 'video_player_widget.dart';
import 'linkable_text.dart';
import 'militant_badge.dart';
import 'technician_badge.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';
import '../utils/date_formatter.dart';
import '../utils/error_helper.dart';
import 'common/common.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onDeleted;
  /// Si true, l'utilisateur courant est admin du groupe → peut supprimer n'importe quel post du groupe
  final bool isGroupAdmin;

  const PostCard({super.key, required this.post, this.onDeleted, this.isGroupAdmin = false});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likesCount;
  String? _avatarUrl;
  String? _mediaUrl;
  String? _videoThumbnailUrl;
  String? _translatedContent;
  bool _showTranslation = false;
  bool _isTranslating = false;
  late String _currentContent;
  int? _currentUserId;
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
    final currentId = await api.getCurrentUserId();
    final mediaPaths = widget.post.mediaUrls;
    final isVideoPost = widget.post.mediaType == 'video';
    final rawVideoPath = isVideoPost
        ? mediaPaths.cast<String?>().firstWhere(
            (path) => path != null && _isVideoUrl(path),
            orElse: () => mediaPaths.isNotEmpty ? mediaPaths.first : null,
          )
        : mediaPaths.isNotEmpty
        ? mediaPaths.first
        : null;
    final rawThumbnailPath = isVideoPost
        ? mediaPaths.cast<String?>().firstWhere(
            (path) => path != null && !_isVideoUrl(path),
            orElse: () => widget.post.thumbnailUrl,
          )
        : null;
    if (mounted) {
      setState(() {
        _currentUserId = currentId;
        _avatarUrl = api.getImageUrl(widget.post.userAvatar);
        if (rawVideoPath != null) {
          _mediaUrl = api.getImageUrl(rawVideoPath);
          _videoThumbnailUrl = ApiService.resolveVideoThumbnailUrl(
            rawVideoPath,
            thumbnailPath: rawThumbnailPath,
            baseUrl: api.baseUrl,
          );
        }
      });
    }
  }

  Future<void> _toggleLike() async {
    final bool previouslyLiked = _isLiked;
    final int previousLikesCount = _likesCount;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      final api = await ApiService.getInstance();

      // Vérifier le type de post pour utiliser la bonne API
      if (widget.post.type == 'group') {
        // Post de groupe
        if (previouslyLiked) {
          await api.removeGroupPostReaction(widget.post.id);
        } else {
          await api.reactToGroupPost(widget.post.id, 'like');
        }
      } else if (widget.post.type == 'page') {
        // Post de page
        if (previouslyLiked) {
          // Pour les pages, on envoie la même réaction pour toggle
          await api.reactToPagePost(widget.post.id, 'like');
        } else {
          await api.reactToPagePost(widget.post.id, 'like');
        }
      } else {
        // Post normal
        if (previouslyLiked) {
          await api.unlikePost(widget.post.id);
        } else {
          await api.likePost(widget.post.id);
        }
      }
    } catch (e) {
      // Annuler en cas d'erreur
      if (mounted) {
        setState(() {
          _isLiked = previouslyLiked;
          _likesCount = previousLikesCount;
        });
      }
      debugPrint('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final colors = context.colors;
    final textColor = colors.onSurface;
    final subtitleColor = context.tokens.textMuted;

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
          color: colors.surface,
          border: Border(
            bottom: BorderSide(color: context.theme.dividerColor, width: 1),
          ),
          boxShadow: context.tokens.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bandeau de partage
              if (widget.post.sharedByUsername != null) ...[
                Row(
                  children: [
                    Icon(Icons.repeat, size: 16, color: subtitleColor),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        lang
                            .translate('post_shared_by')
                            .replaceAll(
                              '{username}',
                              widget.post.sharedByUsername!,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
                    child: AppAvatar(
                      url: _avatarUrl,
                      radius: 20,
                      semanticLabel: widget.post.username,
                      online: widget.post.isOnline,
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
                              Flexible(
                                child: Text(
                                  widget.post.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              if (widget.post.militantBadge != null) ...[
                                const SizedBox(width: 6),
                                MilitantBadge(
                                  badgeId: widget.post.militantBadge,
                                  size: 20,
                                ),
                              ],
                              if (widget.post.isMilitantTechnician) ...[
                                const SizedBox(width: 4),
                                const TechnicianBadge(size: 20),
                              ],
                              if (widget.post.isModerator) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: lang.translate(
                                    'post_elected_moderator',
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      Icons.shield,
                                      size: 16,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          DateFormatter.formatRelative(widget.post.feedDate),
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: subtitleColor),
                    tooltip: lang.translate('action_more_options'),
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
                style: TextStyle(color: textColor, fontSize: 18, height: 1.4),
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
                            ? colors.primary
                            : subtitleColor,
                      ),
                      const SizedBox(width: AppTokens.space4),
                      Text(
                        _isTranslating
                            ? lang.translate('post_translating')
                            : _showTranslation
                            ? lang.translate('post_show_original')
                            : lang.translate('translate_action'),
                        style: TextStyle(
                          color: _showTranslation
                              ? colors.primary
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
                  VideoPlayerWidget(
                    videoUrl: _mediaUrl!,
                    thumbnailUrl: _videoThumbnailUrl,
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radius12),
                    child: Image.network(
                      _mediaUrl!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SkeletonBox(
                          width: double.infinity,
                          height: 200,
                          radius: 0,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Image load failed ($_mediaUrl): $error');
                        return Container(
                          height: 200,
                          color: colors.surfaceContainerHigh,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: subtitleColor,
                                  size: 48,
                                ),
                                const SizedBox(height: AppTokens.space8),
                                Text(
                                  lang.translate('post_image_unavailable'),
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
                    count: _likesCount,
                    semanticsKey: 'post_likes_count',
                    selected: _isLiked,
                    color: _isLiked ? colors.primary : subtitleColor,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 24),
                  _buildActionButton(
                    icon: Icons.comment_outlined,
                    count: widget.post.commentsCount,
                    semanticsKey: 'post_comments_count',
                    color: subtitleColor,
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
                    count: widget.post.sharesCount,
                    semanticsKey: 'post_shares_count',
                    color: subtitleColor,
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
    required int count,
    required String semanticsKey,
    required Color color,
    required VoidCallback onTap,
    bool? selected,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: LanguageService.instance
          .translate(semanticsKey)
          .replaceAll('{count}', '$count'),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppTokens.space4),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
      builder: (sheetContext) => SafeArea(
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
                Navigator.pop(sheetContext);
                _savePost();
              },
            ),
            if (_currentUserId == widget.post.userId)
              ListTile(
                leading: Icon(Icons.edit, color: iconColor),
                title: Text(
                  lang.translate('edit'),
                  style: TextStyle(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
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
                Navigator.pop(sheetContext);
                _reportPost(context);
              },
            ),
            if (_currentUserId == widget.post.userId || widget.isGroupAdmin)
              ListTile(
                leading: Icon(Icons.delete, color: theme.colorScheme.error),
                title: Text(
                  lang.translate('delete'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
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
    final lang = LanguageService.instance;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(lang.translate('share_via')),
              onTap: () async {
                Navigator.pop(sheetContext);
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

                await Share.share(
                  '${lang.translate('post_share_message')}\n$url',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(lang.translate('repost_to_group')),
              onTap: () async {
                Navigator.pop(sheetContext);
                _showRepostToGroupSheet(context);
              },
            ),
            if (widget.post.type != 'group')
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(lang.translate('repost_to_wall')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  _repostInternal();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showRepostToGroupSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;
    final groupsFuture = _loadRepostGroups();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: groupsFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: AppLoader(),
              );
            }

            if (snapshot.hasError) {
              return ErrorState(error: snapshot.error);
            }

            final groups = snapshot.data ?? [];
            if (groups.isEmpty) {
              return EmptyState(
                icon: Icons.groups_outlined,
                title: lang.translate('no_groups_message'),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          color: theme.iconTheme.color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lang.translate('choose_group'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final name =
                            _stringFromGroup(group, 'name') ??
                            lang.translate('group');
                        final description =
                            _stringFromGroup(group, 'description') ?? '';
                        final groupId = _intFromGroup(group, 'id');

                        return ListTile(
                          leading: _buildRepostGroupAvatar(group, name),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: description.isEmpty
                              ? null
                              : Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: subtitleColor),
                                ),
                          onTap: groupId == null
                              ? null
                              : () {
                                  Navigator.pop(sheetContext);
                                  _repostToGroup(groupId, name);
                                },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<dynamic>> _loadRepostGroups() async {
    final api = await ApiService.getInstance();
    final groups = await api.getGroups();
    return groups.map((group) {
      if (group is! Map) return group;
      final copy = Map<String, dynamic>.from(group);
      copy['_resolved_avatar_url'] = api.getImageUrl(
        _stringFromGroup(copy, 'avatar') ??
            _stringFromGroup(copy, 'avatar_url') ??
            _stringFromGroup(copy, 'image'),
      );
      return copy;
    }).toList();
  }

  Widget _buildRepostGroupAvatar(dynamic group, String name) {
    return AppAvatar(
      url: _stringFromGroup(group, '_resolved_avatar_url'),
      semanticLabel: name,
    );
  }

  int? _intFromGroup(dynamic group, String key) {
    if (group is! Map) return null;
    final value = group[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String? _stringFromGroup(dynamic group, String key) {
    if (group is! Map) return null;
    final value = group[key];
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Future<void> _repostToGroup(int groupId, String groupName) async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      final source = lang
          .translate('repost_source')
          .replaceAll('{username}', widget.post.username);
      final originalContent = widget.post.content.trim();
      final content = originalContent.isEmpty
          ? source
          : '$source\n\n$originalContent';

      await api.createGroupPost(
        groupId,
        content,
        media: widget.post.mediaUrls,
        mediaType: widget.post.mediaType,
        tags: widget.post.tags,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang
                  .translate('reposted_to_group')
                  .replaceAll('{group}', groupName),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _repostInternal() async {
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
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
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
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
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
              style: TextStyle(color: theme.colorScheme.primary),
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
            SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
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
    final messenger = ScaffoldMessenger.of(context);
    const reasons = <String>[
      'spam',
      'harassment',
      'hate_speech',
      'misinformation',
      'violence',
      'other',
    ];
    final descriptionController = TextEditingController();
    var selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            lang.translate('report_post_title'),
            style: TextStyle(color: textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                dropdownColor: theme.cardColor,
                decoration: InputDecoration(
                  labelText: lang.translate('report_reason_hint'),
                  labelStyle: TextStyle(color: subtitleColor),
                ),
                style: TextStyle(color: textColor),
                items: reasons
                    .map(
                      (reason) => DropdownMenuItem<String>(
                        value: reason,
                        child: Text(
                          lang.translate('live_report_reason_$reason'),
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedReason = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: lang.translate('live_report_details_label'),
                  labelStyle: TextStyle(color: subtitleColor),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                descriptionController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text(
                lang.translate('cancel'),
                style: TextStyle(color: subtitleColor),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final api = await ApiService.getInstance();
                  final result = await api.reportContent(
                    postId: widget.post.id,
                    reason: selectedReason,
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
                  );
                  final reportId = int.tryParse('${result['report_id'] ?? ''}');

                  if (mounted) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(lang.translate('report_submitted')),
                        action: reportId == null
                            ? null
                            : SnackBarAction(
                                label: lang.translate('undo'),
                                onPressed: () {
                                  _cancelOwnReport(
                                    reportId: reportId,
                                    messenger: messenger,
                                    lang: lang,
                                  );
                                },
                              ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    final errorMessage = e.toString().replaceFirst(
                      'Exception: ',
                      '',
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          errorMessage.contains('Already reported')
                              ? lang.translate('report_already_sent')
                              : '${lang.translate('error')}: $errorMessage',
                        ),
                      ),
                    );
                  }
                } finally {
                  descriptionController.dispose();
                }
              },
              child: Text(
                lang.translate('report_submit'),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOwnReport({
    required int reportId,
    required ScaffoldMessengerState messenger,
    required LanguageService lang,
  }) async {
    try {
      final api = await ApiService.getInstance();
      await api.cancelOwnReport(reportId: reportId, postId: widget.post.id);

      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(lang.translate('report_cancelled'))),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${lang.translate('error')}: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _deletePost() async {
    final messenger = ScaffoldMessenger.of(
      context,
    ); // Capture context safe reference immediately
    final lang = LanguageService.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('delete')),
        content: Text(lang.translate('delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              lang.translate('cancel'),
              style: TextStyle(color: context.tokens.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('delete'),
              style: TextStyle(color: context.colors.error),
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
            SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
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
        throw Exception(
          result['error'] ??
              LanguageService.instance.translate('error_translation'),
        );
      }
    } catch (e) {
      setState(() => _isTranslating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e))),
        );
      }
    }
  }
}

/// Squelette d'un [PostCard] affiché pendant le premier chargement du fil.
///
/// À placer sous un [SkeletonPulse] pour que plusieurs squelettes pulsent
/// ensemble.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.space4),
      padding: const EdgeInsets.all(AppTokens.space16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.theme.dividerColor, width: 1),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(height: 40, circle: true),
              SizedBox(width: AppTokens.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 14),
                  SizedBox(height: AppTokens.space8),
                  SkeletonBox(width: 40, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: AppTokens.space16),
          SkeletonBox(width: double.infinity, height: 14),
          SizedBox(height: AppTokens.space8),
          FractionallySizedBox(
            widthFactor: 0.7,
            child: SkeletonBox(height: 14),
          ),
          SizedBox(height: AppTokens.space12),
          SkeletonBox(
            width: double.infinity,
            height: 180,
            radius: AppTokens.radius12,
          ),
          SizedBox(height: AppTokens.space16),
          SkeletonBox(width: 160, height: 16),
        ],
      ),
    );
  }
}
