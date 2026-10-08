import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/theme_context.dart';
import '../widgets/common/common.dart';
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
  Object? _error;
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

      if (!mounted) return;
      setState(() {
        _error = null;
        _conversations.clear();
        _conversations.addAll(results[0]);
        _groupConversations.clear();
        _groupConversations.addAll(results[1]);
      });
    } catch (e) {
      if (!mounted) return;
      if (_conversations.isEmpty && _groupConversations.isEmpty) {
        // Rien à montrer : état d'erreur plein écran avec « Réessayer ».
        setState(() => _error = e);
      } else {
        final lang = LanguageService.instance;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrivateConversationOptions(dynamic conv) {
    final lang = LanguageService.instance;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: Icon(Icons.delete, color: context.colors.error),
          title: Text(
            lang.translate('delete'),
            style: TextStyle(color: context.colors.error),
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
        title: Text(lang.translate('delete_question')),
        content: Text(lang.translate('delete_conversation_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            child: Text(lang.translate('delete')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFriendlyErrorMessage(e, lang))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LanguageService.instance,
      builder: (context, locale, child) {
        final lang = LanguageService.instance;

        return Scaffold(
          appBar: AppBar(
            title: Text(lang.translate('messages_title')),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: context.colors.primary,
              labelColor: context.colors.primary,
              unselectedLabelColor: context.colors.onSurfaceVariant,
              tabs: [
                Tab(text: lang.translate('discussions')),
                Tab(text: lang.translate('groups_title')),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildSearchBar(lang),
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
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              tooltip: lang.translate('create_group'),
              child: const Icon(Icons.add),
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

  Widget _buildSearchBar(LanguageService lang) {
    final colors = context.colors;
    final muted = context.tokens.textMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant, width: 1),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: TextStyle(color: colors.onSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: _tabController.index == 0
                ? lang.translate('search_users')
                : lang.translate('search_group'),
            hintStyle: TextStyle(color: muted, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: colors.primary, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: lang.translate('clear'),
                    icon: Icon(Icons.clear, color: muted, size: 18),
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

    if (_isLoading && list.isEmpty) {
      return const SkeletonList();
    }

    if (_error != null && list.isEmpty) {
      return ErrorState(error: _error, onRetry: _loadConversations);
    }

    final filteredList = list.where((item) {
      if (_searchQuery.isEmpty) return true;
      final name = isPrivate
          ? (item['username'] ?? '').toString().toLowerCase()
          : (item['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredList.isEmpty) {
      return EmptyState(
        icon: isPrivate ? Icons.message_outlined : Icons.groups_outlined,
        title: _searchQuery.isNotEmpty
            ? lang.translate('no_results')
            : (isPrivate
                  ? lang.translate('no_conversations')
                  : lang.translate('no_group_discussions')),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: context.colors.primary,
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
          border: Border(
            bottom: BorderSide(color: context.colors.outlineVariant),
          ),
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
                      color: context.colors.onSurface,
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
                      color: context.tokens.textMuted,
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
          border: Border(
            bottom: BorderSide(color: context.colors.outlineVariant),
          ),
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
                      color: context.colors.onSurface,
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
                      color: context.tokens.textMuted,
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
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  semanticsLabel: lang
                      .translate('unread_messages_count')
                      .replaceAll('{count}', unreadCount.toString()),
                  style: TextStyle(
                    color: context.colors.onPrimary,
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
    // Groupe sans image : logo Militant ; personne : son initiale.
    return AppAvatar(
      url: _api?.getImageUrl(avatar),
      name: isGroup ? null : name,
      semanticLabel: name,
      radius: 24,
    );
  }
}
