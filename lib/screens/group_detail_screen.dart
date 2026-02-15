import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import '../widgets/linkable_text.dart';

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

  @override
  void initState() {
    super.initState();
    _groupData = widget.group;
    _loadPosts();
    _loadGroupInfo();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _shareGroup() async {
    final String groupName = _groupData!['name'] ?? 'Groupe';
    final int groupId = _groupData!['id'];

    if (_api == null) {
      _api = await ApiService.getInstance();
    }

    // Construct web URL
    String baseUrl = _api!.baseUrl;

    // Clean up URL if needed (remove /api if present to get web root)
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    } else if (baseUrl.contains('api.')) {
      baseUrl = baseUrl.replaceAll('api.', '');
    }

    final String url = '$baseUrl/group_detail.php?id=$groupId';

    await Share.share('Rejoins le groupe "$groupName" sur Militant !\n$url');
  }

  Future<void> _loadGroupInfo() async {
    try {
      if (_api == null) _api = await ApiService.getInstance();
      final data = await _api!.getSocialGroupDetails(_groupData!['id']);
      if (mounted) {
        setState(() {
          // Merge data to keep existing fields if needed, but API usually returns full object
          // But beware of missing fields.
          // Let's just update fields we care about or replace _groupData if structure matches.
          // _groupData is Map<String, dynamic>.
          // The API returns the group object including role.

          // Preserve some local state if any? No.
          // But ensure we don't lose 'is_member' logic if API returns '1'/'0' vs true/false.
          // API v1/groups returns 1/0 for is_member. Flutter checks == 1 || == true.
          _groupData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading group info: $e');
    }
  }

  void _showEditGroupDialog() {
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
          title: const Text(
            'Paramètres du groupe',
            style: TextStyle(color: Colors.white),
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
                          Icon(Icons.camera_alt, color: Colors.white70),
                          SizedBox(height: 4),
                          Text(
                            'Changer la couverture',
                            style: TextStyle(color: Colors.white70),
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
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    filled: true,
                    fillColor: Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    filled: true,
                    fillColor: Color(0xFF2A2A2A),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text(
                    'Privé',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: isPrivate,
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                  activeColor: const Color(0xFFBE1E1E),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.white54),
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
              child: const Text('Enregistrer'),
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
    final name = _groupData!['name'] ?? 'Groupe';
    final description = _groupData!['description'] ?? '';
    final avatar = _groupData!['avatar'];
    final isMember =
        _groupData!['is_member'] == 1 || _groupData!['is_member'] == true;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(refresh: true),
        color: const Color(0xFFBE1E1E),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              actions: [
                if (_groupData!['role'] != null)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _showEditGroupDialog,
                  ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareGroup,
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(name),
                background: _buildHeaderBackground(avatar),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      LinkableText(
                        text: description,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!isMember)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _joinGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBE1E1E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Rejoindre le groupe'),
                        ),
                      )
                    else
                      const Text(
                        'Publications du groupe',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isMember)
              _posts.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Color(0xFFBE1E1E),
                              )
                            : const Text('Aucune publication pour le moment'),
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
