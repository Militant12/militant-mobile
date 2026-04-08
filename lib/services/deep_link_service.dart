import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/group_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../models/post.dart';
import 'api_service.dart';
import 'incoming_call_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep link handling
  Future<void> initialize() async {
    await _linkSubscription?.cancel();

    // Handle initial link if app was opened from a link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Error listening to deep links: $err');
      },
    );
  }

  List<String> _pathTokens(Uri uri) {
    final tokens = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .map((segment) => Uri.decodeComponent(segment).toLowerCase())
        .toList();

    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.host.isNotEmpty) {
      tokens.insert(0, uri.host.toLowerCase());
    }

    return tokens;
  }

  bool _matchesRoute(Uri uri, List<String> routeNames) {
    final path = uri.path.toLowerCase();
    final tokens = _pathTokens(uri);

    for (final routeName in routeNames) {
      final normalizedName = routeName.toLowerCase();
      if (path.contains(normalizedName) || tokens.contains(normalizedName)) {
        return true;
      }
    }

    return false;
  }

  int? _extractId(Uri uri, List<String> routeNames) {
    final queryId = uri.queryParameters['id'];
    if (queryId != null) {
      final parsed = int.tryParse(queryId);
      if (parsed != null) return parsed;
    }

    final tokens = _pathTokens(uri);
    for (final routeName in routeNames) {
      final index = tokens.indexOf(routeName.toLowerCase());
      if (index != -1 && index + 1 < tokens.length) {
        final parsed = int.tryParse(tokens[index + 1]);
        if (parsed != null) return parsed;
      }
    }

    if (tokens.isNotEmpty) {
      return int.tryParse(tokens.last);
    }

    return null;
  }

  NavigatorState? get _navigator => appNavigatorKey.currentState;

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    if (_matchesRoute(uri, const ['group_detail.php', 'group'])) {
      await _handleGroupLink(uri);
    } else if (_matchesRoute(uri, const ['profile.php', 'profile'])) {
      await _handleProfileLink(uri);
    } else if (_matchesRoute(uri, const [
      'post_detail.php',
      'post.php',
      'post',
    ])) {
      await _handlePostLink(uri);
    }
  }

  /// Handle group deep link
  Future<void> _handleGroupLink(Uri uri) async {
    try {
      final groupId = _extractId(uri, const ['group']);

      if (groupId == null) {
        debugPrint('Invalid group ID in deep link');
        return;
      }

      // Load group details and navigate
      final api = await ApiService.getInstance();
      final groupData = await api.getSocialGroupDetails(groupId);

      final navigator = _navigator;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(group: groupData),
          ),
        );
      } else {
        debugPrint('Navigator not ready for group deep link');
      }
    } catch (e) {
      debugPrint('Error handling group deep link: $e');
    }
  }

  /// Handle profile deep link
  Future<void> _handleProfileLink(Uri uri) async {
    try {
      final userId = _extractId(uri, const ['profile']);

      if (userId == null) {
        debugPrint('Invalid user ID in deep link');
        return;
      }

      final navigator = _navigator;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
        );
      } else {
        debugPrint('Navigator not ready for profile deep link');
      }
    } catch (e) {
      debugPrint('Error handling profile deep link: $e');
    }
  }

  /// Handle post deep link
  Future<void> _handlePostLink(Uri uri) async {
    try {
      final postId = _extractId(uri, const ['post']);

      if (postId == null) {
        debugPrint('Invalid post ID in deep link');
        return;
      }

      // Load post details and navigate
      final api = await ApiService.getInstance();
      final postData = await api.getPost(postId);

      final navigator = _navigator;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: Post.fromJson(postData)),
          ),
        );
      } else {
        debugPrint('Navigator not ready for post deep link');
      }
    } catch (e) {
      debugPrint('Error handling post deep link: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
