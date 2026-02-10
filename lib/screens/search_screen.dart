import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<dynamic> _results = [];
  bool _isLoading = false;
  String _selectedTab = 'users'; // users, posts, groups

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results.clear());
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final data = await api.search(query, type: _selectedTab);

      setState(() {
        _results.clear();
        if (data['items'] != null && data['items'] is List) {
          _results.addAll(data['items'] as List);
        } else if (data['data'] != null && data['data'] is List) {
          _results.addAll(data['data'] as List);
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Color(0xFF888888)),
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: Column(
        children: [
          // Onglets
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                _buildTab('Utilisateurs', 'users'),
                _buildTab('Posts', 'posts'),
                _buildTab('Groupes', 'groups'),
              ],
            ),
          ),

          // Résultats
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                  )
                : _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[700]),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Recherchez des utilisateurs, posts ou groupes'
                              : 'Aucun résultat',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      return _buildResultItem(_results[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = value);
          if (_searchController.text.isNotEmpty) {
            _search(_searchController.text);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFFBE1E1E)
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFFBE1E1E)
                  : const Color(0xFF888888),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(dynamic item) {
    final type = item['type'] ?? _selectedTab;

    if (type == 'post' || type == 'posts') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['description'] ?? item['username'] ?? '',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              item['name'] ?? item['content'] ?? '',
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // User result
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFBE1E1E),
        child: Text(
          ((item['name'] ?? item['username'] ?? 'U')[0]).toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        item['name'] ?? item['username'] ?? 'Utilisateur',
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        item['description'] ?? item['bio'] ?? '',
        style: const TextStyle(color: Color(0xFF888888)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        // Navigate to profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Navigation vers le profil à venir')),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
