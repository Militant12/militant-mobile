import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final List<Post> _bookmarks = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!_hasMore) return;

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final data = await api.getBookmarks(page: _currentPage);
      
      setState(() {
        _bookmarks.addAll(data.map((p) => Post.fromJson(p)).toList());
        _hasMore = data.length >= 20;
        _currentPage++;
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

  Future<void> _refresh() async {
    setState(() {
      _bookmarks.clear();
      _currentPage = 1;
      _hasMore = true;
    });
    await _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Posts sauvegardés', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading && _bookmarks.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : _bookmarks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Color(0xFF888888)),
                      SizedBox(height: 16),
                      Text(
                        'Aucun post sauvegardé',
                        style: TextStyle(color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFFBE1E1E),
                  backgroundColor: const Color(0xFF1E1E1E),
                  child: ListView.builder(
                    itemCount: _bookmarks.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _bookmarks.length) {
                        _loadBookmarks();
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
                          ),
                        );
                      }
                      return PostCard(
                        post: _bookmarks[index],
                        onDeleted: () {
                          setState(() {
                            _bookmarks.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
