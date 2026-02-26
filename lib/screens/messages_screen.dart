import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'create_message_group_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _conversations = [];
  bool _isLoading = false;
  late TabController _tabController;
  ApiService? _api;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB
    });
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<dynamic> _groupConversations = [];

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final results = await Future.wait([
        _api!.getMessages(),
        _api!.getMessageGroups(),
      ]);

      setState(() {
        _conversations.clear();
        _conversations.addAll(results[0]);
        _groupConversations.clear();
        _groupConversations.addAll(results[1]);
      });
    } catch (e) {
      if (mounted) {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('${lang.translate('error')}: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance,
      builder: (context, locale, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final lang = LanguageService.instance;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(lang.translate('messages_title')),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFBE1E1E),
              labelColor: const Color(0xFFBE1E1E),
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              tabs: [
                Tab(text: lang.translate('discussions')),
                Tab(text: lang.translate('groups_title')),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildConversationsList(_conversations, isPrivate: true),
              _buildConversationsList(_groupConversations, isPrivate: false),
            ],
          ),
          floatingActionButton: _tabController.index == 1
              ? FloatingActionButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                    builder: (_) => const CreateMessageGroupScreen(),
                  ),
                );
                if (result != null) {
                  _loadConversations();
                }
              },
              backgroundColor: const Color(0xFFBE1E1E),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
        );
      },
    );
  }

  Widget _buildConversationsList(
    List<dynamic> list, {
    required bool isPrivate,
  }) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && list.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPrivate ? Icons.message_outlined : Icons.groups_outlined,
              size: 64,
              color: isDark ? const Color(0xFF888888) : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPrivate
                  ? lang.translate('no_conversations')
                  : lang.translate('no_group_discussions'),
              style: TextStyle(
                color: isDark ? const Color(0xFF888888) : Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: const Color(0xFFBE1E1E),
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final conv = list[index];
          return isPrivate
              ? _buildConversationItem(conv)
              : _buildGroupConversationItem(conv);
        },
      ),
    );
  }

  Widget _buildGroupConversationItem(dynamic conv) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final name = conv['name'] ?? lang.translate('group');
    final lastMessage = conv['last_message'] ?? '';
    final avatar = conv['avatar'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatScreen(
              groupId: conv['id'],
              groupName: name,
              groupAvatar: avatar,
            ),
          ),
        ).then((_) => _loadConversations());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            _buildAvatarWidget(avatar, isGroup: true, name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationItem(dynamic conv) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final username = conv['username'] ?? lang.translate('user');
    final lastMessage = conv['last_message'] ?? '';
    final unreadCount = conv['unread_count'] ?? 0;
    final userId = conv['user_id'] ?? conv['id'];
    final avatar = conv['avatar'];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(userId: userId, username: username, avatar: avatar),
          ),
        ).then((_) => _loadConversations());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            _buildAvatarWidget(avatar, isGroup: false, name: username),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(
    String? avatar, {
    required bool isGroup,
    required String name,
  }) {
    final url = _api?.getImageUrl(avatar);

    if (url != null && url.endsWith('.svg')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SvgPicture.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(12),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else {
      if (isGroup && url == null) {
        return ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: SvgPicture.asset('assets/logo.svg', fit: BoxFit.cover),
          ),
        );
      }

      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFBE1E1E),
        backgroundImage: url != null ? NetworkImage(url) : null,
        child: url == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      );
    }
  }
}
