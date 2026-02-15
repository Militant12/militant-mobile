import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class UsersListScreen extends StatefulWidget {
  final int? userId;
  final String title;
  final String type; // 'followers' or 'following'
  final bool showAppBar;

  const UsersListScreen({
    super.key,
    this.userId,
    required this.title,
    required this.type,
    this.showAppBar = true,
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
        _hasMore) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      List<dynamic> users;

      if (widget.type == 'friends') {
        final result = await api.getFriends(type: 'friends', page: _page);
        users = result['friends'] ?? result['data'] ?? [];
      } else {
        users = await api.getFollows(
          userId: widget.userId,
          type: widget.type,
          page: _page,
        );
      }

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title),
              backgroundColor: theme.appBarTheme.backgroundColor,
            )
          : null,
      body: _users.isEmpty && _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun utilisateur trouvé',
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFBE1E1E),
                      ),
                    ),
                  );
                }

                final user = _users[index];
                final api = ApiService(
                  baseUrl: '',
                ); // Used only for getImageUrl

                return ListTile(
                  leading: GestureDetector(
                    onTap: () => _navigateToProfile(user['id']),
                    child: Stack(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child:
                                (user['avatar'] != null &&
                                    api.getImageUrl(user['avatar']) != null)
                                ? Image.network(
                                    api.getImageUrl(user['avatar'])!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: SvgPicture.asset(
                                          'assets/logo.svg',
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    },
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(0.0),
                                    child: SvgPicture.asset(
                                      'assets/logo.svg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                        if (user['is_online'] == 1 || user['is_online'] == true)
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
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  title: Text(
                    user['username'] ?? 'Utilisateur',
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    user['bio'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                  onTap: () => _navigateToProfile(user['id']),
                  trailing: widget.type == 'friends'
                      ? IconButton(
                          icon: const Icon(
                            Icons.message,
                            color: Color(0xFFBE1E1E),
                          ),
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
                        )
                      : null,
                );
              },
            ),
    );
  }

  void _navigateToProfile(int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
