import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_bar.dart';
import 'create_post_screen.dart';
import 'search_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';

const _feedInterestStorageKey = 'feed_interests';

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
                Tab(
                  text: LanguageService.instance.translate('feed_tab_for_you'),
                ),
                Tab(
                  text: LanguageService.instance.translate(
                    'feed_tab_following',
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
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
                    MaterialPageRoute(
                      builder: (context) => const MessagesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Pour toi (global + priorisation locale)
              FeedList(
                key: ValueKey('global_$_refreshKey'),
                feedType: 'global',
              ),
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
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
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
  bool _isLoadingPreferences = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  List<String> _interests = [];
  String? _mainCause;

  @override
  bool get wantKeepAlive => true; // Keep tab state when switching

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeFeed();
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

  Future<void> _initializeFeed() async {
    if (widget.feedType == 'global') {
      await _loadPersonalization();
    }
    await _loadPosts();
  }

  Future<void> _loadPersonalization() async {
    if (!mounted) return;
    setState(() => _isLoadingPreferences = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedInterests = prefs.getStringList(_feedInterestStorageKey) ?? [];

      String? cause;
      try {
        final api = await ApiService.getInstance();
        final profile = await api.getProfile();
        final rawCause = profile['cause']?.toString().trim();
        if (rawCause != null && rawCause.isNotEmpty) {
          cause = rawCause;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _interests = savedInterests;
        _mainCause = cause;
        _isLoadingPreferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPreferences = false);
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
          _applyInterestRankingInPlace();

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
        debugPrint('Error loading posts: $e');
      }
    }
  }

  Future<void> _saveInterests(List<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_feedInterestStorageKey, interests);
    if (!mounted) return;
    setState(() {
      _interests = interests;
      _applyInterestRankingInPlace();
    });
  }

  List<String> _rankingTerms() {
    final normalized = <String>{};

    void addValue(String? value) {
      final raw = value?.trim();
      if (raw == null || raw.isEmpty) return;
      normalized.add(raw.toLowerCase());
      for (final part in raw.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        if (part.length >= 3) {
          normalized.add(part);
        }
      }
    }

    for (final interest in _interests) {
      addValue(interest);
    }
    addValue(_mainCause);

    return normalized.toList();
  }

  List<String> _contentDrivenSuggestions() {
    final suggestions = <String>{};

    for (final post in _posts) {
      for (final tag in post.tags) {
        final clean = tag.trim();
        if (clean.length >= 2) {
          suggestions.add(clean);
        }
      }
    }

    for (final selected in _interests) {
      suggestions.removeWhere(
        (tag) => tag.toLowerCase() == selected.trim().toLowerCase(),
      );
    }

    final sorted = suggestions.toList()..sort((a, b) => a.compareTo(b));
    return sorted.take(24).toList();
  }

  int _scorePost(Post post, List<String> rankingTerms) {
    if (rankingTerms.isEmpty) return 0;

    final haystack = [
      post.content,
      post.username,
      if (post.sharedByUsername != null) post.sharedByUsername!,
      ...post.tags.map((tag) => '#$tag'),
    ].join(' ').toLowerCase();

    var score = 0;
    for (final term in rankingTerms) {
      if (!haystack.contains(term)) continue;
      score += term.contains(' ') ? 6 : 2;
    }

    return score;
  }

  void _applyInterestRankingInPlace() {
    if (widget.feedType != 'global' || _posts.length < 2) {
      return;
    }

    final rankingTerms = _rankingTerms();
    if (rankingTerms.isEmpty) {
      _posts.sort((a, b) => b.feedDate.compareTo(a.feedDate));
      return;
    }

    _posts.sort((a, b) {
      final scoreDiff =
          _scorePost(b, rankingTerms).compareTo(_scorePost(a, rankingTerms));
      if (scoreDiff != 0) {
        return scoreDiff;
      }
      return b.feedDate.compareTo(a.feedDate);
    });
  }

  Future<void> _openInterestsSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InterestEditorSheet(
          initialInterests: _interests,
          suggestions: _contentDrivenSuggestions(),
          title: LanguageService.instance.translate('feed_interests_title'),
          hint: LanguageService.instance.translate('feed_interests_hint'),
          emptyText: LanguageService.instance.translate('feed_interests_empty'),
          suggestionsTitle: LanguageService.instance.translate(
            'feed_interests_suggestions',
          ),
          cancelLabel: LanguageService.instance.translate('cancel'),
          saveLabel: LanguageService.instance.translate('save'),
        );
      },
    );

    if (result != null) {
      await _saveInterests(result);
    }
  }
  
  Widget _buildInterestHeader() {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = const Color(0xFFBE1E1E);
    final chips = <Widget>[];

    if (_mainCause != null && _mainCause!.isNotEmpty) {
      chips.add(
        _buildInterestPill(
          icon: Icons.flag_outlined,
          label: _mainCause!,
          highlighted: true,
        ),
      );
    }

    chips.addAll(
      _interests.map(
        (interest) => _buildInterestPill(
          icon: Icons.local_offer_outlined,
          label: interest,
        ),
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.12 : 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.tune, color: accent, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.translate('feed_tab_for_you'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                if (_isLoadingPreferences)
                  Text(
                    lang.translate('loading'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  )
                else
                  Text(
                    chips.isEmpty
                        ? lang.translate('feed_interests_hint')
                        : _mainCause != null && _interests.isEmpty
                        ? _mainCause!
                        : '${chips.length} tags actifs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _openInterestsSheet,
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.1),
              foregroundColor: accent,
              minimumSize: const Size(34, 34),
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestPill({
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    final theme = Theme.of(context);
    final accent = const Color(0xFFBE1E1E);
    final backgroundColor = highlighted
        ? accent.withValues(alpha: 0.14)
        : theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);

    final borderColor = highlighted
        ? accent.withValues(alpha: 0.24)
        : theme.dividerColor.withValues(alpha: 0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: highlighted
                ? accent
                : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for KeepAlive

    final headerCount = widget.feedType == 'global' ? 2 : 1;
    final listItemCount =
        headerCount + (_posts.isEmpty ? 1 : _posts.length) + 1;

    return RefreshIndicator(
      onRefresh: () => _loadPosts(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: listItemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const StoriesBar();
          }

          if (widget.feedType == 'global' && index == 1) {
            return _buildInterestHeader();
          }

          final postStartIndex = headerCount;
          final loaderIndex = postStartIndex + (_posts.isEmpty ? 1 : _posts.length);

          if (_posts.isEmpty && index == postStartIndex) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.52,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.feedType == 'following'
                        ? LanguageService.instance.translate(
                            'empty_feed_following',
                          )
                        : LanguageService.instance.translate('empty_feed_global'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            );
          }

          if (index == loaderIndex) {
            return _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox(height: 12);
          }

          final postIndex = index - postStartIndex;
          final post = _posts[postIndex];
          return PostCard(
            post: post,
            onDeleted: () {
              setState(() {
                _posts.removeAt(postIndex);
              });
            },
          );
        },
      ),
    );
  }
}

class _InterestEditorSheet extends StatefulWidget {
  final List<String> initialInterests;
  final List<String> suggestions;
  final String title;
  final String hint;
  final String emptyText;
  final String suggestionsTitle;
  final String cancelLabel;
  final String saveLabel;

  const _InterestEditorSheet({
    required this.initialInterests,
    required this.suggestions,
    required this.title,
    required this.hint,
    required this.emptyText,
    required this.suggestionsTitle,
    required this.cancelLabel,
    required this.saveLabel,
  });

  @override
  State<_InterestEditorSheet> createState() => _InterestEditorSheetState();
}

class _InterestEditorSheetState extends State<_InterestEditorSheet> {
  late final TextEditingController _controller;
  late List<String> _draft;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _draft = List<String>.from(widget.initialInterests);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _containsInterest(String value) {
    final normalized = _normalize(value).toLowerCase();
    return _draft.any((item) => item.toLowerCase() == normalized);
  }

  void _addInterest(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty || _containsInterest(normalized)) {
      _controller.clear();
      return;
    }

    setState(() {
      _draft.add(normalized);
      _controller.clear();
    });
  }

  void _toggleSuggestion(String interest, bool selected) {
    setState(() {
      if (selected) {
        if (!_containsInterest(interest)) {
          _draft.add(interest);
        }
      } else {
        _draft.removeWhere(
          (item) => item.toLowerCase() == interest.toLowerCase(),
        );
      }
    });
  }

  void _save() {
    final clean = _draft
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    Navigator.pop(context, clean);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const selectedColor = Color(0xFFBE1E1E);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF171717) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addInterest,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => _addInterest(_controller.text),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_draft.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _draft
                                .map(
                                  (interest) => InputChip(
                                    label: Text(interest),
                                    labelStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    deleteIconColor: Colors.white,
                                    selected: true,
                                    showCheckmark: false,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.transparent,
                                    selectedColor: selectedColor.withValues(
                                      alpha: 0.88,
                                    ),
                                    side: BorderSide(
                                      color: selectedColor.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _draft.remove(interest);
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          widget.suggestionsTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.suggestions.isEmpty)
                          Text(
                            widget.emptyText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.suggestions.map((interest) {
                              final isSelected = _containsInterest(interest);
                              return FilterChip(
                                label: Text('#$interest'),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : theme.textTheme.bodyMedium?.color,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                selected: isSelected,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.transparent,
                                selectedColor: selectedColor.withValues(
                                  alpha: 0.88,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.9)
                                      : theme.dividerColor.withValues(
                                          alpha: 0.28,
                                        ),
                                ),
                                onSelected: (selected) {
                                  _toggleSuggestion(interest, selected);
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.cancelLabel),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _save,
                      child: Text(widget.saveLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
