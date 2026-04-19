import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/fediverse_post.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../utils/fediverse_text.dart';
import '../widgets/fediverse_post_card.dart';

class FediverseProfileScreen extends StatefulWidget {
  final String initialQuery;
  final Map<String, dynamic>? initialProfile;
  final ValueChanged<Map<String, dynamic>>? onProfileUpdated;

  const FediverseProfileScreen({
    super.key,
    required this.initialQuery,
    this.initialProfile,
    this.onProfileUpdated,
  });

  @override
  State<FediverseProfileScreen> createState() => _FediverseProfileScreenState();
}

class _FediverseProfileScreenState extends State<FediverseProfileScreen> {
  ApiService? _api;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isTogglingFollow = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile != null
        ? Map<String, dynamic>.from(widget.initialProfile!)
        : null;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_profile == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final api = _api ?? await ApiService.getInstance();
      final data = await api.getRemoteFediverseProfile(widget.initialQuery);
      if (!mounted) return;
      setState(() {
        _api = api;
        _profile = data;
        _isLoading = false;
      });
      widget.onProfileUpdated?.call(Map<String, dynamic>.from(data));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleFollow() async {
    final api = _api;
    final profile = _profile;
    if (api == null || profile == null || _isTogglingFollow) {
      return;
    }

    final actorUrl = (profile['actor_url'] ?? '').toString();
    final isFollowing = _isFollowing(profile);
    if (actorUrl.isEmpty) {
      return;
    }

    setState(() => _isTogglingFollow = true);

    try {
      final response = isFollowing
          ? await api.unfollowRemoteFediverse(actorUrl, isActorUrl: true)
          : await api.followRemoteFediverse(actorUrl, isActorUrl: true);

      if (!mounted) return;

      final updated = Map<String, dynamic>.from(profile);
      updated['is_following'] = !isFollowing;
      final returnedProfile = response['profile'];
      if (returnedProfile is Map<String, dynamic>) {
        updated.addAll(returnedProfile);
      }

      setState(() {
        _profile = updated;
        _isTogglingFollow = false;
      });
      widget.onProfileUpdated?.call(updated);

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
      setState(() => _isTogglingFollow = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  bool _isFollowing(Map<String, dynamic> profile) {
    final value = profile['is_following'];
    return value == true || value == 1 || value == '1';
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

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
            actions: [
              IconButton(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _isLoading && _profile == null
              ? Center(child: CircularProgressIndicator(color: accent))
              : _error != null && _profile == null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: accent,
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 20),
                      Text(
                        lang.translate('fediverse_recent_posts'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildPosts(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    final lang = LanguageService.instance;
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
              lang.translate('fediverse_error_load'),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              child: Text(lang.translate('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _profile ?? const <String, dynamic>{};
    final theme = Theme.of(context);
    final avatarUrl = (profile['avatar'] ?? '').toString();
    final displayName = (profile['display_name'] ?? profile['username'] ?? '')
        .toString();
    final handle = (profile['handle'] ?? '@${profile['username'] ?? ''}')
        .toString();
    final summary = fediverseHtmlToText(profile['summary']?.toString());
    final isFollowing = _isFollowing(profile);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset('assets/logo.svg'),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              handle,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                summary,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTogglingFollow ? null : _toggleFollow,
                  icon: Icon(
                    isFollowing ? Icons.person_remove : Icons.person_add,
                  ),
                  label: Text(
                    isFollowing
                        ? LanguageService.instance.translate(
                            'fediverse_unfollow',
                          )
                        : LanguageService.instance.translate('follow'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openUrl(
                    (profile['profile_url'] ?? profile['actor_url']).toString(),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(LanguageService.instance.translate('open')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPosts() {
    final rawPosts = _profile?['recent_posts'];
    if (rawPosts is! List || rawPosts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              LanguageService.instance.translate('fediverse_no_posts'),
            ),
          ),
        ),
      ];
    }

    return rawPosts
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (json) => FediversePostCard(
            post: FediversePost.fromJson(json),
            onProfileTap: null,
          ),
        )
        .toList();
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
