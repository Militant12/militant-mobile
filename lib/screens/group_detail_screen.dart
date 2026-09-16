import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import '../widgets/linkable_text.dart';
import 'users_list_screen.dart';
import 'group_join_requests_screen.dart';
import 'group_invite_screen.dart';


import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/error_helper.dart';

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
    if (_canViewPostsForGroup(_groupData)) {
      _loadPosts();
    }
    _loadGroupInfo();
    _loadMembersPreview();
  }

  bool _canViewPostsForGroup(Map<String, dynamic>? group) {
    if (group == null) return false;
    final isMember = group['is_member'] == 1 || group['is_member'] == true;
    final isPublic = group['privacy'] == 'public';
    return isMember || isPublic;
  }

  bool _isExpectedPrivateGroupAccessError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('403') ||
        message.contains('forbidden') ||
        message.contains('unauthorized') ||
        message.contains('non autorise') ||
        message.contains('non autorisé') ||
        message.contains('must be a member') ||
        message.contains('membership required') ||
        message.contains('membre requis') ||
        message.contains('private group') ||
        message.contains('groupe prive') ||
        message.contains('groupe privé');
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading || !_canViewPostsForGroup(_groupData)) return;

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
        // Private groups can legitimately block posts before membership approval.
        if (!_isExpectedPrivateGroupAccessError(e)) {
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
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();

      // Check if group is private
      final isPrivate = _groupData!['privacy'] == 'private';

      if (isPrivate) {
        // For private groups, show a message that a request will be sent
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            title: Text(lang.translate('join_private_group_title')),
            content: Text(lang.translate('join_private_group_message')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(lang.translate('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  lang.translate('send_request'),
                  style: const TextStyle(color: Color(0xFFBE1E1E)),
                ),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      await api.joinGroup(_groupData!['id']);

      // Reload group info to get updated status
      await _loadGroupInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPrivate
                  ? lang.translate('join_request_sent')
                  : lang.translate('joined_group_success'),
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint(
        '[GroupDetailScreen][_joinGroup] groupId=${_groupData?['id']} error=$e',
      );
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _leaveGroup() async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Text(lang.translate('leave_group_title')),
        content: Text(lang.translate('leave_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('leave'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiService.getInstance();
        await api.leaveSocialGroup(_groupData!['id']);
        setState(() {
          _groupData!['is_member'] = 0;
          _posts.clear();
        });
        _loadMembersPreview();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('left_group_success'))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
        }
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
      if (_canViewPostsForGroup(data) && _posts.isEmpty) {
        await _loadPosts(refresh: true);
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
                  ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
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
    final canViewPosts = _canViewPostsForGroup(_groupData);
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
                if (_groupData!['role'] != null) ...[
                  // Show join requests button for admins of private groups
                  if (_groupData!['role'] == 'admin' &&
                      _groupData!['privacy'] == 'private')
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupJoinRequestsScreen(
                                    groupId: _groupData!['id'],
                                    groupName: _groupData!['name'] ?? '',
                                  ),
                                ),
                              ).then((_) => _loadGroupInfo());
                            },
                          ),
                          if ((_groupData!['pending_requests_count'] ?? 0) > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFBE1E1E),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '${_groupData!['pending_requests_count']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.group_add, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupInviteScreen(
                              groupId: _groupData!['id'],
                              groupName: _groupData!['name'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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
                            onPressed: () {
                              final hasPendingRequest =
                                  _groupData!['has_pending_request'] ==
                                  'pending';
                              if (isMember) {
                                _leaveGroup();
                              } else if (hasPendingRequest) {
                                // Show message that request is pending
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang.translate('join_request_pending'),
                                    ),
                                  ),
                                );
                              } else {
                                _joinGroup();
                              }
                            },
                            icon: Icon(
                              isMember
                                  ? Icons.exit_to_app
                                  : (_groupData!['has_pending_request'] ==
                                            'pending'
                                        ? Icons.schedule
                                        : Icons.group_add),
                              size: 18,
                            ),
                            label: Text(
                              isMember
                                  ? lang.translate('leave')
                                  : (_groupData!['has_pending_request'] ==
                                            'pending'
                                        ? lang.translate('request_pending')
                                        : lang.translate('join')),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMember
                                  ? (isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[300])
                                  : (_groupData!['has_pending_request'] ==
                                            'pending'
                                        ? Colors.orange
                                        : const Color(0xFFBE1E1E)),
                              foregroundColor: isMember
                                  ? (isDark ? Colors.white70 : Colors.black87)
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

                    // Members section with inline list
                    _buildMembersSection(lang, theme, isMember),

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
                        return PostCard(
                          post: _posts[index],
                          isGroupAdmin: _groupData?['role'] == 'admin',
                          onDeleted: () {
                            setState(() {
                              _posts.removeAt(index);
                            });
                          },
                        );
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

  Widget _buildMembersSection(
    LanguageService lang,
    ThemeData theme,
    bool isMember,
  ) {
    final isCurrentUserAdmin = _groupData?['role'] == 'admin';
    final groupId = int.parse(_groupData!['id'].toString());
    final membersCount = _groupData?['members_count'] ?? _previewMembers.length;
    final displayMembers = _previewMembers.take(4).toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UsersListScreen(
                groupId: groupId,
                type: 'members',
                title: lang.translate('members_title'),
                isCurrentUserAdmin: isCurrentUserAdmin,
              ),
            ),
          ).then((_) => _loadMembersPreview());
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Overlapped avatars stack (Facebook style)
              SizedBox(
                width: displayMembers.isEmpty
                    ? 32
                    : (32 + (displayMembers.length - 1) * 20).toDouble(),
                height: 32,
                child: Stack(
                  children: [
                    for (int i = 0; i < displayMembers.length; i++)
                      Positioned(
                        left: i * 20.0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                            color: Colors.grey[400],
                          ),
                          child: ClipOval(
                            child: _buildMemberAvatar(displayMembers[i]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Member count and summary label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$membersCount ${membersCount > 1 ? lang.translate('members') : lang.translate('member')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Admins et membres du groupe',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Action / Arrow indicator
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE1E1E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFBE1E1E),
                ),
              ),
            ],
          ),
        ),
      ),
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
