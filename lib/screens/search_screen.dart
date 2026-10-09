import 'package:flutter/material.dart';
import '../theme/theme_context.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/linkable_text.dart';
import '../widgets/militant_badge.dart';
import '../widgets/technician_badge.dart';
import 'chat_screen.dart';
import '../widgets/common/common.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<dynamic> _results = [];
  bool _isLoading = false;
  Object? _error;
  String _selectedTab = 'users'; // users, posts

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = await ApiService.getInstance();
      final data = await api.search(query, type: _selectedTab);

      if (!mounted) return;
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
        setState(() {
          _results.clear();
          _error = e;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    
    return ValueListenableBuilder<Locale>(
      valueListenable: lang,
      builder: (context, locale, child) {
        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: context.colors.onSurface),
              decoration: InputDecoration(
                hintText: lang.translate('search_hint'),
                hintStyle: TextStyle(color: context.tokens.textMuted),
                border: InputBorder.none,
              ),
              onChanged: _search,
            ),
          ),
          body: Column(
        children: [
          // Onglets
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
            ),
            child: Row(
              children: [
                _buildTab(lang.translate('users_tab'), 'users'),
                _buildTab(lang.translate('posts_tab'), 'posts'),
              ],
            ),
          ),

          // Résultats
          Expanded(
            child: _isLoading
                ? const SkeletonList()
                : _error != null
                ? ErrorState(
                    error: _error,
                    onRetry: () => _search(_searchController.text),
                  )
                : _results.isEmpty
                ? EmptyState(
                    icon: Icons.search,
                    title: _searchController.text.isEmpty
                        ? lang.translate('search_users_posts')
                        : lang.translate('no_results'),
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
      },
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
                    ? context.colors.primary
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
                  ? context.colors.primary
                  : context.tokens.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(dynamic item) {
    if (_selectedTab == 'posts') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: item['id']),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FutureBuilder<ApiService>(
                    future: ApiService.getInstance(),
                    builder: (context, snapshot) => AppAvatar(
                      url: snapshot.data?.getImageUrl(item['user_avatar']),
                      semanticLabel: item['username']?.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '@${item['username'] ?? LanguageService.instance.translate('unknown_user')}',
                            style: TextStyle(
                              color: context.colors.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item['militant_badge'] != null) ...[
                            const SizedBox(width: 4),
                            MilitantBadge(badgeId: item['militant_badge'], size: 16),
                          ],
                          if (item['is_militant_technician'] == true || item['is_militant_technician'] == 1 || item['is_militant_technician'] == '1') ...[
                            const SizedBox(width: 4),
                            const TechnicianBadge(size: 16),
                          ],
                          if (item['is_moderator'] == true || item['is_moderator'] == 1 || item['is_moderator'] == '1') ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: LanguageService.instance.translate(
                                'post_elected_moderator',
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: context.colors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.shield,
                                  size: 14,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        item['created_at'] != null
                            ? _formatDate(item['created_at'])
                            : '',
                        style: TextStyle(
                          color: context.tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinkableText(
                text: item['content'] ?? '',
                style: TextStyle(color: context.colors.onSurface, fontSize: 15),
              ),
              if (item['media_url'] != null &&
                  item['media_url'].isNotEmpty) ...[
                const SizedBox(height: 12),
                FutureBuilder<ApiService>(
                  future: ApiService.getInstance(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final mediaUrl = snapshot.data!.getImageUrl(
                      item['media_url'],
                    );
                    if (mediaUrl == null) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        mediaUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SkeletonBox(
                            height: 200,
                            width: double.infinity,
                            radius: 0,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ],
              if (item['image'] != null && item['image'].isNotEmpty) ...[
                const SizedBox(height: 12),
                FutureBuilder<ApiService>(
                  future: ApiService.getInstance(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final imageUrl = snapshot.data!.getImageUrl(item['image']);
                    if (imageUrl == null) return const SizedBox.shrink();
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SkeletonBox(
                            height: 200,
                            width: double.infinity,
                            radius: 0,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    // User or Group result
    final lang = LanguageService.instance;
    final name = item['name'] ?? item['username'] ?? lang.translate('unknown_user');
    final subtitle = item['bio'] ?? item['description'] ?? '';
    final avatarUrl = item['avatar'];

    return ListTile(
      leading: FutureBuilder<ApiService>(
        future: ApiService.getInstance(),
        builder: (context, snapshot) => AppAvatar(
          url: snapshot.data?.getImageUrl(avatarUrl),
          semanticLabel: name,
          online:
              _selectedTab == 'users' &&
              (item['is_online'] == 1 || item['is_online'] == true),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (item['militant_badge'] != null) ...[
            const SizedBox(width: 4),
            MilitantBadge(badgeId: item['militant_badge'], size: 16),
          ],
          if (item['is_militant_technician'] == true || item['is_militant_technician'] == 1 || item['is_militant_technician'] == '1') ...[
            const SizedBox(width: 4),
            const TechnicianBadge(size: 16),
          ],
          if (item['is_moderator'] == true || item['is_moderator'] == 1 || item['is_moderator'] == '1') ...[
            const SizedBox(width: 4),
            Tooltip(
              message: LanguageService.instance.translate(
                'post_elected_moderator',
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.shield,
                  size: 14,
                  color: context.colors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(color: context.tokens.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () {
        if (_selectedTab == 'users') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: item['id']),
            ),
          );
        }
      },
      trailing:
          _selectedTab == 'users' &&
              (item['is_friend'] == 1 || item['is_friend'] == true)
          ? IconButton(
              tooltip: lang.translate('action_messages'),
              icon: Icon(Icons.message, color: context.colors.primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      userId: item['id'],
                      username: item['username'] ?? item['name'],
                      avatar: item['avatar'] ?? item['image'],
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  String _formatDate(String dateStr) {
    try {
      final lang = LanguageService.instance;
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return lang.translate('just_now');
      if (diff.inMinutes < 60) return '${diff.inMinutes}${lang.translate('minutes_short')}';
      if (diff.inHours < 24) return '${diff.inHours}${lang.translate('hours_short')}';
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
