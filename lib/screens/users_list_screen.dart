import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/theme_context.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import '../widgets/militant_badge.dart';
import '../widgets/technician_badge.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class UsersListScreen extends StatefulWidget {
  final int? userId;
  final int? groupId;
  final String title;
  final String type; // 'followers', 'following', 'members', 'friends'
  final bool showAppBar;
  final bool isCurrentUserAdmin;

  const UsersListScreen({
    super.key,
    this.userId,
    this.groupId,
    required this.title,
    required this.type,
    this.showAppBar = true,
    this.isCurrentUserAdmin = false,
  });

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final List<dynamic> _users = [];
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  ApiService? _api;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _error == null &&
        _hasMore) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _api ??= await ApiService.getInstance();
      List<dynamic> users;

      if (widget.type == 'friends') {
        final result = await _api!.getFriends(type: 'friends', page: _page);
        users = result['friends'] ?? result['data'] ?? [];
      } else if (widget.type == 'members' && widget.groupId != null) {
        users = await _api!.getGroupMembers(widget.groupId!, page: _page);
      } else {
        users = await _api!.getFollows(
          userId: widget.userId,
          type: widget.type,
          page: _page,
        );
      }

      if (!mounted) return;
      setState(() {
        if (users.isEmpty) {
          _hasMore = false;
        } else {
          _users.addAll(users);
          _page++;
          if (users.length < 20) _hasMore = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title),
              backgroundColor: theme.appBarTheme.backgroundColor,
            )
          : null,
      body: _users.isEmpty && _isLoading
          ? const SkeletonList()
          : _users.isEmpty && _error != null
          ? ErrorState(error: _error, onRetry: _loadUsers)
          : _users.isEmpty
          ? EmptyState(
              icon: Icons.people_outline,
              title: lang.translate('users_list_empty'),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  if (_error != null) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: Text(lang.translate('retry')),
                      ),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppLoader(size: 28),
                  );
                }

                final user = _users[index];
                final bool isMembersView = widget.type == 'members';
                final bool isAdmin = user['role'] == 'admin';

                return ListTile(
                  leading: GestureDetector(
                    onTap: () => _navigateToProfile(user['id']),
                    child: AppAvatar(
                      url: _api?.getImageUrl(user['avatar']),
                      semanticLabel: user['username']?.toString(),
                      online: user['is_online'] == 1 || user['is_online'] == true,
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['username'] ?? lang.translate('user'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (user['militant_badge'] != null) ...[
                        const SizedBox(width: 4),
                        MilitantBadge(badgeId: user['militant_badge'], size: 16),
                      ],
                      if (user['is_militant_technician'] == true ||
                          user['is_militant_technician'] == 1 ||
                          user['is_militant_technician'] == '1') ...[
                        const SizedBox(width: 4),
                        const TechnicianBadge(size: 16),
                      ],
                      if (user['is_moderator'] == true ||
                          user['is_moderator'] == 1 ||
                          user['is_moderator'] == '1') ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: lang.translate('post_elected_moderator'),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.shield,
                              size: 14,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                      ],
                      // Role badge (only in members view)
                      if (isMembersView) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? context.colors.primary
                                : Colors.grey[600],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isAdmin
                                ? lang.translate('admin_badge')
                                : lang.translate('member_badge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    user['bio'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.tokens.textMuted),
                  ),
                  onTap: () => _navigateToProfile(user['id']),
                  trailing: _buildTrailing(context, user, isMembersView, isAdmin, lang),
                );
              },
            ),
    );
  }

  Widget? _buildTrailing(
    BuildContext context,
    dynamic user,
    bool isMembersView,
    bool isAdmin,
    LanguageService lang,
  ) {
    // Friends view → chat button
    if (widget.type == 'friends') {
      return IconButton(
        tooltip: lang.translate('action_messages'),
        icon: Icon(Icons.message, color: context.colors.primary),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userId: user['id'],
                username: user['username'],
                avatar: user['avatar'],
              ),
            ),
          );
        },
      );
    }

    // Members view + current user is admin → contextual menu
    if (isMembersView && widget.isCurrentUserAdmin && widget.groupId != null) {
      final username = user['username'] ?? '';
      final memberId = user['id'] is int
          ? user['id']
          : int.tryParse(user['id']?.toString() ?? '');

      if (memberId == null) return null;

      return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: context.tokens.textMuted),
        tooltip: lang.translate('action_more_options'),
        onSelected: (value) {
          switch (value) {
            case 'promote':
              _promoteMember(widget.groupId!, memberId, username);
              break;
            case 'demote':
              _demoteMember(widget.groupId!, memberId, username);
              break;
            case 'kick':
              _kickMember(widget.groupId!, memberId, username);
              break;
          }
        },
        itemBuilder: (context) => [
          if (!isAdmin)
            PopupMenuItem(
              value: 'promote',
              child: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: context.colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(lang.translate('promote_to_admin')),
                ],
              ),
            ),
          if (isAdmin)
            PopupMenuItem(
              value: 'demote',
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_downward,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(lang.translate('demote_to_editor')),
                ],
              ),
            ),
          PopupMenuItem(
            value: 'kick',
            child: Row(
              children: [
                Icon(
                  Icons.person_remove,
                  color: context.colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  lang.translate('remove_member'),
                  style: TextStyle(color: context.colors.primary),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return null;
  }

  Future<void> _promoteMember(
    int groupId,
    int memberId,
    String username,
  ) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.translate('promote_to_admin')),
        content: Text(
          lang
              .translate('promote_to_admin_question')
              .replaceAll('{username}', username),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.translate('promote_to_admin'),
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.promoteSocialGroupMember(groupId, memberId);
      // Update local state
      setState(() {
        final idx = _users.indexWhere(
          (u) => (u['id'] is int ? u['id'] : int.tryParse(u['id']?.toString() ?? '')) == memberId,
        );
        if (idx != -1) _users[idx] = {..._users[idx], 'role': 'admin'};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang
                  .translate('group_promote_success')
                  .replaceAll('{username}', username),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  Future<void> _demoteMember(
    int groupId,
    int memberId,
    String username,
  ) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang
              .translate('group_demote_question')
              .replaceAll('{username}', username),
        ),
        content: Text(
          lang
              .translate('group_demote_confirm')
              .replaceAll('{username}', username),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.translate('demote_to_editor'),
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.demoteSocialGroupMember(groupId, memberId);
      // Update local state
      setState(() {
        final idx = _users.indexWhere(
          (u) => (u['id'] is int ? u['id'] : int.tryParse(u['id']?.toString() ?? '')) == memberId,
        );
        if (idx != -1) _users[idx] = {..._users[idx], 'role': 'member'};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang
                  .translate('group_demote_success')
                  .replaceAll('{username}', username),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  Future<void> _kickMember(
    int groupId,
    int memberId,
    String username,
  ) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          lang
              .translate('group_kick_question')
              .replaceAll('{username}', username),
        ),
        content: Text(
          lang
              .translate('group_kick_confirm')
              .replaceAll('{username}', username),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              lang.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.kickSocialGroupMember(groupId, memberId);
      // Update local state
      setState(() {
        _users.removeWhere(
          (u) => (u['id'] is int ? u['id'] : int.tryParse(u['id']?.toString() ?? '')) == memberId,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang
                  .translate('group_kick_success')
                  .replaceAll('{username}', username),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e, lang))));
      }
    }
  }

  void _navigateToProfile(dynamic userId) {
    final id = userId is int ? userId : int.tryParse(userId?.toString() ?? '');
    if (id == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
