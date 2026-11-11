import 'package:flutter/material.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/comment_threads.dart';
import '../services/language_service.dart';
import '../widgets/post_card.dart';
import '../widgets/comments/comment_thread_view.dart';
import '../widgets/mention_user_avatar.dart';
import '../theme/theme_context.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';
import '../theme/app_tokens.dart';

class PostDetailScreen extends StatefulWidget {
  final Post? post;
  final int? postId;

  const PostDetailScreen({super.key, this.post, this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<CommentThread> _threads = [];

  /// Fils dépliés, par identifiant du commentaire principal. Gardés quand la
  /// liste est rechargée.
  final Set<int> _expanded = {};
  ApiService? _api;
  bool _isLoading = false;
  Object? _loadError;
  int? _currentUserId;
  final TextEditingController _commentController = TextEditingController();
  Timer? _mentionDebounce;
  bool _isMentionLoading = false;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  int _mentionRequestId = 0;
  ApiService? _mentionApi;
  Post? _post;
  Comment? _replyingTo; // Pour suivre à quel commentaire on répond

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _commentController.addListener(_onCommentChanged);
    if (_post != null) {
      _loadComments();
    } else {
      _loadPostIfNeeded();
    }
    _loadCurrentUser();
  }

  void _onCommentChanged() {
    final query = _extractMentionQuery(
      _commentController.text,
      _commentController.selection.baseOffset,
    );
    _scheduleMentionSearch(query);
  }

  String? _extractMentionQuery(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    final beforeCursor = text.substring(0, cursor);
    final match = RegExp(
      r'(^|[\s\n])@([A-Za-z0-9_]*)$',
    ).firstMatch(beforeCursor);
    if (match == null) return null;
    final query = match.group(2) ?? '';
    if (query.isEmpty) return null;
    return query;
  }

  void _scheduleMentionSearch(String? query) {
    _mentionDebounce?.cancel();
    if (query == null || query.isEmpty) {
      if (_mentionSuggestions.isNotEmpty || _isMentionLoading) {
        setState(() {
          _mentionSuggestions = [];
          _isMentionLoading = false;
        });
      }
      return;
    }

    _mentionDebounce = Timer(const Duration(milliseconds: 220), () {
      _searchMentionUsers(query);
    });
  }

  Future<void> _searchMentionUsers(String query) async {
    final requestId = ++_mentionRequestId;
    setState(() => _isMentionLoading = true);
    try {
      final api = await ApiService.getInstance();
      _mentionApi = api;
      final data = await api.search(query, type: 'users', page: 1);
      final raw = data['data'] is List
          ? data['data'] as List
          : (data['items'] is List ? data['items'] as List : <dynamic>[]);
      final suggestions = raw
          .whereType<Map>()
          .map((u) => Map<String, dynamic>.from(u))
          .where((u) => (u['username'] ?? '').toString().trim().isNotEmpty)
          .take(6)
          .toList();

      if (!mounted || requestId != _mentionRequestId) return;
      setState(() {
        _mentionSuggestions = suggestions;
        _isMentionLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _mentionRequestId) return;
      setState(() {
        _mentionSuggestions = [];
        _isMentionLoading = false;
      });
    }
  }

  void _insertMention(String username) {
    final value = _commentController.value;
    final cursor = value.selection.baseOffset;
    if (cursor < 0 || cursor > value.text.length) return;

    final beforeCursor = value.text.substring(0, cursor);
    final match = RegExp(
      r'(^|[\s\n])@([A-Za-z0-9_]*)$',
    ).firstMatch(beforeCursor);
    if (match == null) return;

    final prefix = match.group(1) ?? '';
    final start = match.start + prefix.length;
    final replacement = '@$username ';
    final newText = value.text.replaceRange(start, cursor, replacement);
    final newCursor = start + replacement.length;

    _commentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _mentionSuggestions = [];
      _isMentionLoading = false;
    });
  }

