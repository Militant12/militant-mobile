import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

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
      _query = query;
    });

    try {
      _api ??= await ApiService.getInstance();
      final result = await _api!.search(query, type: 'users');
      final users = result['data'] ?? result['users'] ?? result['items'] ?? [];
      setState(() {
        _users.clear();
        _users.addAll(users);
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
    } finally {
      setState(() => _isLoading = false);
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
            content: Text(
              '${lang.translate('invitation_sent_to')} $username',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                prefixIcon: const Icon(Icons.search, color: Color(0xFFBE1E1E)),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  )
                : _users.isEmpty && _query.isNotEmpty
                    ? Center(child: Text(lang.translate('no_users_found')))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          final avatar = user['avatar'];
                          final username = user['username'] ?? '';

                          return ListTile(
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
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _inviteUser(user['id'], username),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBE1E1E),
                                foregroundColor: Colors.white,
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
    final avatarUrl = avatar == null ? null : _api?.getImageUrl(avatar);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      if (avatarUrl.endsWith('.svg')) {
        return CircleAvatar(
          backgroundColor: Colors.white,
          child: ClipOval(
            child: SvgPicture.network(
              avatarUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: Colors.white,
      );
    }

    return CircleAvatar(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.contain),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
