import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/profile_stories.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import 'users_list_screen.dart';
import '../services/language_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  final List<Post> _posts = [];
  bool _isLoading = true;
  bool _isLoadingPosts = false;
  late TabController _tabController;
  int _selectedTab = 0;
  bool _isFollowing = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });
    _loadProfile();
  }

  String? _avatarUrl;

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final myProfile = await api.getProfile();

      final profile = await api.getProfile(userId: widget.userId);

      setState(() {
        _profile = profile;
        _isMe = widget.userId == null || widget.userId == myProfile['id'];
        _isFollowing =
            profile['is_following'] == 1 || profile['is_following'] == true;
        _avatarUrl = api.getImageUrl(profile['avatar']);
      });

      // Load posts if allowed
      final isPrivate =
          profile['is_private'] == 1 || profile['is_private'] == true;
      if (!isPrivate || _isMe || _isFollowing) {
        _loadUserPosts(profile['id'] ?? profile['user_id']);
      }
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

  Future<void> _loadUserPosts(int userId) async {
    setState(() => _isLoadingPosts = true);
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

      setState(() {
        _posts.clear();
        _posts.addAll(allPosts.map((p) => Post.fromJson(p)).toList());
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null || _isMe) return;

    try {
      final api = await ApiService.getInstance();
      if (_isFollowing) {
        await api.unfollowUser(widget.userId ?? _profile!['id']);
        setState(() {
          _isFollowing = false;
          _profile!['followers_count'] =
              (_profile!['followers_count'] ?? 1) - 1;
        });
      } else {
        await api.followUser(widget.userId ?? _profile!['id']);
        setState(() {
          _isFollowing = true;
          _profile!['followers_count'] =
              (_profile!['followers_count'] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
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
                const SizedBox(height: 16),
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
                  Text(
                    _profile!['bio'],
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ).then((_) => _loadProfile());
              },
            ),
            _buildOption(
              icon: Icons.settings,
              title: lang.translate('settings_title'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
            // Follow button could go here
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? Colors.grey
                      : const Color(0xFFBE1E1E),
                ),
                child: Text(
                  _isFollowing
                      ? lang.translate('following_status')
                      : lang.translate('follow'),
                ),
              ),
            ),
          ],

          // Check for Private access
          if ((_profile?['is_private'] == 1 ||
                  _profile?['is_private'] == true) &&
              !_isMe &&
              !_isFollowing) ...[
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
                      setState(() => _posts.removeAt(index));
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
    if (_profile == null) return const SizedBox.shrink();

    final socials = [
      {
        'key': 'mastodon',
        'icon': Icons.alternate_email,
        'url': (v) => v.startsWith('http') ? v : 'https://$v',
      },
      {
        'key': 'github',
        'icon': Icons.code,
        'url': (v) => v.startsWith('http') ? v : 'https://github.com/$v',
      },
      {
        'key': 'twitter',
        'icon': Icons.chat_bubble_outline,
        'url': (v) => v.startsWith('http') ? v : 'https://twitter.com/$v',
      },
      {
        'key': 'instagram',
        'icon': Icons.camera_alt_outlined,
        'url': (v) => v.startsWith('http') ? v : 'https://instagram.com/$v',
      },
      {
        'key': 'facebook',
        'icon': Icons.facebook,
        'url': (v) => v.startsWith('http') ? v : 'https://facebook.com/$v',
      },
      {
        'key': 'tiktok',
        'icon': Icons.music_note,
        'url': (v) => v.startsWith('http') ? v : 'https://tiktok.com/@$v',
      },
    ];

    List<Widget> icons = [];
    for (var social in socials) {
      final value = _profile![social['key']];
      if (value != null && value.toString().isNotEmpty) {
        icons.add(
          IconButton(
            icon: Icon(social['icon'] as IconData, size: 24),
            color: const Color(0xFFBE1E1E),
            onPressed: () async {
              final urlString = (social['url'] as String Function(String))(
                value.toString(),
              );
              final url = Uri.parse(urlString);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
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
