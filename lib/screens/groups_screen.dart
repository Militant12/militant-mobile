import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme_context.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'group_detail_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

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
  Object? _error;
  ApiService? _api;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      debugPrint('[GroupsScreen] loading groups baseUrl=${_api!.apiUrl}');
      final myGroups = await _api!.getGroups(query: _searchQuery);
      debugPrint('[GroupsScreen] myGroups loaded count=${myGroups.length}');
      final discoverGroups = await _api!.discoverGroups(query: _searchQuery);
      debugPrint(
        '[GroupsScreen] discoverGroups loaded count=${discoverGroups.length}',
      );
      final discoverGroupsWithStatus = await _enrichDiscoverGroups(
        discoverGroups,
      );
      if (!mounted) return;
      setState(() {
        _error = null;
        _myGroups.clear();
        _myGroups.addAll(myGroups);
        _discoverGroups.clear();
        _discoverGroups.addAll(discoverGroupsWithStatus);
      });
    } catch (e) {
      debugPrint('[GroupsScreen] loadGroups error=$e');
      if (!mounted) return;
      if (_myGroups.isEmpty && _discoverGroups.isEmpty) {
        setState(() => _error = e);
      } else {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text(
          lang.translate('join_private_group_title'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        content: Text(
          lang.translate('join_private_group_message'),
          style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.7)),
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
              style: TextStyle(color: context.colors.primary),
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
          title: Row(
            children: [
              Icon(Icons.group_add, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(
                lang.translate('create_group_title'),
                style: TextStyle(color: context.colors.onSurface),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: context.colors.onSurface),
                  decoration: InputDecoration(
                    labelText: lang.translate('group_name_label'),
                    labelStyle: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.54)),
                    filled: true,
                    fillColor: context.colors.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: TextStyle(color: context.colors.onSurface),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: lang.translate('group_description_label'),
                    labelStyle: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.54)),
                    filled: true,
                    fillColor: context.colors.surfaceContainerHigh,
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
                    style: TextStyle(color: context.colors.onSurface),
                  ),
                  subtitle: Text(
                    lang.translate('group_private_subtitle'),
                    style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.38), fontSize: 12),
                  ),
                  value: isPrivate,
                  activeThumbColor: context.colors.primary,
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
                style: TextStyle(color: context.colors.onSurface.withValues(alpha: 0.54)),
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
                        content: Text(getFriendlyErrorMessage(e, lang)),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
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
      appBar: AppBar(
        title: Text(
          LanguageService.instance.translate('groups_title'),
          style: TextStyle(color: context.colors.onSurface),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.primary,
          labelColor: context.colors.onSurface,
          unselectedLabelColor: context.colors.onSurface.withValues(alpha: 0.54),
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
      body: _isLoading && _myGroups.isEmpty && _discoverGroups.isEmpty
          ? const SkeletonList()
          : _error != null && _myGroups.isEmpty && _discoverGroups.isEmpty
          ? ErrorState(error: _error, onRetry: _loadGroups)
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildMyGroupsTab(), _buildDiscoverTab()],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        tooltip: LanguageService.instance.translate('create_group_title'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    try {
      final api = _api ?? await ApiService.getInstance();
      final myGroups = await api.getGroups(query: _searchQuery);
      final discoverGroups = await api.discoverGroups(query: _searchQuery);
      final discoverGroupsWithStatus = await _enrichDiscoverGroups(discoverGroups);
      if (mounted) {
        setState(() {
          _myGroups.clear();
          _myGroups.addAll(myGroups);
          _discoverGroups.clear();
          _discoverGroups.addAll(discoverGroupsWithStatus);
        });
      }
    } catch (e) {
      debugPrint('[GroupsScreen] search error=$e');
    }
  }

  Widget _buildSearchBar() {
    final lang = LanguageService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.colors.outlineVariant,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: context.colors.onSurface,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: _tabController.index == 0
                ? lang.translate('search_my_groups')
                : lang.translate('discover_groups_hint'),
            hintStyle: TextStyle(
              color: context.colors.onSurface.withValues(alpha: 0.54),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: context.colors.primary,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: lang.translate('clear'),
                    icon: Icon(
                      Icons.clear,
                      color: context.colors.onSurface.withValues(alpha: 0.54),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      setState(() {
                        _searchQuery = '';
                      });
                      _performSearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    final lang = LanguageService.instance;
    final filteredGroups = _myGroups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final name = (g['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredGroups.isEmpty) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: _searchQuery.isNotEmpty
            ? lang.translate('no_results')
            : lang.translate('no_groups_message'),
        message: _searchQuery.isEmpty
            ? lang.translate('no_groups_subtitle')
            : null,
        action: _searchQuery.isEmpty
            ? ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.explore),
                label: Text(lang.translate('discover_groups')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                ),
              )
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: context.colors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: filteredGroups.length,
        itemBuilder: (context, index) {
          final group = filteredGroups[index];
          return _buildGroupItem(group, isMember: true);
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final lang = LanguageService.instance;
    final filteredGroups = _discoverGroups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final name = (g['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredGroups.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: _searchQuery.isNotEmpty
            ? lang.translate('no_results')
            : lang.translate('no_discover_groups'),
        message: _searchQuery.isEmpty
            ? lang.translate('all_groups_joined')
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGroups,
      color: context.colors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: filteredGroups.length,
        itemBuilder: (context, index) {
          final group = filteredGroups[index];
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
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
                          style: TextStyle(
                            color: context.colors.onSurface,
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
                            color: context.colors.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                color: context.colors.onSurface.withValues(alpha: 0.54),
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                lang.translate('private'),
                                style: TextStyle(
                                  color: context.colors.onSurface.withValues(alpha: 0.54),
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
                      style: TextStyle(
                        color: context.tokens.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: context.tokens.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$membersCount ${membersCount > 1 ? lang.translate('members') : lang.translate('member')}',
                        style: TextStyle(
                          color: context.tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.article,
                        color: context.tokens.textMuted,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$postsCount ${postsCount > 1 ? lang.translate('posts_count_plural') : lang.translate('posts_count')}',
                        style: TextStyle(
                          color: context.tokens.textMuted,
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
                      : context.colors.primary,
                  disabledBackgroundColor: hasPendingRequest
                      ? Colors.orange
                      : context.colors.onSurface.withValues(alpha: 0.24),
                  foregroundColor: context.colors.onPrimary,
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
    // Avatar de groupe carré arrondi (les personnes ont un avatar rond).
    const size = 56.0;
    final url = _api?.getImageUrl(avatar);
    final Widget logo = Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.contain),
    );
    final Widget image;
    if (url != null && url.endsWith('.svg')) {
      image = SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const SkeletonBox(height: size, width: size),
      );
    } else if (url != null) {
      image = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => logo,
      );
    } else {
      // Logo Militant par défaut pour les groupes sans image
      image = logo;
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: image);
  }
}
