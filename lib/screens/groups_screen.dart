import 'package:flutter/material.dart';
import '../services/api_service.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<dynamic> _groups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final groups = await api.getGroups();
      setState(() {
        _groups.clear();
        _groups.addAll(groups);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Groupes', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _groups.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: Color(0xFF888888),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucun groupe',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  color: const Color(0xFFBE1E1E),
                  child: ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return _buildGroupItem(group);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Création de groupe à venir')),
          );
        },
        backgroundColor: const Color(0xFFBE1E1E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupItem(dynamic group) {
    final name = group['name'] ?? 'Groupe';
    final description = group['description'] ?? '';
    final membersCount = group['members_count'] ?? 0;

    return InkWell(
      onTap: () {
        // TODO: Ouvrir le groupe
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Détails du groupe à venir')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFBE1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.group,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                  const SizedBox(height: 4),
                  Text(
                    '$membersCount membres',
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
