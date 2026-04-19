import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';
import '../widgets/linkable_text.dart';
import '../widgets/militant_badge.dart';
import '../widgets/technician_badge.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<dynamic> _results = [];
  bool _isLoading = false;
  String _selectedTab = 'users'; // users, posts

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
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    
    return ValueListenableBuilder<Locale>(
      valueListenable: lang,
      builder: (context, locale, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1E1E),
            title: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: lang.translate('search_hint'),
                hintStyle: const TextStyle(color: Color(0xFF888888)),
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
                _buildTab(lang.translate('users_tab'), 'users'),
                _buildTab(lang.translate('posts_tab'), 'posts'),
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
                              ? lang.translate('search_users_posts')
                              : lang.translate('no_results'),
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
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FutureBuilder<ApiService>(
                    future: ApiService.getInstance(),
                    builder: (context, snapshot) {
                      final avatarUrl = snapshot.hasData
                          ? snapshot.data!.getImageUrl(item['user_avatar'])
                          : null;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          avatarUrl ?? '',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(2),
                            child: SvgPicture.asset('assets/logo.svg'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '@${item['username'] ?? LanguageService.instance.translate('unknown_user')}',
                            style: const TextStyle(
                              color: Colors.white,
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
                        ],
                      ),
                      Text(
                        item['created_at'] != null
                            ? _formatDate(item['created_at'])
                            : '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinkableText(
                text: item['content'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15),
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
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[900],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFBE1E1E),
                              ),
                            ),
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
                          return Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey[900],
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFBE1E1E),
                              ),
                            ),
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
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: SvgPicture.asset('assets/logo.svg'),
            );
          }

          final url = snapshot.data!.getImageUrl(avatarUrl);

          return Stack(
            children: [
              ClipOval(
                child: Image.network(
                  url ?? '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(2),
                    alignment: Alignment.center,
                    child: SvgPicture.asset('assets/logo.svg'),
                  ),
                ),
              ),
              if (_selectedTab == 'users' &&
                  (item['is_online'] == 1 || item['is_online'] == true))
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E1E1E),
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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
        ],
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF888888)),
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
              icon: const Icon(Icons.message, color: Color(0xFFBE1E1E)),
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
