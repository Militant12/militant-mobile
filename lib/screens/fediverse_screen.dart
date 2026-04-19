import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/fediverse_post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/fediverse_text.dart';
import '../widgets/fediverse_post_card.dart';
import 'fediverse_profile_screen.dart';

class FediverseScreen extends StatefulWidget {
  const FediverseScreen({super.key});

  @override
  State<FediverseScreen> createState() => _FediverseScreenState();
}

class _FediverseScreenState extends State<FediverseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);

    return ValueListenableBuilder<Locale>(
      valueListenable: lang,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            surfaceTintColor: Colors.transparent,
            title: Text(lang.translate('fediverse_title')),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.textTheme.bodyMedium?.color,
              tabs: [
                Tab(text: lang.translate('fediverse_feed_tab')),
                Tab(text: lang.translate('fediverse_profiles_tab')),
                Tab(text: lang.translate('following')),
                Tab(text: lang.translate('followers')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              _FediverseFeedTab(),
              _FediverseProfilesTab(),
              _FediverseAccountsTab(type: 'following'),
              _FediverseAccountsTab(type: 'followers'),
            ],
          ),
        );
      },
    );
  }
}

class _FediverseFeedTab extends StatefulWidget {
  const _FediverseFeedTab();

  @override
  State<_FediverseFeedTab> createState() => _FediverseFeedTabState();
}

class _FediverseFeedTabState extends State<_FediverseFeedTab> {
  final ScrollController _scrollController = ScrollController();
  final List<FediversePost> _posts = [];

