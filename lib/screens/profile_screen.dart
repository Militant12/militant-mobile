import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/profile_stories.dart';
import '../widgets/militant_badge.dart';
import '../widgets/technician_badge.dart';
import '../widgets/status_picker.dart';
import '../services/user_status_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'users_list_screen.dart';
import 'friends_screen.dart';
import '../services/language_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/linkable_text.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  final List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  late TabController _tabController;
  int _selectedTab = 0;
  bool _isFollowing = false;
  bool _isMe = false;
  bool _isFriend = false;
  int? _sentRequestId;
  int? _receivedRequestId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _safeSetState(() => _selectedTab = _tabController.index);
    });
    _loadProfile();
  }

  String? _avatarUrl;

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Public method to refresh profile from outside
  void refreshProfile() {
    if (mounted) {
      _loadProfile();
    }
  }

  Future<void> _reloadProfileIfMounted() async {
    if (!mounted) return;
    await _loadProfile();
    _safeSetState(() {});
  }

  Future<void> _loadProfile() async {
    final lang = LanguageService.instance;
    _safeSetState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final myProfile = await api.getProfile();

      final profile = await api.getProfile(userId: widget.userId);

      _safeSetState(() {
        _profile = profile;
        _isMe = widget.userId == null || widget.userId == myProfile['id'];
        _isFollowing =
            profile['is_following'] == 1 || profile['is_following'] == true;
        _isFriend = profile['is_friend'] == 1 || profile['is_friend'] == true;
        _sentRequestId = profile['sent_request_id'];
        _receivedRequestId = profile['received_request_id'];
        // Add timestamp to force image reload and bypass cache
        final avatarUrl = api.getImageUrl(profile['avatar']);
        _avatarUrl = avatarUrl != null
            ? '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}'
            : null;
      });

      // Load posts if allowed
      final isPrivate =
          profile['is_private'] == 1 || profile['is_private'] == true;
      if (!isPrivate || _isMe || _isFollowing) {
        _loadUserPosts(profile['id'] ?? profile['user_id']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserPosts(int userId) async {
    final lang = LanguageService.instance;
    _safeSetState(() => _isLoadingPosts = true);
    try {
      final api = await ApiService.getInstance();

      // Load ALL pages of posts
      List<dynamic> allPosts = [];
      int page = 1;

      do {
        final postsData = await api.getUserPosts(userId, page: page);
        allPosts.addAll(postsData);

        if (postsData.length < 20) {
          break; // No more pages
        }
        page++;
      } while (page <= 50); // Safety limit

      _safeSetState(() {
        _posts.clear();
        _posts.addAll(allPosts.map((p) => Post.fromJson(p)).toList());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      _safeSetState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final lang = LanguageService.instance;
    if (_profile == null || _isMe) return;
    try {
      final api = await ApiService.getInstance();
      final result = await api.sendFriendRequest(
        widget.userId ?? _profile!['id'],
      );
      _safeSetState(() => _sentRequestId = result['request_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('friend_request_sent'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest() async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      if (_receivedRequestId != null) {
        await api.handleFriendRequest(_receivedRequestId!, 'accept');
        _safeSetState(() {
          _isFriend = true;
          _receivedRequestId = null;
        });
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _unfriend() async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('remove_from_friends'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('remove_friend_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('remove'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        await api.unfriend(widget.userId ?? _profile!['id']);
        _safeSetState(() => _isFriend = false);
        _loadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${lang.translate('error_generic')}: ${e.toString()}',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectFriendRequest() async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      if (_receivedRequestId != null) {
        await api.handleFriendRequest(_receivedRequestId!, 'reject');
        _safeSetState(() {
          _receivedRequestId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final lang = LanguageService.instance;
    if (_profile == null || _isMe) return;

    try {
      final api = await ApiService.getInstance();
      if (_isFollowing) {
        await api.unfollowUser(widget.userId ?? _profile!['id']);
        _safeSetState(() {
          _isFollowing = false;
          _profile!['followers_count'] =
              (_profile!['followers_count'] ?? 1) - 1;
        });
      } else {
        await api.followUser(widget.userId ?? _profile!['id']);
        _safeSetState(() {
          _isFollowing = true;
          _profile!['followers_count'] =
              (_profile!['followers_count'] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_generic')}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('logout_question'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('logout_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Déconnexion',
              style: TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final api = await ApiService.getInstance();
      await api.clearToken();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color;
    final subtitleColor = theme.textTheme.bodyMedium?.color;

    final username = _profile?['username'] ?? 'Utilisateur';

    // ... (avatar logic unchanged) ...

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          lang.translate('profile_title'),
          style: TextStyle(color: theme.textTheme.titleLarge?.color),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: theme.iconTheme.color),
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        children: [
          // En-tête (unchanged until stats)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                _avatarUrl != null
                    ? CircleAvatar(
                        radius: 50,
                        backgroundColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey[200],
                        backgroundImage: NetworkImage(_avatarUrl!),
                        onBackgroundImageError: (_, __) {},
                        child: _avatarUrl == null
                            ? Padding(
                                padding: const EdgeInsets.all(0.0),
                                child: SvgPicture.asset('assets/logo.svg'),
                              )
                            : null,
                      )
                    : CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: SvgPicture.asset('assets/logo.svg'),
                        ),
                      ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_profile?['militant_badge'] != null) ...[
                      const SizedBox(width: 8),
                      MilitantBadge(
                        badgeId: _profile!['militant_badge'],
                        size: 28,
                      ),
                    ],
                    // Badge technicien
                    if (_profile?['is_militant_technician'] == true ||
                        _profile?['is_militant_technician'] == 1 ||
                        _profile?['is_militant_technician'] == '1') ...[
                      const SizedBox(width: 6),
                      const TechnicianBadge(size: 26),
                    ],
                    if (_profile?['is_private'] == 1 ||
                        _profile?['is_private'] == true) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.lock,
                        size: 20,
                        color: Color(0xFFBE1E1E),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_profile?['is_online'] == 1 ||
                        _profile?['is_online'] == true) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang.translate('online'),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else if (_profile?['last_active'] != null) ...[
                      Text(
                        'Dernière activité: ${_profile!['last_active']}', // TODO: Format date
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // === STATUT PERSONNALISÉ ===
                if (_isMe)
                  ValueListenableBuilder<UserStatus>(
                    valueListenable: UserStatusService.instance,
                    builder: (context, status, _) => StatusChip(
                      status: status,
                      onTap: () async {
                        final api = await ApiService.getInstance();
                        if (context.mounted) {
                          await StatusPickerDialog.show(context, api);
                        }
                      },
                    ),
                  )
                else
                  UserStatusBadge(
                    statusEmoji: _profile?['status_emoji'] as String?,
                    statusText: _profile?['status_text'] as String?,
                  ),
                const SizedBox(height: 12),
                _buildSocialRow(),
                if (_profile?['email'] != null &&
                    _profile!['email'].isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _profile!['email'],
                    style: TextStyle(color: subtitleColor, fontSize: 14),
                  ),
                ],
                if (_profile?['bio'] != null &&
                    _profile!['bio'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  LinkableText(
                    text: _profile!['bio'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor?.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Statistiques
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStat(
                  lang.translate('posts'),
                  _profile?['posts_count']?.toString() ?? '0',
                ),
                _buildStat(
                  lang.translate('followers'),
                  _profile?['followers_count']?.toString() ?? '0',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UsersListScreen(
                          userId: widget.userId ?? _profile!['id'],
                          title: lang.translate('followers'),
                          type: 'followers',
                        ),
                      ),
                    );
                  },
                ),
                _buildStat(
                  lang.translate('following'),
                  _profile?['following_count']?.toString() ?? '0',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UsersListScreen(
                          userId: widget.userId ?? _profile!['id'],
                          title: lang.translate('following'),
                          type: 'following',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Options (Only if Me)
          if (_isMe) ...[
            _buildOption(
              icon: Icons.edit,
              title: lang.translate('edit_profile_title'),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
                if (result == true && mounted) {
                  await _reloadProfileIfMounted();
                }
              },
            ),
            _buildOption(
              icon: Icons.settings,
              title: lang.translate('settings_title'),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                // Refresh profile after returning from settings
                if (mounted) {
                  await _reloadProfileIfMounted();
                }
              },
            ),
            _buildOption(
              icon: Icons.people,
              title: lang.translate('friends_title'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FriendsScreen(userId: widget.userId ?? _profile!['id']),
                  ),
                );
              },
            ),
            _buildOption(
              icon: Icons.bookmark,
              title: lang.translate('saved_posts_title'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (_isFriend)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _unfriend,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.grey[200],
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 20,
                                  color: theme.iconTheme.color,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang.translate('friends'),
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    userId: widget.userId ?? _profile!['id'],
                                    username: _profile!['username'],
                                    avatar: _profile!['avatar'],
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBE1E1E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.message,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang.translate('message'),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (_sentRequestId != null)
                    ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey[200],
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: Text(lang.translate('friend_request_sent')),
                    )
                  else if (_receivedRequestId != null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _acceptFriendRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBE1E1E),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: Text(lang.translate('accept')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _rejectFriendRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF2A2A2A)
                                  : Colors.grey[200],
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: Text(
                              lang.translate('decline'),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _sendFriendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBE1E1E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: Text(lang.translate('add_friend')),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing
                          ? (isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey[200])
                          : Colors.transparent,
                      side: _isFollowing
                          ? null
                          : const BorderSide(color: Color(0xFFBE1E1E)),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                    child: Text(
                      _isFollowing
                          ? lang.translate('following_status')
                          : lang.translate('follow'),
                      style: TextStyle(
                        color: _isFollowing
                            ? textColor
                            : const Color(0xFFBE1E1E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Check for Private access
          if ((_profile?['is_private'] == 1 ||
                  _profile?['is_private'] == true) &&
              !_isMe &&
              !_isFollowing &&
              !_isFriend) ...[
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    lang.translate('private_account_title'),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.translate('private_account_subtitle'),
                    style: TextStyle(color: subtitleColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Stories
            if (_profile != null)
              ProfileStories(
                userId: _profile!['id'] ?? _profile!['user_id'],
                isMe: _isMe,
              ),

            // Onglets
            Container(
              color: theme.cardColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFBE1E1E),
                labelColor: const Color(0xFFBE1E1E),
                unselectedLabelColor: subtitleColor,
                tabs: [
                  Tab(text: '${lang.translate('posts')} (${_posts.length})'),
                  Tab(text: lang.translate('media')),
                ],
              ),
            ),

            // Render Selected Tab Content
            if (_selectedTab == 0) ...[
              // Posts
              if (_isLoadingPosts)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  ),
                )
              else if (_posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      lang.translate('no_posts'),
                      style: TextStyle(color: subtitleColor),
                    ),
                  ),
                )
              else
                ...List.generate(_posts.length, (index) {
                  return PostCard(
                    post: _posts[index],
                    onDeleted: () {
                      _safeSetState(() => _posts.removeAt(index));
                    },
                  );
                }),
            ] else ...[
              // Médias content
              if (_isLoadingPosts)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  ),
                )
              else
                _buildMediaGrid(),
            ],
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildMediaGrid() {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final postsWithMedia = _posts.where((p) => p.mediaUrls.isNotEmpty).toList();

    if (postsWithMedia.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 64, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text(
                lang.translate('no_media'),
                style: TextStyle(color: theme.disabledColor),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<ApiService>(
      future: ApiService.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
          );
        }
        final api = snapshot.data!;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: postsWithMedia.length,
          itemBuilder: (context, index) {
            final post = postsWithMedia[index];
            final rawMedia = post.mediaUrls.isNotEmpty
                ? post.mediaUrls[0]
                : null;
            final imageUrl = rawMedia != null
                ? api.getImageUrl(rawMedia)
                : null;

            final isVideo =
                rawMedia != null &&
                (rawMedia.endsWith('.mp4') ||
                    rawMedia.endsWith('.webm') ||
                    rawMedia.endsWith('.mov') ||
                    rawMedia.endsWith('.avi'));

            return GestureDetector(
              onTap: () {
                // TODO: Navigate to post detail
              },
              child: Container(
                color: theme.cardColor,
                child: imageUrl != null
                    ? isVideo
                          ? const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFFBE1E1E),
                                size: 40,
                              ),
                            )
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFBE1E1E),
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.broken_image,
                                  color: theme.disabledColor,
                                );
                              },
                            )
                    : Icon(Icons.image, color: theme.disabledColor),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSocialRow() {
    final lang = LanguageService.instance;
    if (_profile == null) return const SizedBox.shrink();

    final socials = [
      {
        'key': 'website',
        'icon': Icons.link,
        'url': '\$value',
      },
      {
        'key': 'mastodon',
        'icon': Icons.alternate_email,
        'url': 'https://\$value',
      },
      {
        'key': 'bluesky',
        'icon': Icons.cloud,
        'url': 'https://bsky.app/profile/\$value',
      },
      {
        'key': 'twitter',
        'icon': Icons.chat_bubble_outline,
        'url': 'https://twitter.com/\$value',
      },
      {
        'key': 'instagram',
        'icon': Icons.camera_alt_outlined,
        'url': 'https://instagram.com/\$value',
      },
      {
        'key': 'facebook',
        'icon': Icons.facebook,
        'url': 'https://facebook.com/\$value',
      },
      {
        'key': 'tiktok',
        'icon': Icons.music_note,
        'url': 'https://tiktok.com/@\$value',
      },
    ];

    List<Widget> icons = [];
    for (var social in socials) {
      final value = _profile![social['key'] as String];
      if (value != null && value.toString().isNotEmpty) {
        icons.add(
          IconButton(
            icon: Icon(social['icon'] as IconData, size: 24),
            color: const Color(0xFFBE1E1E),
            onPressed: () async {
              try {
                final urlTemplate = social['url'] as String;
                final urlString = value.toString().startsWith('http')
                    ? value.toString()
                    : urlTemplate.replaceAll('\$value', value.toString());
                final url = Uri.parse(urlString);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${lang.translate('cannot_open_url')}: $urlString',
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${lang.translate('error_generic')}: ${e.toString()}',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        );
      }
    }

    if (icons.isEmpty) return const SizedBox.shrink();

    return Wrap(alignment: WrapAlignment.center, spacing: 8, children: icons);
  }

  Widget _buildStat(String label, String value, [VoidCallback? onTap]) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBE1E1E)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.iconTheme.color?.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
