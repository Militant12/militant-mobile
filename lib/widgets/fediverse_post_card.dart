import 'package:flutter/material.dart';
import 'common/app_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/fediverse_post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/date_formatter.dart';
import '../utils/error_helper.dart';
import '../utils/fediverse_text.dart';
import 'linkable_text.dart';
import 'video_player_widget.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

class FediversePostCard extends StatefulWidget {
  final FediversePost post;
  final VoidCallback? onProfileTap;

  const FediversePostCard({super.key, required this.post, this.onProfileTap});

  @override
  State<FediversePostCard> createState() => _FediversePostCardState();
}

class _FediversePostCardState extends State<FediversePostCard> {
  bool _liked = false;
  bool _announced = false;
  bool _isLikeLoading = false;
  bool _isAnnounceLoading = false;
  bool _showReplyForm = false;
  bool _isSendingReply = false;
  bool _showReplies = false;
  bool _isLoadingReplies = false;
  List<Map<String, dynamic>>? _replies;
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading) return;
    final nextLiked = !_liked;
    setState(() {
      _liked = nextLiked;
      _isLikeLoading = true;
    });

    try {
      final api = await ApiService.getInstance();
      if (nextLiked) {
        await api.likeFediversePost(
          widget.post.id,
          remotePostId: widget.post.remotePostId,
        );
      } else {
        await api.unlikeFediversePost(
          widget.post.id,
          remotePostId: widget.post.remotePostId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked = !nextLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFriendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLikeLoading = false);
      }
    }
  }

  Future<void> _toggleAnnounce() async {
    if (_isAnnounceLoading) return;
    final nextAnnounced = !_announced;
    setState(() {
      _announced = nextAnnounced;
      _isAnnounceLoading = true;
    });

    try {
      final api = await ApiService.getInstance();
      if (nextAnnounced) {
        await api.announceFediversePost(
          widget.post.id,
          remotePostId: widget.post.remotePostId,
        );
      } else {
        await api.unannounceFediversePost(
          widget.post.id,
          remotePostId: widget.post.remotePostId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _announced = !nextAnnounced);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFriendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnnounceLoading = false);
      }
    }
  }

  Future<void> _toggleReplies() async {
    if (_showReplies) {
      setState(() => _showReplies = false);
      return;
    }

    setState(() => _showReplies = true);
    if (_replies != null || _isLoadingReplies) {
      return;
    }

    setState(() => _isLoadingReplies = true);
    try {
      final api = await ApiService.getInstance();
      final loaded = await api.getFediversePostReplies(
        widget.post.id,
        remotePostId: widget.post.remotePostId,
      );
      if (!mounted) return;
      setState(() {
        _replies = loaded;
        _isLoadingReplies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReplies = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFriendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _isSendingReply) return;

    setState(() => _isSendingReply = true);
    try {
      final api = await ApiService.getInstance();
      await api.replyFediversePost(
        widget.post.id,
        text,
        remotePostId: widget.post.remotePostId,
      );
      if (!mounted) return;
      final optimistic = <String, dynamic>{
        'handle': '@moi',
        'content': text,
        'published_at': DateTime.now().toUtc().toIso8601String(),
      };
      setState(() {
        _replyController.clear();
        _showReplyForm = false;
        _showReplies = true;
        _replies = [...(_replies ?? const []), optimistic];
        _isSendingReply = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReply = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFriendlyErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final accent = theme.colorScheme.primary;
    final content = fediverseHtmlToText(post.content);
    final avatarUrl = post.avatar != null && post.avatar!.trim().isNotEmpty
        ? post.avatar
        : null;
    final displayName = (post.displayName?.trim().isNotEmpty ?? false)
        ? post.displayName!.trim()
        : post.username;
    final lang = LanguageService.instance;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius20),
        border: Border.all(color: context.colors.outlineVariant),
        boxShadow: tokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.onProfileTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(url: avatarUrl, radius: 23),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTokens.fontBodyLarge,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.handle ?? '@${post.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatRelative(post.publishedAt),
                      style: TextStyle(color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinkableText(
                text: content,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  height: 1.45,
                ),
              ),
            ],
            if (post.mediaUrl != null && post.mediaUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              if (post.isVideo)
                VideoPlayerWidget(
                  videoUrl: post.mediaUrl!,
                  thumbnailUrl: ApiService.resolveVideoThumbnailUrl(
                    post.mediaUrl,
                    thumbnailPath: post.thumbnailUrl,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image(
                    image: CachedNetworkImageProvider(post.mediaUrl!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        color: theme.colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: AppTokens.space8),
            Transform.translate(
              offset: const Offset(-AppTokens.space8, 0),
              child: Row(
                children: [
                  _buildActionPill(
                    tooltip: lang.translate('like'),
                    icon: _liked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    color: _liked
                        ? context.colors.onPrimaryContainer
                        : tokens.textMuted,
                    selected: _liked,
                    onTap: _isLikeLoading ? null : _toggleLike,
                  ),
                  const SizedBox(width: AppTokens.space4),
                  _buildActionPill(
                    tooltip: lang.translate('share'),
                    icon: Icons.repeat_rounded,
                    color: _announced
                        ? context.colors.onPrimaryContainer
                        : tokens.textMuted,
                    selected: _announced,
                    onTap: _isAnnounceLoading ? null : _toggleAnnounce,
                  ),
                  const SizedBox(width: AppTokens.space4),
                  _buildActionPill(
                    tooltip: lang.translate('reply'),
                    icon: Icons.reply_rounded,
                    color: _showReplyForm ? accent : tokens.textMuted,
                    selected: _showReplyForm,
                    onTap: () =>
                        setState(() => _showReplyForm = !_showReplyForm),
                  ),
                  const SizedBox(width: AppTokens.space4),
                  _buildActionPill(
                    tooltip: lang.translate('comments'),
                    icon: Icons.comment_outlined,
                    label: _replies != null ? '${_replies!.length}' : null,
                    color: _showReplies ? accent : tokens.textMuted,
                    selected: _showReplies,
                    onTap: _toggleReplies,
                  ),
                  const Spacer(),
                  if (widget.onProfileTap != null)
                    _buildActionPill(
                      tooltip: lang.translate('profile'),
                      icon: Icons.person_outline_rounded,
                      color: tokens.textMuted,
                      onTap: widget.onProfileTap,
                    ),
                  _buildActionPill(
                    tooltip: lang.translate('open'),
                    icon: Icons.open_in_new_rounded,
                    color: tokens.textMuted,
                    onTap: () => _openExternalUrl(post.originalUrl),
                  ),
                ],
              ),
            ),
            if (_showReplyForm) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: lang.translate('reply'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSendingReply ? null : _sendReply,
                    child: _isSendingReply
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(lang.translate('send')),
                  ),
                ],
              ),
            ],
            if (_showReplies) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (_isLoadingReplies)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(lang.translate('loading')),
                    ],
                  ),
                )
              else if (_replies == null || _replies!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    lang.translate('no_comments'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                )
              else
                ..._replies!.map((reply) {
                  final handle = (reply['handle'] ?? '@${reply['username'] ?? ''}')
                      .toString();
                  final body = fediverseHtmlToText(reply['content']?.toString());
                  final origUrl = reply['original_url']?.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                handle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (origUrl != null && origUrl.isNotEmpty)
                              IconButton(
                                tooltip: lang.translate('open'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                onPressed: () => _openExternalUrl(origUrl),
                              ),
                          ],
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          LinkableText(
                            text: body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.textTheme.bodyLarge?.color,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required String tooltip,
    required IconData icon,
    required Color color,
    String? label,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (label != null) ...[
                    const SizedBox(width: AppTokens.space4),
                    Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalUrl(String? rawUrl) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return;
  }

  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) {
    return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
