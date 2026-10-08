import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';
import '../theme/theme_context.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class GroupInviteScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupInviteScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<dynamic> _users = [];
  bool _isLoading = false;
  String _query = '';
  Object? _error;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    _api = await ApiService.getInstance();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _users.clear();
        _query = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _query = query;
    });

    try {
      _api ??= await ApiService.getInstance();
      final result = await _api!.search(query, type: 'users');
      final users = result['data'] ?? result['users'] ?? result['items'] ?? [];
      if (!mounted) return;
      setState(() {
        _users.clear();
        _users.addAll(users);
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteUser(int userId, String username) async {
    final lang = LanguageService.instance;
    try {
      _api ??= await ApiService.getInstance();
      await _api!.inviteToGroup(widget.groupId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.translate('invitation_sent_to')} $username'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.translate('invite_to_group')),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _searchUsers(val),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: lang.translate('search_users'),
                prefixIcon: Icon(Icons.search, color: context.colors.primary),
                filled: true,
                fillColor: context.colors.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const SkeletonList()
                : _error != null
                ? ErrorState(
                    error: _error,
                    onRetry: () => _searchUsers(_query),
                  )
                : _users.isEmpty && _query.isNotEmpty
                ? EmptyState(
                    icon: Icons.person_search_outlined,
                    title: lang.translate('no_users_found'),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final username = user['username'] ?? '';

                      return ListTile(
                        onTap: () {
                          final userId = user['id'] is int
                              ? user['id']
                              : int.tryParse(user['id']?.toString() ?? '');
                          if (userId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(userId: userId),
                              ),
                            );
                          }
                        },
                        leading: _buildUserAvatar(user),
                        title: Text(
                          username,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          user['bio'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.tokens.textMuted,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _inviteUser(user['id'], username),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            foregroundColor: context.colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(lang.translate('invite')),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(dynamic user) {
    final avatar = user['avatar']?.toString();
    return AppAvatar(
      url: avatar == null ? null : _api?.getImageUrl(avatar),
      semanticLabel: user['username']?.toString(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
