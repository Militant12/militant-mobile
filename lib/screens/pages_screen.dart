import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'page_detail_screen.dart';
import 'create_page_screen.dart';

class PagesScreen extends StatefulWidget {
  const PagesScreen({super.key});

  @override
  State<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends State<PagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<dynamic> _myPages = [];
  final List<dynamic> _followedPages = [];
  final List<dynamic> _discoverPages = [];
  bool _isLoading = false;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final myPages = await _api!.getPages();
      List<dynamic> followedPages = [];
      List<dynamic> discoverPages = [];
      try {
        followedPages = await _api!.getFollowedPages();
      } catch (_) {}
      try {
        discoverPages = await _api!.discoverPages();
      } catch (_) {}
      setState(() {
        _myPages.clear();
        _myPages.addAll(myPages);
        _followedPages.clear();
        _followedPages.addAll(followedPages);
        _discoverPages.clear();
        _discoverPages.addAll(discoverPages);
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error_loading')}: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _followPage(dynamic page) async {
    try {
      final lang = LanguageService.instance;
      final api = await ApiService.getInstance();
      await api.followPage(page['id']);
      _loadPages();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('following_page')} ${page['name']}')));
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
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          lang.translate('pages_title'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBE1E1E),
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag, size: 18),
                  const SizedBox(width: 6),
                  Text('${lang.translate('my_pages')} (${_myPages.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, size: 18),
                  const SizedBox(width: 6),
                  Text('${lang.translate('followed_pages')} (${_followedPages.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore, size: 18),
                  const SizedBox(width: 6),
                  Text(lang.translate('discover')),
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
              children: [
                _buildMyPagesTab(),
                _buildFollowedPagesTab(),
                _buildDiscoverTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePageScreen()),
          );
          if (result == true) {
            _loadPages();
          }
        },
        backgroundColor: const Color(0xFFBE1E1E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMyPagesTab() {
    final lang = LanguageService.instance;
    if (_myPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF888888)
                  : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('no_pages_message'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF888888)
                    : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang.translate('create_page_subtitle'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF666666)
                    : Colors.grey[500],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePageScreen()),
                );
                if (result == true) _loadPages();
              },
              icon: const Icon(Icons.add),
              label: Text(lang.translate('create_page_button')),
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
      onRefresh: _loadPages,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _myPages.length,
        itemBuilder: (context, index) {
          return _buildPageItem(_myPages[index], showBadge: lang.translate('admin_badge'));
        },
      ),
    );
  }

  Widget _buildFollowedPagesTab() {
    final lang = LanguageService.instance;
    if (_followedPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF888888)
                  : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('no_followed_pages'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF888888)
                    : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(2),
              icon: const Icon(Icons.explore),
              label: Text(lang.translate('discover_pages')),
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
      onRefresh: _loadPages,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _followedPages.length,
        itemBuilder: (context, index) {
          return _buildPageItem(_followedPages[index]);
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final lang = LanguageService.instance;
    if (_discoverPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF888888)
                  : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              lang.translate('no_discover_pages'),
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF888888)
                    : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPages,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _discoverPages.length,
        itemBuilder: (context, index) {
          final page = _discoverPages[index];
          final isFollowed =
              page['is_followed'] == 1 || page['is_followed'] == true;
          return _buildPageItem(page, showFollow: !isFollowed);
        },
      ),
    );
  }

  Widget _buildPageItem(
    dynamic page, {
    String? showBadge,
    bool showFollow = false,
  }) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = page['name'] ?? lang.translate('page');
    final description = page['description'] ?? '';
    final category = page['category'] ?? '';
    final followersCount =
        page['followers_count'] ?? page['follower_count'] ?? 0;
    final avatar = page['avatar'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PageDetailScreen(page: page)),
        ).then((_) => _loadPages());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildPageAvatar(avatar),
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
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showBadge != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBE1E1E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            showBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (category.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.grey[600],
                              fontSize: 11,
                            ),
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
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF888888)
                            : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: isDark ? const Color(0xFF888888) : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$followersCount ${followersCount > 1 ? lang.translate('followers_count_plural') : lang.translate('followers_count')}',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF888888) : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showFollow) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _followPage(page),
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
                child: Text(lang.translate('follow_button'), style: const TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageAvatar(String? avatar) {
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFBE1E1E).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.flag, color: Color(0xFFBE1E1E), size: 28),
        ),
      );
    }
  }
}
