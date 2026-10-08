import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'profile_screen.dart';
import 'group_detail_screen.dart';
import 'page_detail_screen.dart';
import '../theme/theme_context.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _discoveryData = {};
  Object? _error;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _loadDiscoveryData();
  }

  Future<void> _loadDiscoveryData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _api = await ApiService.getInstance();
      final data = await _api!.getDiscoveryData();
      if (mounted) {
        setState(() {
          _discoveryData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _followUser(int userId) async {
    try {
      if (_api == null) return;
      await _api!.followUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance.translate('subscription_success'),
            ),
          ),
        );
        _loadDiscoveryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              getFriendlyErrorMessage(e, LanguageService.instance),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isNarrowScreen = MediaQuery.of(context).size.width < 380;
    final appBarTitle = isNarrowScreen
        ? lang.translate('discover')
        : lang.translate('discover_militants');

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            appBarTitle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: lang.translate('refresh'),
            onPressed: _loadDiscoveryData,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoader()
          : _error != null
          ? ErrorState(error: _error, onRetry: _loadDiscoveryData)
          : RefreshIndicator(
              onRefresh: _loadDiscoveryData,
              color: context.colors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(lang.translate('new_militants')),
                  const SizedBox(height: 12),
                  _buildUserSuggestions(
                    _discoveryData['users']?['new_users'] ?? [],
                  ),
                  const SizedBox(height: 24),

                  _buildHeader(lang.translate('militants_same_cause')),
                  const SizedBox(height: 12),
                  _buildUserSuggestions(
                    _discoveryData['users']?['same_cause'] ?? [],
                  ),
                  const SizedBox(height: 24),

                  _buildHeader(lang.translate('suggested_militants')),
                  const SizedBox(height: 12),
                  _buildUserSuggestions(
                    _discoveryData['users']?['random'] ?? [],
                  ),
                  const SizedBox(height: 24),

                  _buildHeader(lang.translate('suggested_groups')),
                  const SizedBox(height: 12),
                  _buildGroupSuggestions(_discoveryData['groups'] ?? []),
                  const SizedBox(height: 24),

                  _buildHeader(lang.translate('suggested_pages')),
                  const SizedBox(height: 12),
                  _buildPageSuggestions(_discoveryData['pages'] ?? []),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildUserSuggestions(List<dynamic> users) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          LanguageService.instance.translate('no_results'),
          style: TextStyle(color: context.tokens.textMuted),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 430 ? 2 : (width < 760 ? 3 : 4);
        final childAspectRatio = width < 430 ? 0.76 : (width < 760 ? 0.72 : 0.78);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildUserCard(users[index]);
          },
        );
      },
    );
  }

  Widget _buildUserCard(dynamic user) {

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: user['id'])),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAvatar(
                url: _api?.getImageUrl(user['avatar']),
                semanticLabel: user['username']?.toString(),
                radius: 25,
                online: user['is_online'] == 1 || user['is_online'] == true,
              ),
              const SizedBox(height: 8),
              Text(
                user['username'] ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user['cause'] ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.clip,
                softWrap: true,
                style: TextStyle(
                  fontSize: 10,
                  color: context.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () => _followUser(user['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    foregroundColor: context.colors.onPrimary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    LanguageService.instance.translate('follow'),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSuggestions(List<dynamic> groups) {
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          LanguageService.instance.translate('no_results'),
          style: TextStyle(color: context.tokens.textMuted),
        ),
      );
    }
    final lang = LanguageService.instance;
    return Column(
      children: groups.map((group) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildItemCard(
            title: group['name'],
            subtitle:
                '${group['members_count']} ${group['members_count'] > 1 ? lang.translate('members') : lang.translate('member')}',
            image: group['avatar'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(group: group),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageSuggestions(List<dynamic> pages) {
    if (pages.isEmpty) return const SizedBox();
    return Column(
      children: pages.map((page) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildItemCard(
            title: page['name'],
            subtitle: page['category'] ?? '',
            image: page['avatar'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PageDetailScreen(page: page)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard({
    required String title,
    required String subtitle,
    String? image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                image: image != null && image != 'default.svg'
                    ? DecorationImage(
                        image: NetworkImage(_api?.getImageUrl(image) ?? ''),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: image == null || image == 'default.svg'
                  ? Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: SvgPicture.asset('assets/logo.svg'),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.tokens.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