  ApiService? _api;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _loadFeed();
    }
  }

  bool _isTimeoutLikeError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
        message.contains('time limit') ||
        message.contains('exceeded');
  }

  Future<void> _loadFeed({
    bool refresh = false,
    bool allowRefreshFallback = true,
  }) async {
    if (_isLoadingMore || (!_hasMore && !refresh)) {
      return;
    }

    if (refresh) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final api = _api ?? await ApiService.getInstance();
      final data = await api.getFediverseFeed(
        page: refresh ? 1 : _page,
        refresh: refresh,
      );

      final rawPosts = data['posts'] is List ? data['posts'] as List : const [];
      final posts = rawPosts
          .whereType<Map>()
          .map(
            (item) => FediversePost.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      final meta = data['meta'];
      final totalPages = meta is Map<String, dynamic>
          ? int.tryParse('${meta['total_pages'] ?? 1}') ?? 1
          : 1;
      final currentPage = refresh ? 1 : _page;

      if (!mounted) return;

      setState(() {
        _api = api;
        if (refresh) {
          _posts
            ..clear()
            ..addAll(posts);
        } else {
          _posts.addAll(posts);
        }
        _page = currentPage + 1;
        _hasMore = currentPage < totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (refresh && allowRefreshFallback && _isTimeoutLikeError(e)) {
        await _loadFeed(refresh: false, allowRefreshFallback: false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Le flux Fediverse distant est lent. Affichage du contenu deja synchronise.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (_isLoading && _posts.isEmpty) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    if (_error != null && _posts.isEmpty) {
      return _FediverseErrorState(
        message: _error!,
        onRetry: () => _loadFeed(refresh: true),
      );
    }

    return RefreshIndicator(
      color: accent,
      onRefresh: () => _loadFeed(refresh: true),
      child: _posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                _FediverseEmptyState(
                  icon: Icons.rss_feed_outlined,
                  message: LanguageService.instance.translate(
                    'fediverse_feed_empty',
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final post = _posts[index];
                return FediversePostCard(
                  post: post,
                  onProfileTap: () => _openProfile(
                    actorUrl: post.actorUrl,
                    initialProfile: {
                      'actor_url': post.actorUrl,
                      'username': post.username,
                      'display_name': post.displayName,
                      'domain': post.domain,
                      'handle': post.handle,
                      'avatar': post.avatar,
                      'profile_url': post.profileUrl,
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openProfile({
    required String actorUrl,
    Map<String, dynamic>? initialProfile,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FediverseProfileScreen(
          initialQuery: actorUrl,
          initialProfile: initialProfile,
        ),
      ),
    );
  }
}

class _FediverseProfilesTab extends StatefulWidget {
  const _FediverseProfilesTab();

  @override
  State<_FediverseProfilesTab> createState() => _FediverseProfilesTabState();
}

class _FediverseProfilesTabState extends State<_FediverseProfilesTab> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _followOverrides = {};
  Timer? _debounce;

  ApiService? _api;
  Map<String, dynamic>? _localProfile;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = await ApiService.getInstance();
      final profile = await api.getFediverseProfile();
      if (!mounted) return;
      setState(() {
        _api = api;
        _localProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _results = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final api = _api;
    if (api == null) return;

    setState(() => _isSearching = true);

    try {
      final data = await api.searchRemoteFediverse(query);
      final items = data['items'] is List ? data['items'] as List : const [];
      if (!mounted || _searchController.text.trim() != query) return;

      setState(() {
        _results = items
            .whereType<Map>()
            .map((item) => _normalizeAccount(Map<String, dynamic>.from(item)))
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> account) async {
    final api = _api;
    if (api == null) return;

    final actorUrl = (account['actor_url'] ?? '').toString();
    if (actorUrl.isEmpty) return;

    final isFollowing = _isFollowing(account);

    try {
      final response = isFollowing
          ? await api.unfollowRemoteFediverse(actorUrl, isActorUrl: true)
          : await api.followRemoteFediverse(actorUrl, isActorUrl: true);

      if (!mounted) return;

      final nextFollowing = !isFollowing;
      _followOverrides[actorUrl] = nextFollowing;
      final updated = Map<String, dynamic>.from(account)
        ..['is_following'] = nextFollowing;

      if (response['profile'] is Map<String, dynamic>) {
        updated.addAll(
          _normalizeAccount(
            Map<String, dynamic>.from(response['profile'] as Map),
            fallback: updated,
          ),
        );
      }

      _updateAccount(updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing
                ? LanguageService.instance.translate('fediverse_unfollow')
                : LanguageService.instance.translate('subscription_success'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _updateAccount(Map<String, dynamic> updated) {
    final actorUrl = (updated['actor_url'] ?? '').toString();
    if (actorUrl.isEmpty) {
      return;
    }

    final existing = _results.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['actor_url'] == actorUrl,
      orElse: () => null,
    );
    final normalized = _normalizeAccount(updated, fallback: existing);
    _followOverrides[actorUrl] = _isFollowing(normalized);

    setState(() {
      _results = _results.map((item) {
        if (item['actor_url'] == actorUrl) {
          return Map<String, dynamic>.from(item)..addAll(normalized);
        }
        return item;
      }).toList();
    });
  }

  bool _isFollowing(Map<String, dynamic> account) {
    final value = account['is_following'];
    return value == true || value == 1 || value == '1';
  }

  Map<String, dynamic> _normalizeAccount(
    Map<String, dynamic> account, {
    Map<String, dynamic>? fallback,
  }) {
    final normalized = <String, dynamic>{};

    if (fallback != null) {
      normalized.addAll(fallback);
    }
    normalized.addAll(account);

    final actorUrl = (normalized['actor_url'] ?? '').toString();
    final override = actorUrl.isNotEmpty ? _followOverrides[actorUrl] : null;

    if (override != null) {
      normalized['is_following'] = override;
    } else if (!_hasFollowingValue(account) &&
        fallback != null &&
        _hasFollowingValue(fallback)) {
      normalized['is_following'] = _isFollowing(fallback);
    }

    return normalized;
  }

  bool _hasFollowingValue(Map<String, dynamic> account) {
    if (!account.containsKey('is_following')) {
      return false;
    }

    final value = account['is_following'];
    if (value == null) {
      return false;
    }

    return value.toString().trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (_isLoading && _localProfile == null) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    if (_error != null && _localProfile == null) {
      return _FediverseErrorState(message: _error!, onRetry: _loadInitial);
    }

    final lang = LanguageService.instance;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return RefreshIndicator(
      color: accent,
      onRefresh: _loadInitial,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildLocalIdentityCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('fediverse_profiles_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.translate('fediverse_search_helper'),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: lang.translate('fediverse_search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: hasQuery
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: accent)),
            )
          else if (!hasQuery)
            _FediverseEmptyState(
              icon: Icons.travel_explore_outlined,
              message: lang.translate('fediverse_search_helper'),
            )
          else if (_results.isEmpty)
            _FediverseEmptyState(
              icon: Icons.person_search_outlined,
              message: lang.translate('no_results'),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                lang.translate('fediverse_search_results'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._results.map(
              (account) => _FediverseAccountCard(
                account: account,
                onTap: () => _openProfile(account),
                onToggleFollow: () => _toggleFollow(account),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalIdentityCard() {
    final profile = _localProfile ?? const <String, dynamic>{};
    final handle =
        (profile['fediverse_handle'] ?? '@${profile['username'] ?? ''}')
            .toString();
    final followersCount =
        int.tryParse('${profile['followers_count'] ?? 0}') ?? 0;
    final followingCount =
        int.tryParse('${profile['following_count'] ?? 0}') ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LanguageService.instance.translate('fediverse_local_identity'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              handle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildCounterChip(
                  '${LanguageService.instance.translate('followers')}: $followersCount',
                ),
                _buildCounterChip(
                  '${LanguageService.instance.translate('following')}: $followingCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterChip(String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Text(label),
    );
  }

  Future<void> _openProfile(Map<String, dynamic> account) async {
    final query = (account['actor_url'] ?? account['handle'] ?? '').toString();
    if (query.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FediverseProfileScreen(
          initialQuery: query,
          initialProfile: account,
          onProfileUpdated: _updateAccount,
        ),
      ),
    );
  }
}

class _FediverseAccountsTab extends StatefulWidget {
  final String type;

  const _FediverseAccountsTab({required this.type});

  @override
  State<_FediverseAccountsTab> createState() => _FediverseAccountsTabState();
}

class _FediverseAccountsTabState extends State<_FediverseAccountsTab> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _accounts = [];
  final Map<String, bool> _followOverrides = {};

  ApiService? _api;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String? _processingActorUrl;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadAccounts(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 250 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts({bool refresh = false}) async {
    if (_isLoadingMore || (!_hasMore && !refresh)) {
      return;
    }

    if (refresh) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final api = _api ?? await ApiService.getInstance();
      final data = await api.getFediverseConnections(
        type: widget.type,
        page: refresh ? 1 : _page,
      );

      final key = widget.type == 'following' ? 'following' : 'followers';
      final rawItems = data[key] is List ? data[key] as List : const [];
      final items = rawItems
          .whereType<Map>()
          .map((item) => _normalizeAccount(Map<String, dynamic>.from(item)))
          .toList();

      final meta = data['meta'];
      final totalPages = meta is Map<String, dynamic>
          ? int.tryParse('${meta['total_pages'] ?? 1}') ?? 1
          : 1;
      final currentPage = refresh ? 1 : _page;

      if (!mounted) return;

      setState(() {
        _api = api;
        if (refresh) {
          _accounts
            ..clear()
            ..addAll(items);
        } else {
          _accounts.addAll(items);
        }
        _page = currentPage + 1;
        _hasMore = currentPage < totalPages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> account) async {
    final api = _api;
    if (api == null) return;

    final actorUrl = (account['actor_url'] ?? '').toString();
    if (actorUrl.isEmpty || _processingActorUrl == actorUrl) return;

    final isFollowing = _isFollowing(account);
    setState(() => _processingActorUrl = actorUrl);

    try {
      final response = isFollowing
          ? await api.unfollowRemoteFediverse(actorUrl, isActorUrl: true)
          : await api.followRemoteFediverse(actorUrl, isActorUrl: true);

      if (!mounted) return;

      final nextFollowing = !isFollowing;
      _followOverrides[actorUrl] = nextFollowing;
      final updated = Map<String, dynamic>.from(account)
        ..['is_following'] = nextFollowing;
      if (response['profile'] is Map<String, dynamic>) {
        updated.addAll(
          _normalizeAccount(
            Map<String, dynamic>.from(response['profile'] as Map),
            fallback: updated,
          ),
        );
      }

      setState(() {
        if (widget.type == 'following' && !_isFollowing(updated)) {
          _accounts.removeWhere((item) => item['actor_url'] == actorUrl);
        } else {
          _replaceAccount(updated);
        }
        _processingActorUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFollowing
                ? LanguageService.instance.translate('fediverse_unfollow')
                : LanguageService.instance.translate('subscription_success'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingActorUrl = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _replaceAccount(Map<String, dynamic> updated) {
    final actorUrl = (updated['actor_url'] ?? '').toString();
    if (actorUrl.isEmpty) {
      return;
    }

    final index = _accounts.indexWhere((item) => item['actor_url'] == actorUrl);
    final existing = index >= 0 ? _accounts[index] : null;
    final normalized = _normalizeAccount(updated, fallback: existing);
    _followOverrides[actorUrl] = _isFollowing(normalized);

    if (index >= 0) {
      _accounts[index] = Map<String, dynamic>.from(_accounts[index])
        ..addAll(normalized);
    }
  }

  bool _isFollowing(Map<String, dynamic> account) {
    final value = account['is_following'];
    return value == true || value == 1 || value == '1';
  }

  Map<String, dynamic> _normalizeAccount(
    Map<String, dynamic> account, {
    Map<String, dynamic>? fallback,
  }) {
    final normalized = <String, dynamic>{};

    if (fallback != null) {
      normalized.addAll(fallback);
    }
    normalized.addAll(account);

    final actorUrl = (normalized['actor_url'] ?? '').toString();
    final override = actorUrl.isNotEmpty ? _followOverrides[actorUrl] : null;

    if (override != null) {
      normalized['is_following'] = override;
    } else if (!_hasFollowingValue(account) &&
        fallback != null &&
        _hasFollowingValue(fallback)) {
      normalized['is_following'] = _isFollowing(fallback);
    }

    return normalized;
  }

  bool _hasFollowingValue(Map<String, dynamic> account) {
    if (!account.containsKey('is_following')) {
      return false;
    }

    final value = account['is_following'];
    if (value == null) {
      return false;
    }

    return value.toString().trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    if (_isLoading && _accounts.isEmpty) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    if (_error != null && _accounts.isEmpty) {
      return _FediverseErrorState(
        message: _error!,
        onRetry: () => _loadAccounts(refresh: true),
      );
    }

    final emptyKey = widget.type == 'following'
        ? 'fediverse_following_empty'
        : 'fediverse_followers_empty';

    return RefreshIndicator(
      color: accent,
      onRefresh: () => _loadAccounts(refresh: true),
      child: _accounts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                _FediverseEmptyState(
                  icon: widget.type == 'following'
                      ? Icons.people_outline
                      : Icons.group_outlined,
                  message: LanguageService.instance.translate(emptyKey),
                ),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _accounts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final account = _accounts[index];
                final actorUrl = (account['actor_url'] ?? '').toString();

                return _FediverseAccountCard(
                  account: account,
                  onTap: () => _openProfile(account),
                  onToggleFollow: () => _toggleFollow(account),
                  isProcessing: _processingActorUrl == actorUrl,
                );
              },
            ),
    );
  }

  Future<void> _openProfile(Map<String, dynamic> account) async {
    final query = (account['actor_url'] ?? account['handle'] ?? '').toString();
    if (query.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FediverseProfileScreen(
          initialQuery: query,
          initialProfile: account,
          onProfileUpdated: (updated) {
            if (!mounted) return;
            final normalized = _normalizeAccount(updated);
            setState(() {
              if (widget.type == 'following' && !_isFollowing(normalized)) {
                _accounts.removeWhere(
                  (item) => item['actor_url'] == normalized['actor_url'],
                );
              } else {
                _replaceAccount(normalized);
              }
            });
          },
        ),
      ),
    );
  }
}

class _FediverseAccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;
  final bool isProcessing;

  const _FediverseAccountCard({
    required this.account,
    required this.onTap,
    required this.onToggleFollow,
    this.isProcessing = false,
  });

  bool get _isFollowing {
    final value = account['is_following'];
    return value == true || value == 1 || value == '1';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = (account['avatar'] ?? '').toString();
    final displayName = (account['display_name'] ?? account['username'] ?? '')
        .toString();
    final handle = (account['handle'] ?? '@${account['username'] ?? ''}')
        .toString();
    final summary = fediverseHtmlToText(account['summary']?.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: SvgPicture.asset('assets/logo.svg'),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _isFollowing
                  ? OutlinedButton(
                      onPressed: isProcessing ? null : onToggleFollow,
                      child: Text(
                        LanguageService.instance.translate(
                          'fediverse_unfollow',
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isProcessing ? null : onToggleFollow,
                      child: Text(LanguageService.instance.translate('follow')),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FediverseErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FediverseErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hub_outlined, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              LanguageService.instance.translate('fediverse_error_load'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(LanguageService.instance.translate('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FediverseEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _FediverseEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 64, color: theme.disabledColor),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
      ],
    );
  }
}