  Future<void> _loadPostIfNeeded() async {
    if (widget.postId != null) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
      try {
        final api = await ApiService.getInstance();
        final postData = await api.getPost(widget.postId!);
        if (mounted) {
          setState(() {
            _post = Post.fromJson(postData);
          });
          await _loadComments();
        }
      } catch (e) {
        debugPrint('Error loading post: $e');
        if (mounted) setState(() => _loadError = e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();
      if (mounted) {
        setState(() {
          _currentUserId = profile['id'];
        });
      }
    } catch (_) {}
  }

  /// Recharge les commentaires. [expandThreadOf] déplie le fil qui contient
  /// ce commentaire (celui auquel on vient de répondre).
  Future<void> _loadComments({int? expandThreadOf}) async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final List<dynamic> commentsData = _post!.type == 'group'
          ? await api.getGroupPostComments(_post!.id)
          : await api.getComments(_post!.id);
      final threads = threadsFromTree([
        for (final c in commentsData)
          Comment.fromJson(Map<String, dynamic>.from(c)),
      ]);
      keepTranslations(_threads, threads);
      if (mounted) {
        setState(() {
          _api = api;
          _threads = threads;
          if (expandThreadOf != null) {
            for (final thread in threads) {
              if (thread.contains(expandThreadOf)) {
                _expanded.add(thread.root.id);
              }
            }
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading comments: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(getFriendlyErrorMessage(e, LanguageService.instance)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final replyingToId = _replyingTo?.id;
    try {
      final api = await ApiService.getInstance();
      if (_post!.type == 'group') {
        await api.addGroupComment(
          _post!.id,
          content,
          parentId: _replyingTo?.id,
        );
      } else if (_post!.type == 'page') {
        await api.commentOnPagePost(
          _post!.id,
          content,
          parentId: _replyingTo?.id,
        );
      } else {
        await api.addComment(_post!.id, content, parentId: _replyingTo?.id);
      }
      _commentController.clear();
      setState(() => _replyingTo = null); // Réinitialiser la réponse
      setState(() {
        _mentionSuggestions = [];
        _isMentionLoading = false;
      });

      // Recharger les commentaires ET le post pour mettre à jour le compteur.
      // Le fil auquel on vient de répondre s'ouvre.
      await _loadComments(expandThreadOf: replyingToId);

      // Recharger le post pour avoir le compteur à jour
      if (_post != null) {
        try {
          final postData = await api.getPost(_post!.id);
          if (postData.isNotEmpty && mounted) {
            setState(() {
              _post = Post.fromJson(postData);
            });
          }
        } catch (e) {
          // Si le rechargement échoue, on continue quand même
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance.translate('comment_add_error'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    if (_post == null && _isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(lang.translate('post_detail_title'))),
        body: const AppLoader(),
      );
    }

    if (_post == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(lang.translate('post_detail_title'))),
        body: _loadError != null
            ? ErrorState(error: _loadError, onRetry: _loadPostIfNeeded)
            : EmptyState(
                icon: Icons.article_outlined,
                title: lang.translate('post_not_found'),
              ),
      );
    }

    final textColor = theme.textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(lang.translate('post_detail_title'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                PostCard(post: _post!),
                Divider(color: theme.dividerColor),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    lang.translate('comments_title'),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: AppTokens.fontBodyLarge,
                    ),
                  ),
                ),
                if (_isLoading && _threads.isEmpty)
                  const SkeletonPulse(
                    child: Column(
                      children: [
                        SkeletonListTile(),
                        SkeletonListTile(),
                        SkeletonListTile(),
                      ],
                    ),
                  )
                else if (_threads.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        lang.translate('comments_empty'),
                        style: TextStyle(color: context.tokens.textMuted),
                      ),
                    ),
                  )
                else
                  for (final thread in _threads)
                    CommentThreadView(
                      key: ValueKey(thread.root.id),
                      thread: thread,
                      expanded: _expanded.contains(thread.root.id),
                      onToggleExpanded: () => setState(() {
                        if (!_expanded.remove(thread.root.id)) {
                          _expanded.add(thread.root.id);
                        }
                      }),
                      actions: _commentActions,
                    ),
                const SizedBox(height: AppTokens.space16),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  bool _isMine(Comment comment) =>
      _currentUserId != null && comment.userId == _currentUserId;

  CommentActions get _commentActions => CommentActions(
    avatarUrl: (path) => _api?.getImageUrl(path),
    onLike: _toggleCommentReaction,
    onReply: (comment) => setState(() => _replyingTo = comment),
    onTranslate: _toggleCommentTranslation,
    onEdit: _editComment,
    onDelete: _deleteComment,
    canEdit: _isMine,
    canDelete: _isMine,
  );

  Future<void> _deleteComment(Comment comment) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('delete')),
        content: Text(lang.translate('delete_post_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text(lang.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        if (_post!.type == 'group') {
          await api.deleteGroupComment(comment.id);
        } else if (_post!.type == 'page') {
          await api.deletePageComment(comment.id);
        } else {
          await api.deleteComment(comment.id);
        }
        await _loadComments();
      } catch (e) {
        debugPrint('Error deleting comment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
          );
        }
      }
    }
  }

  Future<void> _editComment(Comment comment) async {
    final lang = LanguageService.instance;
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('edit')),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(lang.translate('save')),
          ),
        ],
      ),
    );

    if (newContent != null &&
        newContent.isNotEmpty &&
        newContent != comment.content) {
      try {
        final api = await ApiService.getInstance();
        if (_post!.type == 'group') {
          await api.updateGroupComment(comment.id, newContent);
        } else if (_post!.type == 'page') {
          await api.updatePageComment(comment.id, newContent);
        } else {
          await api.updateComment(comment.id, newContent);
        }
        await _loadComments();
      } catch (e) {
        debugPrint('Error editing comment: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
          );
        }
      }
    }
  }

  /// Le pouce change tout de suite ; il revient en arrière si l'API refuse.
  /// Sans rechargement, les traductions et les fils dépliés restent en place.
  Future<void> _toggleCommentReaction(Comment comment) async {
    final wasReacted = comment.hasReacted;
    setState(() {
      comment.hasReacted = !wasReacted;
      comment.reactionsCount = (comment.reactionsCount + (wasReacted ? -1 : 1))
          .clamp(0, 1 << 30);
    });
    try {
      final api = await ApiService.getInstance();
      final commentType = switch (_post!.type) {
        'group' => 'group',
        'page' => 'page',
        _ => 'post',
      };
      if (wasReacted) {
        await api.removeCommentReaction(comment.id, commentType);
      } else {
        await api.reactToComment(comment.id, commentType);
      }
    } catch (e) {
      debugPrint('Error toggling comment reaction: $e');
      if (!mounted) return;
      setState(() {
        comment.hasReacted = wasReacted;
        comment.reactionsCount =
            (comment.reactionsCount + (wasReacted ? 1 : -1)).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.instance.translate('reaction_error')),
        ),
      );
    }
  }

  Future<void> _toggleCommentTranslation(Comment comment) async {
    if (comment.isTranslated) {
      setState(() {
        comment.isTranslated = false;
      });
      return;
    }

    if (comment.translatedContent != null) {
      setState(() {
        comment.isTranslated = true;
      });
      return;
    }

    try {
      final api = await ApiService.getInstance();
      final result = await api.translateText(comment.content);

      if (mounted && result['success'] == true) {
        setState(() {
          comment.translatedContent = result['translated'];
          comment.isTranslated = true;
        });
      }
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('error_translation'))),
        );
      }
    }
  }

  Widget _buildCommentInput() {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur de réponse
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: theme.dividerColor.withValues(alpha: 0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang
                          .translate('reply_to')
                          .replaceAll('{username}', _replyingTo!.username),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: AppTokens.fontBodySmall,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: LanguageService.instance.translate('a11y_cancel_reply'),
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    onPressed: () {
                      setState(() {
                        _replyingTo = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Champ de saisie
          if (_isMentionLoading || _mentionSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: _isMentionLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _mentionSuggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (context, index) {
                          final user = _mentionSuggestions[index];
                          final username = (user['username'] ?? '').toString();
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            leading: MentionUserAvatar(
                              user: user,
                              api: _mentionApi!,
                            ),
                            title: Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            onTap: () => _insertMention(username),
                          );
                        },
                      ),
                    ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    hintText: lang.translate('comment_hint'),
                    hintStyle: TextStyle(color: theme.hintColor),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: lang.translate('send'),
                icon: Icon(Icons.send, color: context.colors.primary),
                onPressed: () => _submitComment(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }
}
