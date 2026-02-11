import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'bookmarks_screen.dart';
import 'settings_screen.dart';
import '../services/language_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTab = _tabController.index);
    });
    _loadProfile();
    _loadUserPosts();
  }

  String? _avatarUrl;

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();

      setState(() {
        _profile = profile;
        _avatarUrl = api.getImageUrl(profile['avatar']);
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

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();
      final userId = profile['id'] ?? profile['user_id'];

      // Load ALL pages of posts
      List<dynamic> allPosts = [];
      int page = 1;

      do {
        final postsData = await api.getUserPosts(userId, page: page);
        allPosts.addAll(postsData);

        // Try to get total pages from the API response metadata
        // If we got fewer posts than expected, we've reached the last page
        if (postsData.length < 20) {
          break; // No more pages
        }
        page++;
      } while (page <= 50); // Safety limit: max 50 pages (1000 posts)

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
                            ? Text(
                                username[0].toUpperCase(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      )
                    : CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFBE1E1E),
                        child: Text(
                          username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                Text(
                  username,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                ),
                _buildStat(
                  lang.translate('following'),
                  _profile?['following_count']?.toString() ?? '0',
                ),
              ],
            ),
          ),

          // Options
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

          // Contenu des onglets
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
            // Médias
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

  Widget _buildStat(String label, String value) {
    final theme = Theme.of(context);
    return Column(
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
