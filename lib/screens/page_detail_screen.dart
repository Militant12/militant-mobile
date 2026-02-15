import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/linkable_text.dart';

class PageDetailScreen extends StatefulWidget {
  final dynamic page;
  const PageDetailScreen({super.key, required this.page});

  @override
  State<PageDetailScreen> createState() => _PageDetailScreenState();
}

class _PageDetailScreenState extends State<PageDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _pageDetail;
  bool _isLoading = true;
  bool _isFollowed = false;
  bool _isAdmin = false;
  bool _isEditor = false;
  ApiService? _api;
  TabController? _tabController;
  int? _currentUserId;

  // Posts
  List<dynamic> _posts = [];
  final _postController = TextEditingController();
  File? _mediaFile;
  final _picker = ImagePicker();
  bool _isUploading = false;

  // Followers
  List<dynamic> _followers = [];

  // Team
  List<dynamic> _team = [];

  // Settings
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();
  final _twitterController = TextEditingController();
  final _mastodonController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _facebookController = TextEditingController();
  final _blueskyController = TextEditingController();
  String _selectedCategory = '';
  String _selectedPrivacy = 'public';

  @override
  void initState() {
    super.initState();
    _isFollowed =
        widget.page['is_followed'] == 1 || widget.page['is_followed'] == true;
    _loadPageDetail();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _api!.getProfile();
      if (mounted) setState(() => _currentUserId = user['id']);
    } catch (_) {}
  }

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le lien : $url')),
        );
      }
    }
  }

  Future<void> _loadPageDetail() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final detail = await _api!.getPageDetail(widget.page['id']);
      final role = detail['user_role'];
      final isAdmin = role == 'admin';
      final isEditor = role == 'admin' || role == 'editor';

      setState(() {
        _pageDetail = detail;
        _isFollowed =
            detail['is_followed'] == 1 || detail['is_followed'] == true;
        _isAdmin = isAdmin;
        _isEditor = isEditor;

        // Setup tabs
        final tabCount = isAdmin ? 4 : 1;
        _tabController?.dispose();
        _tabController = TabController(length: tabCount, vsync: this);

        // Fill settings
        _nameController.text = detail['name'] ?? '';
        _descController.text = detail['description'] ?? '';
        _locationController.text = detail['location'] ?? '';
        _websiteController.text = detail['website'] ?? '';
        _twitterController.text = detail['social_twitter'] ?? '';
        _mastodonController.text = detail['social_mastodon'] ?? '';
        _instagramController.text = detail['social_instagram'] ?? '';
        _tiktokController.text = detail['social_tiktok'] ?? '';
        _facebookController.text = detail['social_facebook'] ?? '';
        _blueskyController.text = detail['social_bluesky'] ?? '';
        _selectedCategory = detail['category'] ?? '';
        _selectedPrivacy = detail['privacy'] ?? 'public';
      });

      // Load posts
      _loadPosts();
      if (isAdmin) {
        _loadFollowers();
        _loadTeam();
      }
    } catch (e) {
      setState(() {
        _pageDetail = Map<String, dynamic>.from(widget.page);
        _tabController = TabController(length: 1, vsync: this);
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await _api!.getPagePosts(widget.page['id']);
      setState(() => _posts = posts);
    } catch (_) {}
  }

  Future<void> _loadFollowers() async {
    try {
      final followers = await _api!.getPageFollowers(widget.page['id']);
      print('=== LOAD FOLLOWERS: Got ${followers.length} followers ===');
      setState(() => _followers = followers);
    } catch (e) {
      print('=== LOAD FOLLOWERS ERROR: $e ===');
    }
  }

  Future<void> _loadTeam() async {
    try {
      final team = await _api!.getPageTeam(widget.page['id']);
      setState(() => _team = team);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    try {
      final api = await ApiService.getInstance();
      if (_isFollowed) {
        await api.unfollowPage(widget.page['id']);
        setState(() => _isFollowed = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous ne suivez plus cette page')),
          );
        }
      } else {
        await api.followPage(widget.page['id']);
        setState(() => _isFollowed = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Vous suivez ${_pageDetail?['name'] ?? 'cette page'}',
              ),
            ),
          );
        }
      }
      _loadPageDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _pickMedia() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Choisir un média'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFBE1E1E),
              ),
              title: const Text('Image de la galerie'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFFBE1E1E)),
              title: const Text('Vidéo de la galerie'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.gallery,
                'isVideo': true,
              }),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFBE1E1E)),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.camera,
                'isVideo': false,
              }),
            ),
            ListTile(
              leading: const Icon(
                Icons.videocam_outlined,
                color: Color(0xFFBE1E1E),
              ),
              title: const Text('Filmer une vidéo'),
              onTap: () => Navigator.pop(context, {
                'source': ImageSource.camera,
                'isVideo': true,
              }),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        XFile? pickedFile;
        if (result['isVideo'] == true) {
          pickedFile = await _picker.pickVideo(source: result['source']);
        } else {
          pickedFile = await _picker.pickImage(source: result['source']);
        }
        if (pickedFile != null) {
          setState(() => _mediaFile = File(pickedFile!.path));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty && _mediaFile == null) return;

    setState(() => _isUploading = true);
    try {
      String? mediaUrl;
      String? mediaType;

      if (_mediaFile != null) {
        final ext = _mediaFile!.path.split('.').last.toLowerCase();
        final isVideo = ['mp4', 'webm', 'mov', 'avi'].contains(ext);
        mediaType = isVideo ? 'video' : 'image';
        mediaUrl = await _api!.uploadFile(_mediaFile!.path, type: 'posts');
        if (mediaUrl.contains('/')) {
          mediaUrl = mediaUrl.split('/').last;
        }
      }

      await _api!.createPagePost(
        widget.page['id'],
        content,
        media: mediaUrl,
        mediaType: mediaType,
      );
      _postController.clear();
      setState(() => _mediaFile = null);
      _loadPosts();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Publication ajoutée !')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePost(dynamic post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la publication ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api!.deletePagePost(post['id']);
        _loadPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publication supprimée')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _editPost(dynamic post) async {
    final controller = TextEditingController(text: post['content']);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la publication'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Contenu de la publication...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.isNotEmpty) {
      try {
        await _api!.updatePagePost(post['id'], newContent);
        _loadPosts();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Publication modifiée')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _reactToPost(int postId, String type) async {
    try {
      await _api!.reactToPagePost(postId, type);
      _loadPosts();
    } catch (_) {}
  }

  void _showReactionPicker(int postId) {
    final reactions = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
      'wow': '😮',
      'sad': '😢',
      'angry': '😠',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: reactions.entries
              .map(
                (e) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _reactToPost(postId, e.key);
                  },
                  child: e.key == 'like'
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFBE1E1E).withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.thumb_up,
                            color: Color(0xFFBE1E1E),
                            size: 24,
                          ),
                        )
                      : Text(e.value, style: const TextStyle(fontSize: 32)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      await _api!.updatePageSettings(widget.page['id'], {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'location': _locationController.text.trim(),
        'website': _websiteController.text.trim(),
        'privacy': _selectedPrivacy,
        'social_twitter': _twitterController.text.trim(),
        'social_mastodon': _mastodonController.text.trim(),
        'social_instagram': _instagramController.text.trim(),
        'social_tiktok': _tiktokController.text.trim(),
        'social_facebook': _facebookController.text.trim(),
        'social_bluesky': _blueskyController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres enregistrés !')),
        );
      }
      _loadPageDetail();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  void _showAddTeamMemberDialog() {
    final usernameController = TextEditingController();
    String role = 'editor';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          title: Text(
            'Ajouter un membre',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: "Nom d'utilisateur",
                  labelStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.grey,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.white,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin (tout)')),
                  DropdownMenuItem(
                    value: 'editor',
                    child: Text('Éditeur (publier)'),
                  ),
                ],
                onChanged: (val) => setDialogState(() => role = val!),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2A2A)
                      : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (usernameController.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  await _api!.addTeamMember(
                    widget.page['id'],
                    usernameController.text.trim(),
                    role,
                  );
                  _loadTeam();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Membre ajouté !')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: ${e.toString()}')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final page = _pageDetail ?? widget.page;
    final name = page['name'] ?? 'Page';
    final description = page['description'] ?? '';
    final category = page['category'] ?? '';
    final followersCount = page['followers_count'] ?? 0;
    final coverImage = page['cover_image'];
    final avatar = page['avatar'];
    final privacy = page['privacy'] ?? 'public';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          // Cover + header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverImage != null && coverImage.isNotEmpty)
                    Image.network(
                      _api?.getImageUrl(coverImage) ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultCover(),
                    )
                  else
                    _buildDefaultCover(),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Page info
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      _buildAvatar(avatar, 60),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (category.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (privacy == 'private')
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          color: Colors.white70,
                                          size: 12,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          'Privée',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  '$followersCount abonné${followersCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF888888)
                                        : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Follow button or Admin badge
                      if (_isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE1E1E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowed
                                ? (isDark
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.grey[200])
                                : const Color(0xFFBE1E1E),
                            foregroundColor: _isFollowed
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(_isFollowed ? 'Abonné' : 'Suivre'),
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PageDescriptionContent(
                      description: description,
                      isDark: isDark,
                    ),
                  ],
                  // Social links
                  _buildSocialLinks(page, isDark),
                ],
              ),
            ),
          ),

          // Tab bar (admin sees all tabs, others see Posts only)
          if (_tabController != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFBE1E1E),
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                  isScrollable: _isAdmin,
                  tabs: [
                    const Tab(text: 'Publications'),
                    if (_isAdmin)
                      Tab(
                        text:
                            'Abonnés (${_pageDetail?['followers_count'] ?? _followers.length})',
                      ),
                    if (_isAdmin) const Tab(text: 'Équipe'),
                    if (_isAdmin) const Tab(text: 'Paramètres'),
                  ],
                ),
                isDark ? const Color(0xFF1E1E1E) : Colors.white,
              ),
            ),
        ],
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
              )
            : _tabController == null
            ? const SizedBox()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(),
                  if (_isAdmin) _buildFollowersTab(),
                  if (_isAdmin) _buildTeamTab(),
                  if (_isAdmin) _buildSettingsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBE1E1E), Color(0xFF8B0000), Color(0xFF2C0000)],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatar, double size) {
    final url = _api?.getImageUrl(avatar ?? '');
    if (url != null && !url.endsWith('.svg') && !url.contains('default')) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url),
        backgroundColor: Colors.white24,
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFBE1E1E).withOpacity(0.2),
      child: Icon(Icons.flag, color: const Color(0xFFBE1E1E), size: size * 0.5),
    );
  }

  Widget _buildSocialLinks(Map<String, dynamic> page, bool isDark) {
    final links = <Widget>[];
    final socials = {
      'social_facebook': Icons.facebook,
      'social_twitter': Icons.alternate_email,
      'social_instagram': Icons.camera_alt,
      'social_mastodon': Icons.public,
      'social_tiktok': Icons.music_note,
      'social_bluesky': Icons.cloud,
    };

    for (final entry in socials.entries) {
      final value = page[entry.key]?.toString() ?? '';
      if (value.isNotEmpty) {
        links.add(
          InkWell(
            onTap: () => _launchUrl(value),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                entry.value,
                color: isDark ? Colors.white54 : Colors.grey[600],
                size: 20,
              ),
            ),
          ),
        );
      }
    }

    final location = page['location']?.toString() ?? '';
    final website = page['website']?.toString() ?? '';

    if (links.isEmpty && location.isEmpty && website.isEmpty)
      return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (location.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (website.isNotEmpty)
          InkWell(
            onTap: () => _launchUrl(website),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      website,
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (links.isNotEmpty) Row(children: links),
      ],
    );
  }

  // ==================== POSTS TAB ====================
  Widget _buildPostsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: const Color(0xFFBE1E1E),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Create post form (admin/editor)
          if (_isEditor) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _postController,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Quoi de neuf ?...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  // Media preview
                  if (_mediaFile != null) ...[
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _isVideoFile(_mediaFile!.path)
                              ? Container(
                                  height: 120,
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  _mediaFile!,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _mediaFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _isUploading ? null : _pickMedia,
                        icon: Icon(
                          Icons.photo_camera,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                        tooltip: 'Ajouter un média',
                      ),
                      IconButton(
                        onPressed: _isUploading
                            ? null
                            : () async {
                                final pickedFile = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (pickedFile != null) {
                                  setState(
                                    () => _mediaFile = File(pickedFile.path),
                                  );
                                }
                              },
                        icon: Icon(
                          Icons.image,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                        tooltip: 'Image rapide',
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _createPost,
                        icon: _isUploading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, size: 16),
                        label: Text(_isUploading ? 'Envoi...' : 'Publier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBE1E1E),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Posts list
          if (_posts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 48,
                      color: isDark ? const Color(0xFF888888) : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune publication',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF888888)
                            : Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ..._posts.map((post) => _buildPostCard(post)),
        ],
      ),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = _pageDetail ?? widget.page;
    final likeCount = post['like_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;
    final userReaction = post['user_reaction']?.toString() ?? '';
    final emojis = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
      'wow': '😮',
      'sad': '😢',
      'angry': '😠',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildAvatar(page['avatar'], 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page['name'] ?? 'Page',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(post['created_at'] ?? ''),
                        style: TextStyle(
                          color: isDark ? const Color(0xFF888888) : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isEditor ||
                    (_currentUserId != null &&
                        post['user_id'].toString() ==
                            _currentUserId.toString()))
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Modifier'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Supprimer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') _editPost(post);
                      if (val == 'delete') _deletePost(post);
                    },
                  ),
              ],
            ),
          ),

          // Content
          if ((post['content'] ?? '').isNotEmpty)
            _PagePostContent(content: post['content'], isDark: isDark),

          // Media
          if (post['media'] != null) ...[
            const SizedBox(height: 8),
            if (post['media_type'] == 'video')
              Container(
                height: 200,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _api?.getImageUrl('uploads/posts/${post['media']}') ?? '',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
          ],

          // Stats
          if (likeCount > 0 || commentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (likeCount > 0)
                    Text(
                      '$likeCount réaction${likeCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  if (commentCount > 0)
                    GestureDetector(
                      onTap: () => _showCommentsSheet(post['id']),
                      child: Text(
                        '$commentCount commentaire${commentCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Actions
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showReactionPicker(post['id']),
                    icon: userReaction == 'like'
                        ? const Icon(
                            Icons.thumb_up,
                            color: Color(0xFFBE1E1E),
                            size: 18,
                          )
                        : userReaction.isNotEmpty
                        ? Text(
                            emojis[userReaction] ?? '',
                            style: const TextStyle(fontSize: 16),
                          )
                        : Icon(
                            Icons.thumb_up_outlined,
                            size: 18,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                    label: Text(
                      'J\'aime',
                      style: TextStyle(
                        color: userReaction.isNotEmpty
                            ? const Color(0xFFBE1E1E)
                            : (isDark ? Colors.white54 : Colors.grey),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showCommentsSheet(post['id']),
                    icon: Icon(
                      Icons.comment_outlined,
                      size: 18,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    label: Text(
                      'Commenter',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet(int postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CommentsSheet(
        postId: postId,
        pageId: widget.page['id'],
        api: _api!,
        onCommentAdded: _loadPosts,
        currentUserId: _currentUserId,
      ),
    );
  }

  // ==================== FOLLOWERS TAB ====================
  Widget _buildFollowersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: isDark ? const Color(0xFF888888) : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun abonné',
              style: TextStyle(
                color: isDark ? const Color(0xFF888888) : Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowers,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final follower = _followers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      follower['avatar'] != null &&
                          follower['avatar'] != 'default.svg' &&
                          follower['avatar'].toString().isNotEmpty
                      ? NetworkImage(
                          _api?.getImageUrl(follower['avatar']) ?? '',
                        )
                      : null,
                  radius: 22,
                  backgroundColor: const Color(0xFF1E1E1E),
                  child:
                      (follower['avatar'] == null ||
                          follower['avatar'] == 'default.svg' ||
                          follower['avatar'].toString().isEmpty)
                      ? ClipOval(
                          child: SvgPicture.asset(
                            'assets/logo.svg',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        follower['username'] ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((follower['cause'] ?? '').isNotEmpty)
                        Text(
                          follower['cause'],
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Depuis ${_formatDate(follower['followed_at'] ?? '')}',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Retirer cet abonné ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Retirer',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _api!.removePageFollower(
                          widget.page['id'],
                          follower['id'],
                        );
                        _loadFollowers();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== TEAM TAB ====================
  Widget _buildTeamTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadTeam,
      color: const Color(0xFFBE1E1E),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Les admins peuvent tout faire. Les éditeurs peuvent publier mais pas modifier les paramètres.',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey,
                fontSize: 13,
              ),
            ),
          ),

          // Team list
          ..._team.map(
            (member) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: member['avatar'] != null
                        ? NetworkImage(
                            _api?.getImageUrl(member['avatar']) ?? '',
                          )
                        : null,
                    radius: 20,
                    child: member['avatar'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member['username'] ?? '',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: member['role'] == 'admin'
                                ? const Color(0xFFBE1E1E)
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            member['role'] == 'admin' ? 'Admin' : 'Éditeur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Retirer ce membre ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Retirer',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await _api!.removeTeamMember(
                            widget.page['id'],
                            member['user_id'],
                          );
                          _loadTeam();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Add member button
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showAddTeamMemberDialog,
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter un membre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SETTINGS TAB ====================
  Widget _buildSettingsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = [
      '',
      'Syndicat',
      'Collectif',
      'Association',
      'Média',
      'Squat / Lieu',
      'Infokiosque',
      'Artiste',
      'Projet',
      'Autre',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingsField('Nom de la page', _nameController, isDark),
          const SizedBox(height: 12),

          // Category
          Text(
            'Catégorie',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: categories.contains(_selectedCategory)
                ? _selectedCategory
                : '',
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            items: categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.isEmpty ? '-- Choisir --' : c),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedCategory = val ?? ''),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          _settingsField('Description', _descController, isDark, maxLines: 3),
          const SizedBox(height: 12),

          // Privacy
          Text(
            'Visibilité',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedPrivacy,
            dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            items: const [
              DropdownMenuItem(
                value: 'public',
                child: Text('Publique - Tout le monde peut voir'),
              ),
              DropdownMenuItem(
                value: 'private',
                child: Text('Privée - Abonnés uniquement'),
              ),
            ],
            onChanged: (val) =>
                setState(() => _selectedPrivacy = val ?? 'public'),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          _settingsField(
            'Localisation',
            _locationController,
            isDark,
            hint: 'Ville, Pays',
          ),
          const SizedBox(height: 12),
          _settingsField(
            'Site web',
            _websiteController,
            isDark,
            hint: 'https://...',
          ),
          const SizedBox(height: 16),

          // Social links
          Text(
            'Réseaux sociaux',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _socialField(
            Icons.alternate_email,
            'Twitter/X',
            _twitterController,
            isDark,
          ),
          _socialField(
            Icons.public,
            'Mastodon',
            _mastodonController,
            isDark,
            hint: 'https://mastodon.social/@pseudo',
          ),
          _socialField(
            Icons.camera_alt,
            'Instagram',
            _instagramController,
            isDark,
          ),
          _socialField(Icons.music_note, 'TikTok', _tiktokController, isDark),
          _socialField(Icons.facebook, 'Facebook', _facebookController, isDark),
          _socialField(
            Icons.cloud,
            'Bluesky',
            _blueskyController,
            isDark,
            hint: 'pseudo.bsky.social',
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _settingsField(
    String label,
    TextEditingController controller,
    bool isDark, {
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _socialField(
    IconData icon,
    String label,
    TextEditingController controller,
    bool isDark, {
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white38 : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hint ?? label,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey[400],
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return date;
    }
  }

  bool _isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'webm', 'mov', 'avi', 'mkv'].contains(ext);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _postController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _twitterController.dispose();
    _mastodonController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _facebookController.dispose();
    _blueskyController.dispose();
    super.dispose();
  }
}

// Helper delegate for pinned tab bar in NestedScrollView
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        backgroundColor != oldDelegate.backgroundColor;
  }
}

class _CommentsSheet extends StatefulWidget {
  final int postId;
  final int pageId;
  final ApiService api;
  final VoidCallback onCommentAdded;
  final int? currentUserId;

  const _CommentsSheet({
    required this.postId,
    required this.pageId,
    required this.api,
    required this.onCommentAdded,
    this.currentUserId,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<dynamic> _comments = [];
  bool _isLoading = true;
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await widget.api.getPagePostComments(
        widget.pageId,
        widget.postId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await widget.api.commentOnPagePost(widget.postId, text);
      _commentController.clear();
      widget.onCommentAdded();
      _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Supprimer ce commentaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.api.deletePageComment(commentId);
        _loadComments();
        widget.onCommentAdded();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _editComment(dynamic comment) async {
    final controller = TextEditingController(text: comment['content']);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le commentaire'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Votre commentaire...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE1E1E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.isNotEmpty) {
      try {
        await widget.api.updatePageComment(comment['id'], newContent);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFBE1E1E),
                      ),
                    )
                  : _comments.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun commentaire',
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final String avatarUrl = (comment['user_avatar'] ?? '')
                            .toString();
                        final bool hasAvatar =
                            avatarUrl.isNotEmpty && avatarUrl != 'default.svg';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF1E1E1E),
                                backgroundImage: hasAvatar
                                    ? NetworkImage(
                                        widget.api.getImageUrl(avatarUrl) ?? '',
                                      )
                                    : null,
                                child: !hasAvatar
                                    ? ClipOval(
                                        child: SvgPicture.asset(
                                          'assets/logo.svg',
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment['username'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(
                                            comment['created_at'] ?? '',
                                          ),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      comment['content'] ?? '',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.currentUserId == comment['user_id'])
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.grey,
                                  ),
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      height: 32,
                                      child: Text(
                                        'Modifier',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      height: 32,
                                      child: Text(
                                        'Supprimer',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onSelected: (val) {
                                    if (val == 'delete') {
                                      _deleteComment(comment['id']);
                                    } else if (val == 'edit') {
                                      _editComment(comment);
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Input
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Écrire un commentaire...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFBE1E1E),
                            ),
                          )
                        : const Icon(Icons.send, color: Color(0xFFBE1E1E)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String date) {
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'à l\'instant';
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return date;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _PagePostContent extends StatefulWidget {
  final String content;
  final bool isDark;

  const _PagePostContent({required this.content, required this.isDark});

  @override
  State<_PagePostContent> createState() => _PagePostContentState();
}

class _PagePostContentState extends State<_PagePostContent> {
  final Set<String> _detectedUrls = {};

  @override
  Widget build(BuildContext context) {
    if (widget.content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: LinkableText(
            text: widget.content,
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black,
              fontSize: 15,
            ),
            onLinksDetected: (urls) {
              final newUrls = urls
                  .where((u) => !_detectedUrls.contains(u))
                  .toList();
              if (newUrls.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _detectedUrls.addAll(newUrls);
                    });
                  }
                });
              }
            },
          ),
        ),
        if (_detectedUrls.isNotEmpty)
          ..._detectedUrls.map((url) => LinkPreviewCard(url: url)),
      ],
    );
  }
}

class _PageDescriptionContent extends StatefulWidget {
  final String description;
  final bool isDark;

  const _PageDescriptionContent({
    required this.description,
    required this.isDark,
  });

  @override
  State<_PageDescriptionContent> createState() =>
      _PageDescriptionContentState();
}

class _PageDescriptionContentState extends State<_PageDescriptionContent> {
  final Set<String> _detectedUrls = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinkableText(
          text: widget.description,
          style: TextStyle(
            color: widget.isDark ? const Color(0xFFAAAAAA) : Colors.grey[700],
            fontSize: 14,
          ),
          onLinksDetected: (urls) {
            final newUrls = urls
                .where((u) => !_detectedUrls.contains(u))
                .toList();
            if (newUrls.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _detectedUrls.addAll(newUrls);
                  });
                }
              });
            }
          },
        ),
        if (_detectedUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: _detectedUrls
                  .map((url) => LinkPreviewCard(url: url))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
