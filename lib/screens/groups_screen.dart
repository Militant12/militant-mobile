import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
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
      setState(() {
        _myGroups.clear();
        _myGroups.addAll(myGroups);
        _discoverGroups.clear();
        _discoverGroups.addAll(discoverGroups);
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

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Row(
            children: [
              Icon(Icons.group_add, color: Color(0xFFBE1E1E)),
              SizedBox(width: 8),
              Text('Créer un groupe', style: TextStyle(color: Colors.white)),
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
                    labelText: 'Nom du groupe *',
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
                    labelText: 'Description',
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
                  title: const Text(
                    'Groupe privé',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Seuls les membres approuvés peuvent voir le contenu',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: isPrivate,
                  activeColor: const Color(0xFFBE1E1E),
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                  contentPadding: EdgeInsets.zero,
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
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);
                try {
                  final api = await ApiService.getInstance();
                  final result = await api.createGroup(
                    name: nameController.text.trim(),
                    description: descController.text.trim(),
                    isPrivate: isPrivate,
                  );
                  _loadGroups();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Groupe créé !')),
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
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(dynamic group) async {
    try {
      final api = await ApiService.getInstance();
      await api.joinGroup(group['id']);
      _loadGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vous avez rejoint ${group['name']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Groupes', style: TextStyle(color: Colors.white)),
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
                  Text('Mes groupes (${_myGroups.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore, size: 18),
                  const SizedBox(width: 6),
                  const Text('Découvrir'),
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
            const Text(
              'Aucun groupe',
              style: TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rejoignez ou créez un groupe !',
              style: TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.explore),
              label: const Text('Découvrir des groupes'),
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
    if (_discoverGroups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Color(0xFF888888)),
            SizedBox(height: 16),
            Text(
              'Aucun groupe à découvrir',
              style: TextStyle(color: Color(0xFF888888), fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Vous êtes membre de tous les groupes !',
              style: TextStyle(color: Color(0xFF666666), fontSize: 14),
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
    final name = group['name'] ?? 'Groupe';
    final description = group['description'] ?? '';
    final membersCount = group['members_count'] ?? 0;
    final postsCount = group['posts_count'] ?? 0;
    final avatar = group['avatar'];
    final privacy = group['privacy'] ?? 'public';

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
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, color: Colors.white54, size: 12),
                              SizedBox(width: 2),
                              Text(
                                'Privé',
                                style: TextStyle(
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
                      overflow: TextOverflow.ellipsis,
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
                        '$membersCount membre${membersCount > 1 ? 's' : ''}',
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
                        '$postsCount post${postsCount > 1 ? 's' : ''}',
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
                onPressed: () => _joinGroup(group),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Rejoindre', style: TextStyle(fontSize: 13)),
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
