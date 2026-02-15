import 'package:flutter/material.dart';
import 'users_list_screen.dart';
import '../services/language_service.dart';
import '../services/api_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final api = await ApiService.getInstance();
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
              action == 'accept' ? 'Demande acceptée' : 'Demande refusée',
            ),
          ),
        );
      }

      _loadPendingRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
        ),
      );
    }

    final lang = LanguageService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.translate('friends_title')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBE1E1E),
          labelColor: const Color(0xFFBE1E1E),
          unselectedLabelColor: Colors.grey,
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
                          color: const Color(0xFFBE1E1E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
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
    final theme = Theme.of(context);

    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
      );
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune demande en attente',
              style: TextStyle(color: theme.disabledColor),
            ),
          ],
        ),
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
            child: CircleAvatar(
              backgroundColor: theme.cardColor,
              child: req['avatar'] != null
                  ? ClipOval(
                      child: Image.network(
                        ApiService(baseUrl: '').getImageUrl(req['avatar'])!,
                        fit: BoxFit.cover,
                        width: 40,
                        height: 40,
                      ),
                    )
                  : SvgPicture.asset('assets/logo.svg', width: 30),
            ),
          ),
          title: Text(
            req['username'] ?? 'Utilisateur',
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
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _handleRequest(req['request_id'], 'accept'),
                tooltip: lang.translate('accept'),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Color(0xFFBE1E1E)),
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
