import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import '../widgets/linkable_text.dart';
import 'users_list_screen.dart';

import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class GroupDetailScreen extends StatefulWidget {
  final dynamic group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final List<Post> _posts = [];
  bool _isLoading = false;
  int _currentPage = 1;
  ApiService? _api;
  Map<String, dynamic>? _groupData;
  List<dynamic> _previewMembers = []; // For the members preview

  @override
  void initState() {
    super.initState();
    _groupData = widget.group;
    _loadPosts();
    _loadGroupInfo();
    _loadMembersPreview();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _posts.clear();
        _currentPage = 1;
      }
    });

    try {
      _api = await ApiService.getInstance();
      final postsData = await _api!.getGroupPosts(
        _groupData!['id'],
        page: _currentPage,
      );

      setState(() {
        _posts.addAll(
          postsData.map((p) {
            p['type'] = 'group';
            p['group_id'] = _groupData!['id'];
            return Post.fromJson(p);
          }).toList(),
        );
        _currentPage++;
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        // Don't show snackbar for 403 (Unauthorized/Membership required), as it's handled by the UI
        if (!e.toString().contains('403')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${lang.translate('group_detail_error')}: ${e.toString()}',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMembersPreview() async {
    try {
      _api ??= await ApiService.getInstance();
      // Fetch members just for preview count/avatars
      final members = await _api!.getGroupMembers(_groupData!['id']);
      if (mounted) {
        setState(() {
          _previewMembers = members;
          // Also update count if possible
          if (_groupData != null) {
            _groupData!['members_count'] = members.length;
          }
        });
      }
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _joinGroup() async {
    try {
      final api = await ApiService.getInstance();
      await api.joinGroup(_groupData!['id']);
      setState(() {
        _groupData!['is_member'] = 1;
      });
      _loadPosts(refresh: true);
      _loadMembersPreview(); // Reload members to show self
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _shareGroup() async {
    final lang = LanguageService.instance;
    final String groupName = _groupData!['name'] ?? lang.translate('group');
    final int groupId = _groupData!['id'];

    _api ??= await ApiService.getInstance();

    // Construct web URL
    String baseUrl = _api!.baseUrl;

    // Clean up URL if needed (remove /api if present to get web root)
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    } else if (baseUrl.contains('api.')) {
      baseUrl = baseUrl.replaceAll('api.', '');
    }

    final String url = '$baseUrl/group_detail.php?id=$groupId';

    await Share.share(
      '${lang.translate('join')} "$groupName" sur Militant !\n$url',
    );
  }

  Future<void> _loadGroupInfo() async {
    try {
      _api ??= await ApiService.getInstance();
      final data = await _api!.getSocialGroupDetails(_groupData!['id']);
      if (mounted) {
        setState(() {
          _groupData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading group info: $e');
    }
  }

  void _showEditGroupDialog() {
    final lang = LanguageService.instance;
    final nameController = TextEditingController(text: _groupData!['name']);
    final descController = TextEditingController(
      text: _groupData!['description'],
    );
    bool isPrivate = _groupData!['privacy'] == 'private';
    File? newAvatar;
    File? newCover;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            lang.translate('group_settings_title'),
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        newAvatar = File(picked.path);
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF2A2A2A),
                    backgroundImage: newAvatar != null
                        ? FileImage(newAvatar!) as ImageProvider
                        : null,
                    child: newAvatar == null
                        ? (_api?.getImageUrl(_groupData!['avatar']) != null &&
                                  (_api!
                                          .getImageUrl(_groupData!['avatar'])
                                          ?.isNotEmpty ??
                                      false))
                              ? ClipOval(
                                  child: Image.network(
                                    _api!.getImageUrl(_groupData!['avatar'])!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.white,
                                        padding: const EdgeInsets.all(16),
                                        child: SvgPicture.asset(
                                          'assets/logo.svg',
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(16),
                                  child: SvgPicture.asset(
                                    'assets/logo.svg',
                                    fit: BoxFit.contain,
                                  ),
                                )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        newCover = File(picked.path);
                      });
                    }
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(8),
                      image: newCover != null
                          ? DecorationImage(
                              image: FileImage(newCover!),
                              fit: BoxFit.cover,
                            )
                          : (_groupData!['cover_image'] != null &&
                                _groupData!['cover_image']
                                    .toString()
                                    .isNotEmpty)
                          ? DecorationImage(
                              image: NetworkImage(
                                _api!.getImageUrl(_groupData!['cover_image'])!,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.white70),
                          const SizedBox(height: 4),
                          Text(
                            lang.translate('change_cover'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang.translate('group_name'),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang.translate('description'),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    lang.translate('group_privacy'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  value: isPrivate,
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                  activeThumbColor: const Color(0xFFBE1E1E),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                lang.translate('cancel'),
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  String? avatarPath;
                  if (newAvatar != null) {
                    final uploadUrl = await _api!.uploadFile(
                      newAvatar!.path,
                      type: 'group',
                    );
                    avatarPath = uploadUrl.split('/').last;
                  }

                  String? coverPath;
                  if (newCover != null) {
                    final uploadUrl = await _api!.uploadFile(
                      newCover!.path,
                      type: 'group',
                    );
                    coverPath = uploadUrl.split('/').last;
                  }

                  await _api!.updateGroup(
                    int.parse(_groupData!['id'].toString()),
                    name: nameController.text,
                    description: descController.text,
                    avatar: avatarPath,
                    coverImage: coverPath,
                    isPrivate: isPrivate,
                  );

                  _loadGroupInfo(); // Refresh info
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
              ),
              child: Text(lang.translate('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = _groupData!['name'] ?? lang.translate('group');
    final description = _groupData!['description'] ?? '';
    final avatar = _groupData!['avatar'];
    final isMember =
        _groupData!['is_member'] == 1 || _groupData!['is_member'] == true;
    final isPublic = _groupData!['privacy'] == 'public';
    final canViewPosts = isMember || isPublic;
    final membersCount = _groupData!['members_count'] ?? _previewMembers.length;
    final privacy = _groupData!['privacy'] == 'private'
        ? lang.translate('private')
        : lang.translate('public');

    // Facebook style Header
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(refresh: true),
        color: const Color(0xFFBE1E1E),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                if (_groupData!['role'] != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _showEditGroupDialog,
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildHeaderBackground(avatar),
                    // Optional: Gradient for better visibility if we had text here
                    // But we moved text below.
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: theme.scaffoldBackgroundColor,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stats Row
                    Row(
                      children: [
                        Icon(
                          _groupData!['privacy'] == 'private'
                              ? Icons.lock
                              : Icons.public,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$privacy · $membersCount ${membersCount > 1 ? lang.translate('members') : lang.translate('member')}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isMember ? () {} : _joinGroup,
                            icon: Icon(
                              isMember ? Icons.check : Icons.group_add,
                              size: 18,
                            ),
                            label: Text(
                              isMember
                                  ? lang.translate('joined')
                                  : lang.translate('join'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMember
                                  ? (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200])
                                  : const Color(0xFFBE1E1E),
                              foregroundColor: isMember
                                  ? theme.textTheme.bodyLarge?.color
                                  : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareGroup,
                            icon: const Icon(Icons.share, size: 18),
                            label: Text(lang.translate('share')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              foregroundColor: theme.textTheme.bodyLarge?.color,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              iconColor: theme.iconTheme.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Members Link / Preview
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UsersListScreen(
                              groupId: int.parse(_groupData!['id'].toString()),
                              type: 'members',
                              title: lang.translate('members_title'),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor,
                              width: 0.5,
                            ),
                            top: BorderSide(
                              color: theme.dividerColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 30,
                              child: Stack(
                                children: [
                                  for (
                                    int i = 0;
                                    i <
                                        (_previewMembers.length > 3
                                            ? 3
                                            : _previewMembers.length);
                                    i++
                                  )
                                    Positioned(
                                      left: i * 20.0,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                theme.scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                          color: Colors.grey[300],
                                        ),
                                        child: ClipOval(
                                          child: _buildMemberAvatar(
                                            _previewMembers[i],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(lang.translate('view_members')),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      LinkableText(
                        text: description,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    if (canViewPosts)
                      Text(
                        lang.translate('publications_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (canViewPosts)
              _posts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFFBE1E1E),
                              )
                            : Text(lang.translate('no_posts_yet')),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == _posts.length) {
                          if (_isLoading) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFBE1E1E),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 80);
                        }
                        return PostCard(post: _posts[index]);
                      }, childCount: _posts.length + 1),
                    ),
          ],
        ),
      ),
      floatingActionButton: isMember
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreatePostScreen(groupId: _groupData!['id']),
                  ),
                );
                if (result == true) {
                  _loadPosts(refresh: true);
                }
              },
              backgroundColor: const Color(0xFFBE1E1E),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildMemberAvatar(dynamic member) {
    if (member['avatar'] != null) {
      final url = _api?.getImageUrl(member['avatar']);
      if (url != null) {
        if (url.endsWith('.svg')) {
          return SvgPicture.network(url, fit: BoxFit.cover);
        }
        return Image.network(url, fit: BoxFit.cover);
      }
    }
    return SvgPicture.asset('assets/logo.svg', fit: BoxFit.cover);
  }

  Widget _buildHeaderBackground(String? avatar) {
    // We utilize the cover_image if available, otherwise fallback to avatar, then color.
    final coverImage = _groupData?['cover_image'];
    final coverUrl = _api?.getImageUrl(coverImage);

    if (coverUrl != null && coverUrl.isNotEmpty) {
      return Image.network(
        coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
      );
    }

    // Fallback to existing avatar logic or plain color
    final url = _api?.getImageUrl(avatar);
    if (url != null) {
      if (url.endsWith('.svg')) {
        return SvgPicture.network(
          url,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(color: Colors.grey[900]),
        );
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
      );
    }
    return Container(color: const Color(0xFFBE1E1E).withOpacity(0.5));
  }
}
