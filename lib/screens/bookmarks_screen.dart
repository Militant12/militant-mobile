import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../theme/theme_context.dart';
import '../widgets/common/common.dart';
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
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = await ApiService.getInstance();
      final data = await api.getBookmarks(page: _currentPage);
      if (!mounted) return;
      setState(() {
        _bookmarks.addAll(data.map((p) => Post.fromJson(p)).toList());
        _hasMore = data.length >= 20;
        _currentPage++;
      });
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildBody(LanguageService lang) {
    if (_bookmarks.isEmpty) {
      if (_isLoading) {
        return SkeletonPulse(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: const [PostCardSkeleton(), PostCardSkeleton()],
          ),
        );
      }
      if (_error != null) {
        return ErrorState(error: _error, onRetry: _refresh);
      }
      return EmptyState(
        icon: Icons.bookmark_border,
        title: lang.translate('bookmarks_empty'),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.colors.primary,
      child: ListView.builder(
        itemCount: _bookmarks.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _bookmarks.length) {
            if (_error != null) {
              // Pas de relance automatique en boucle : l'utilisateur relance.
              return Center(
                child: TextButton.icon(
                  onPressed: _loadBookmarks,
                  icon: const Icon(Icons.refresh),
                  label: Text(lang.translate('retry')),
                ),
              );
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isLoading && _error == null) _loadBookmarks();
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: AppLoader(size: 28),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('saved_posts_title'))),
      body: _buildBody(lang),
    );
  }
}
