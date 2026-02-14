import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../widgets/post_card.dart';

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
  Post? _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    if (_post != null) {
      _loadComments();
    } else {
      _loadPostIfNeeded();
    }
    _loadCurrentUser();
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
      } else {
        commentsData = await api.getComments(_post!.id);
      }
      setState(() {
        _comments.clear();
        _comments.addAll(commentsData.map((c) => Comment.fromJson(c)).toList());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final api = await ApiService.getInstance();
      if (_post!.type == 'group') {
        await api.addGroupComment(_post!.id, content);
      } else {
        await api.addComment(_post!.id, content);
      }
      _commentController.clear();
      _loadComments();
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
                  ..._comments.map((comment) => _buildCommentItem(comment)),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFBE1E1E),
            child: Text(
              comment.username.isNotEmpty
                  ? comment.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
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
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Modifier'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer ce commentaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        if (_post!.type == 'group') {
          await api.deleteGroupComment(comment.id);
        } else {
          // TODO: implement standard delete comment
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suppression non supportée pour ce type'),
            ),
          );
          return;
        }
        _loadComments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _editComment(Comment comment) async {
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enregistrer'),
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
        } else {
          // TODO: standard update
          return;
        }
        _loadComments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
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
      child: Row(
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
    );
  }
}
