import 'package:flutter/material.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/post_card.dart';
import '../widgets/linkable_text.dart';

class PostDetailScreen extends StatefulWidget {
  final Post? post;
  final int? postId;

  const PostDetailScreen({super.key, this.post, this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final List<Comment> _comments = [];
  bool _isLoading = false;
  int? _currentUserId;
  final TextEditingController _commentController = TextEditingController();
  Timer? _mentionDebounce;
  bool _isMentionLoading = false;
  List<Map<String, dynamic>> _mentionSuggestions = [];
  int _mentionRequestId = 0;
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
    final match = RegExp(r'(^|[\s\n])@([A-Za-z0-9_]*)$').firstMatch(beforeCursor);
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
    final match = RegExp(r'(^|[\s\n])@([A-Za-z0-9_]*)$').firstMatch(beforeCursor);
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
      setState(() => _isLoading = true);
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

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      List<dynamic> commentsData;
      if (_post!.type == 'group') {
        commentsData = await api.getGroupPostComments(_post!.id);
        debugPrint('Group comments loaded: ${commentsData.length} root comments');
      } else {
        commentsData = await api.getComments(_post!.id);
        debugPrint('Comments loaded: ${commentsData.length} root comments');
      }
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(commentsData.map((c) {
            try {
              return Comment.fromJson(c);
            } catch (e) {
              debugPrint('Error parsing comment: $e');
              debugPrint('Comment data: $c');
              rethrow;
            }
          }).toList());
          debugPrint('Total comments in list: ${_comments.length}');
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading comments: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
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

    try {
      final api = await ApiService.getInstance();
      if (_post!.type == 'group') {
        await api.addGroupComment(_post!.id, content, parentId: _replyingTo?.id);
      } else if (_post!.type == 'page') {
        await api.commentOnPagePost(_post!.id, content);
      } else {
        await api.addComment(_post!.id, content, parentId: _replyingTo?.id);
      }
      _commentController.clear();
      setState(() => _replyingTo = null); // Réinitialiser la réponse
      setState(() {
        _mentionSuggestions = [];
        _isMentionLoading = false;
      });
      
      // Recharger les commentaires ET le post pour mettre à jour le compteur
      await _loadComments();
      
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
          SnackBar(content: Text('Impossible d\'ajouter le commentaire')),
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
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    if (_post == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text(lang.translate('post_detail_title'))),
        body: const Center(child: Text('Post introuvable')),
      );
    }

    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

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
                      fontSize: 18,
                    ),
                  ),
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  )
                else if (_comments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'Aucun commentaire',
                        style: TextStyle(color: subtitleColor),
                      ),
                    ),
                  )
                else
                  ..._comments.map((comment) => _buildCommentItem(comment, depth: 0)),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, {int depth = 0}) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;
    final maxDepth = 3; // Limite de profondeur pour l'indentation

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: depth > 0 ? (depth * 24.0).clamp(0, maxDepth * 24.0) : 16,
            right: 16,
            top: 8,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<ApiService>(
                future: ApiService.getInstance(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFBE1E1E),
                      child: Text(
                        comment.username.isNotEmpty
                            ? comment.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  }

                  final avatarUrl = snapshot.data!.getImageUrl(comment.userAvatar);
                  
                  if (avatarUrl != null && avatarUrl.isNotEmpty) {
                    return CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(avatarUrl),
                      backgroundColor: const Color(0xFFBE1E1E),
                      onBackgroundImageError: (_, __) {},
                      child: null,
                    );
                  }

                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFBE1E1E),
                    child: Text(
                      comment.username.isNotEmpty
                          ? comment.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(comment.createdAt),
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                        ),
                        const Spacer(),
                        if (_currentUserId != null &&
                            comment.userId == _currentUserId)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz,
                              size: 16,
                              color: subtitleColor,
                            ),
                            onSelected: (value) async {
                              if (value == 'delete') {
                                _deleteComment(comment);
                              } else if (value == 'edit') {
                                _editComment(comment);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(lang.translate('edit')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(lang.translate('delete')),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinkableText(
                      text: comment.content,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    // Boutons Répondre et Réaction
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _replyingTo = comment;
                            });
                          },
                          icon: Icon(Icons.reply, size: 14, color: subtitleColor),
                          label: Text(
                            lang.translate('reply'),
                            style: TextStyle(color: subtitleColor, fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bouton de réaction (pouce)
                        TextButton.icon(
                          onPressed: () => _toggleCommentReaction(comment),
                          icon: Icon(
                            Icons.thumb_up,
                            size: 14,
                            color: comment.hasReacted ? const Color(0xFFBE1E1E) : subtitleColor,
                          ),
                          label: Text(
                            comment.reactionsCount > 0 ? '${comment.reactionsCount}' : '',
                            style: TextStyle(
                              color: comment.hasReacted ? const Color(0xFFBE1E1E) : subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Afficher les réponses de manière récursive
        if (comment.replies.isNotEmpty)
          ...comment.replies.map((reply) => _buildCommentItem(reply, depth: depth + 1)),
      ],
    );
  }

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
            child: Text(lang.translate('delete'), style: const TextStyle(color: Colors.red)),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _toggleCommentReaction(Comment comment) async {
    try {
      final api = await ApiService.getInstance();
      String commentType = 'post';
      if (_post!.type == 'group') {
        commentType = 'group';
      } else if (_post!.type == 'page') {
        commentType = 'page';
      }

      if (comment.hasReacted) {
        await api.removeCommentReaction(comment.id, commentType);
      } else {
        await api.reactToComment(comment.id, commentType);
      }

      // Recharger les commentaires pour mettre à jour l'état
      await _loadComments();
    } catch (e) {
      debugPrint('Error toggling comment reaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la réaction')),
        );
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
              color: theme.dividerColor.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: theme.textTheme.bodyMedium?.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.translate('reply_to').replaceAll('{username}', _replyingTo!.username),
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: theme.textTheme.bodyMedium?.color),
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
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: theme.dividerColor,
                        ),
                        itemBuilder: (context, index) {
                          final user = _mentionSuggestions[index];
                          final username = (user['username'] ?? '').toString();
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            leading: const CircleAvatar(
                              radius: 14,
                              child: Icon(Icons.person, size: 14),
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
                icon: const Icon(Icons.send, color: Color(0xFFBE1E1E)),
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
