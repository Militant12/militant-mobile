import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_bar.dart';
import 'create_post_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0; // Key to force refresh after post creation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance,
      builder: (context, locale, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(LanguageService.instance.translate('app_title')),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: LanguageService.instance.translate('discover')),
                Tab(text: LanguageService.instance.translate('subscriptions')),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MessagesScreen()),
                  );
                },
              ),
            ],
          ),
          body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Découvrir (Global)
          FeedList(key: ValueKey('global_$_refreshKey'), feedType: 'global'),
          // Tab 2: Abonnements (Following)
          FeedList(
            key: ValueKey('following_$_refreshKey'),
            feedType: 'following',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_feed',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
          if (result == true) {
            // Force refresh of feeds
            if (mounted) {
              setState(() {
                _refreshKey++;
              });
            }
          }
        },
        child: const Icon(Icons.add),
      ),
        );
      },
    );
  }
}

class FeedList extends StatefulWidget {
  final String feedType;

  const FeedList({super.key, required this.feedType});

  @override
  State<FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<FeedList>
    with AutomaticKeepAliveClientMixin {
  final List<Post> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true; // Keep tab state when switching

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPosts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadPosts();
      }
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        if (refresh) {
          _posts.clear();
          _currentPage = 1;
          _hasMore = true;
        }
      });
    }

    try {
      final api = await ApiService.getInstance();
      final postsData = await api
          .getPosts(page: _currentPage, feedType: widget.feedType)
          .timeout(const Duration(seconds: 10), onTimeout: () => []);

      if (mounted) {
        setState(() {
          final newPosts = postsData.map((p) => Post.fromJson(p)).toList();

          // Avoid duplicates if API returns same posts
          final existingIds = _posts.map((p) => p.id).toSet();
          final uniqueNewPosts = newPosts
              .where((p) => !existingIds.contains(p.id))
              .toList();

          _posts.addAll(uniqueNewPosts);

          if (newPosts.isEmpty) {
            _hasMore = false;
          } else {
            _currentPage++;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // SnackBar might annoy user if network is flaky
        print('Error loading posts: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive

    return RefreshIndicator(
      onRefresh: () => _loadPosts(refresh: true),
      child: Column(
        children: [
          const StoriesBar(),
          Expanded(
            child: _posts.isEmpty && !_isLoading
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Center(
                        child: Text(
                          widget.feedType == 'following'
                              ? "Aucun post dans vos abonnements.\nAbonnez-vous ou allez dans 'Découvrir' !"
                              : "Aucun post disponible pour le moment.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : const SizedBox.shrink();
                      }
                      final post = _posts[index];
                      return PostCard(
                        post: post,
                        onDeleted: () {
                          setState(() {
                            _posts.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
