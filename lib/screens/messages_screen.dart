import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'chat_screen.dart';
import 'group_chat_screen.dart';
import 'create_message_group_screen.dart';
import '../utils/error_helper.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

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
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  final List<dynamic> _groupConversations = [];

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      _api = await ApiService.getInstance();
      final results = await Future.wait([
        _api!.getMessages(query: _searchQuery),
        _api!.getMessageGroups(query: _searchQuery),
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
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPrivateConversationOptions(dynamic conv) {
    final lang = LanguageService.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete, color: Color(0xFFBE1E1E)),
          title: Text(
            lang.translate('delete'),
            style: const TextStyle(color: Color(0xFFBE1E1E)),
          ),
          onTap: () {
            Navigator.pop(context);
            _confirmDeleteConversation(conv);
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteConversation(dynamic conv) async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          lang.translate('delete_question'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          lang.translate('delete_conversation_confirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('delete'),
              style: const TextStyle(color: Color(0xFFBE1E1E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteConversation(conv);
    }
  }

  Future<void> _deleteConversation(dynamic conv) async {
    final lang = LanguageService.instance;
    final rawUserId = conv['user_id'] ?? conv['id'];
    final userId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('error_generic'))),
      );
      return;
    }

    try {
      _api ??= await ApiService.getInstance();
      await _api!.deleteConversation(userId);

      if (!mounted) return;
      setState(() => _conversations.remove(conv));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('conversation_deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
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
          body: Column(
            children: [
              _buildSearchBar(isDark, lang),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConversationsList(_conversations, isPrivate: true),
                    _buildConversationsList(_groupConversations, isPrivate: false),
                  ],
                ),
              ),
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    try {
      final api = _api ?? await ApiService.getInstance();
      final results = await Future.wait([
        api.getMessages(query: _searchQuery),
        api.getMessageGroups(query: _searchQuery),
      ]);
      if (mounted) {
        setState(() {
          _conversations.clear();
          _conversations.addAll(results[0]);
          _groupConversations.clear();
          _groupConversations.addAll(results[1]);
        });
      }
    } catch (e) {
      debugPrint('[MessagesScreen] search error=$e');
    }
  }

  Widget _buildSearchBar(bool isDark, LanguageService lang) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: _tabController.index == 0
                ? lang.translate('search_users')
                : lang.translate('search_group'),
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFFBE1E1E),
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      setState(() {
                        _searchQuery = '';
                      });
                      _performSearch();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
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

    final filteredList = list.where((item) {
      if (_searchQuery.isEmpty) return true;
      final name = isPrivate
          ? (item['username'] ?? '').toString().toLowerCase()
          : (item['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredList.isEmpty) {
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
              _searchQuery.isNotEmpty
                  ? lang.translate('no_results')
                  : (isPrivate
                      ? lang.translate('no_conversations')
                      : lang.translate('no_group_discussions')),
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
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final conv = filteredList[index];
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
      onLongPress: () => _showPrivateConversationOptions(conv),
      onSecondaryTap: () => _showPrivateConversationOptions(conv),
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
