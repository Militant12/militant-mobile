import 'package:flutter/material.dart';
import 'users_list_screen.dart';
import '../services/language_service.dart';
import '../services/api_service.dart';
import '../theme/theme_context.dart';
import 'profile_screen.dart';
import '../utils/error_helper.dart';
import '../widgets/common/common.dart';

class FriendsScreen extends StatefulWidget {
  final int? userId;
  const FriendsScreen({super.key, this.userId});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<dynamic> _pendingRequests = [];
  bool _isLoadingRequests = false;
  bool _isMe = false;
  bool _isInitializing = true;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final api = await ApiService.getInstance();
      _api = api;
      final profile = await api.getProfile();

      _isMe = widget.userId == null || widget.userId == profile['id'];

      _tabController = TabController(length: _isMe ? 4 : 3, vsync: this);

      if (_isMe) {
        await _loadPendingRequests();
      }
    } catch (e) {
      debugPrint('Error initializing FriendsScreen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final api = await ApiService.getInstance();
      final data = await api.getFriends(type: 'pending');
      if (mounted) {
        setState(() {
          _pendingRequests = data['pending_requests'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _handleRequest(int requestId, String action) async {
    try {
      final api = await ApiService.getInstance();
      await api.handleFriendRequest(requestId, action);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LanguageService.instance.translate(
                action == 'accept'
                    ? 'friend_request_accepted'
                    : 'friend_request_declined',
              ),
            ),
          ),
        );
      }

      _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(LanguageService.instance.translate('friends_title')),
        ),
        body: const AppLoader(),
      );
    }

    final lang = LanguageService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('friends_title')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.colors.primary,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.tokens.textMuted,
          isScrollable: true,
          tabs: [
            Tab(text: lang.translate('friends_title')),
            Tab(text: lang.translate('followers')),
            Tab(text: lang.translate('following')),
            if (_isMe)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang.translate('friend_requests')),
                    if (_pendingRequests.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: TextStyle(
                            color: context.colors.onPrimary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Amis
          UsersListScreen(
            userId: widget.userId,
            title: lang.translate('friends_title'),
            type: 'friends',
            showAppBar: false,
          ),
          // Abonnés
          UsersListScreen(
            userId: widget.userId,
            title: lang.translate('followers'),
            type: 'followers',
            showAppBar: false,
          ),
          // Abonnements
          UsersListScreen(
            userId: widget.userId,
            title: lang.translate('following'),
            type: 'following',
            showAppBar: false,
          ),
          // Demandes
          if (_isMe) _buildRequestsList(),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    final lang = LanguageService.instance;
    if (_isLoadingRequests) {
      return const SkeletonList();
    }

    if (_pendingRequests.isEmpty) {
      return EmptyState(
        icon: Icons.person_add_outlined,
        title: lang.translate('friend_requests_empty'),
      );
    }

    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        return ListTile(
          leading: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: req['id']),
              ),
            ),
            child: AppAvatar(
              url: _api?.getImageUrl(req['avatar']),
              semanticLabel: req['username']?.toString(),
            ),
          ),
          title: Text(
            req['username'] ?? lang.translate('user'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            req['bio'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check_circle, color: context.tokens.success),
                onPressed: () => _handleRequest(req['request_id'], 'accept'),
                tooltip: lang.translate('accept'),
              ),
              IconButton(
                icon: Icon(Icons.cancel, color: context.colors.primary),
                onPressed: () => _handleRequest(req['request_id'], 'reject'),
                tooltip: lang.translate('decline'),
              ),
            ],
          ),
        );
      },
    );
  }
}
