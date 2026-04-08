import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<dynamic> _myGroups = [];
  final List<dynamic> _discoverGroups = [];
  final Set<int> _joiningGroupIds = <int>{};
  bool _isLoading = false;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final myGroups = await _api!.getGroups();
      final discoverGroups = await _api!.discoverGroups();
      final discoverGroupsWithStatus = await _enrichDiscoverGroups(
        discoverGroups,
      );
      setState(() {
        _myGroups.clear();
        _myGroups.addAll(myGroups);
        _discoverGroups.clear();
        _discoverGroups.addAll(discoverGroupsWithStatus);
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error_loading')}: ${e.toString()}',
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _cleanErrorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
  }

  int? _parseGroupId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<List<dynamic>> _enrichDiscoverGroups(List<dynamic> groups) async {
    final api = _api ?? await ApiService.getInstance();

    return Future.wait(
      groups.map((group) async {
        if (group is! Map) return group;

        final groupData = Map<String, dynamic>.from(
          group.map((key, value) => MapEntry(key.toString(), value)),
        );
        final groupId = _parseGroupId(groupData['id']);

        if (groupData['privacy'] != 'private' || groupId == null) {
          return groupData;
        }

        try {
          final details = await api.getSocialGroupDetails(groupId);
          groupData['has_pending_request'] = details['has_pending_request'];
        } catch (_) {}

        return groupData;
      }),
    );
  }

  Future<bool> _confirmPrivateGroupJoin() async {
    final lang = LanguageService.instance;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('join_private_group_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('join_private_group_message'),
          style: const TextStyle(color: Colors.white70),
        ),
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

    return confirm == true;
  }

  void _showCreateGroupDialog() {
    final lang = LanguageService.instance;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Row(
            children: [
              const Icon(Icons.group_add, color: Color(0xFFBE1E1E)),
              const SizedBox(width: 8),
              Text(
                lang.translate('create_group_title'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: lang.translate('group_name_label'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: lang.translate('group_description_label'),
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(
                    lang.translate('group_private_label'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    lang.translate('group_private_subtitle'),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: isPrivate,
                  activeThumbColor: const Color(0xFFBE1E1E),
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                  contentPadding: EdgeInsets.zero,
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
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  final api = await ApiService.getInstance();
                  final result = await api.createGroup(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    isPrivate: isPrivate,
                  );
                  if (!mounted) return;
                  _loadGroups();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang.translate('group_created_success')),
                    ),
                  );
                  // Navigate to the new group
                  if (result['id'] != null) {
                    final groupId = result['id'];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(
                          group: {
                            'id': groupId,
                            'name': nameController.text.trim(),
                            'description': descController.text.trim(),
                            'is_member': 1,
                            'members_count': 1,
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${lang.translate('error')}: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
              ),
              child: Text(LanguageService.instance.translate('create')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(dynamic group) async {
    final lang = LanguageService.instance;
    if (group is! Map) return;

    final groupData = Map<String, dynamic>.from(
      group.map((key, value) => MapEntry(key.toString(), value)),
    );
    final groupId = _parseGroupId(groupData['id']);
    if (groupId == null || _joiningGroupIds.contains(groupId)) return;

    final hasPendingRequest = groupData['has_pending_request'] == 'pending';
    if (hasPendingRequest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('join_request_pending'))),
      );
      return;
    }

    final isPrivate = groupData['privacy'] == 'private';
    if (isPrivate) {
      final confirmed = await _confirmPrivateGroupJoin();
      if (!confirmed) return;
    }

    setState(() {
      _joiningGroupIds.add(groupId);
    });

    try {
      final api = await ApiService.getInstance();
      await api.joinGroup(groupId);

      if (isPrivate) {
        final index = _discoverGroups.indexWhere(
          (item) => item is Map && item['id'] == groupId,
        );
        if (index != -1) {
          _discoverGroups[index] = {
            ...Map<String, dynamic>.from(
              (_discoverGroups[index] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
            'has_pending_request': 'pending',
          };
        }
      } else {
        await _loadGroups();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPrivate
                  ? lang.translate('join_request_sent')
                  : '${lang.translate('joined_group')} ${groupData['name']}',
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[GroupsScreen][_joinGroup] groupId=$groupId error=$e');
      debugPrint('$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_cleanErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _joiningGroupIds.remove(groupId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          LanguageService.instance.translate('groups_title'),
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBE1E1E),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${LanguageService.instance.translate('groups_title')} (${_myGroups.length})',
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore, size: 18),
                  const SizedBox(width: 6),
                  Text(LanguageService.instance.translate('discover')),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildMyGroupsTab(), _buildDiscoverTab()],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: const Color(0xFFBE1E1E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    final lang = LanguageService.instance;
    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_outlined,
              size: 64,
              color: Color(0xFF888888),
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('no_groups_message'),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('no_groups_subtitle'),
              style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.explore),
              label: Text(lang.translate('discover_groups')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _myGroups.length,
        itemBuilder: (context, index) {
          final group = _myGroups[index];
          return _buildGroupItem(group, isMember: true);
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final lang = LanguageService.instance;
    if (_discoverGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Color(0xFF888888)),
            const SizedBox(height: 16),
            Text(
              lang.translate('no_discover_groups'),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('all_groups_joined'),
              style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _discoverGroups.length,
        itemBuilder: (context, index) {
          final group = _discoverGroups[index];
          return _buildGroupItem(group, isMember: false);
        },
      ),
    );
  }

  Widget _buildGroupItem(dynamic group, {required bool isMember}) {
    final lang = LanguageService.instance;
    final name = group['name'] ?? lang.translate('group');
    final description = group['description'] ?? '';
    final membersCount = group['members_count'] ?? 0;
    final postsCount = group['posts_count'] ?? 0;
    final avatar = group['avatar'];
    final privacy = group['privacy'] ?? 'public';
    final groupId = _parseGroupId(group['id']);
    final hasPendingRequest =
        !isMember && group['has_pending_request'] == 'pending';
    final isJoining =
        !isMember && groupId != null && _joiningGroupIds.contains(groupId);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
        ).then((_) => _loadGroups());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            _buildGroupAvatar(avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock,
                                color: Colors.white54,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                lang.translate('private'),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      softWrap: true,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        color: Color(0xFF888888),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$membersCount ${membersCount > 1 ? lang.translate('members') : lang.translate('member')}',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.article,
                        color: Color(0xFF888888),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$postsCount ${postsCount > 1 ? lang.translate('posts_count_plural') : lang.translate('posts_count')}',
                        style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isMember) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: hasPendingRequest || isJoining
                    ? null
                    : () => _joinGroup(group),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasPendingRequest
                      ? Colors.orange
                      : const Color(0xFFBE1E1E),
                  disabledBackgroundColor: hasPendingRequest
                      ? Colors.orange
                      : Colors.white24,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isJoining
                      ? '...'
                      : hasPendingRequest
                      ? lang.translate('request_pending')
                      : lang.translate('join'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(String? avatar) {
    final url = _api?.getImageUrl(avatar);
    if (url != null && url.endsWith('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SvgPicture.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (url != null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      );
    } else {
      // Logo Militant par défaut pour les groupes sans image
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          color: Colors.white,
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.contain),
        ),
      );
    }
  }
}
