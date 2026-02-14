import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_bar.dart';
import 'moderation_screen.dart';
import 'profile_screen.dart';
import 'create_post_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'messages_screen.dart';
import 'groups_screen.dart';
import 'events_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Post> _posts = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _selectedIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const SizedBox.shrink(), // Placeholder, updated in build
      const GroupsScreen(),
      const EventsScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
    _loadPosts();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _posts.clear();
        _currentPage = 1;
      }
    });

    try {
      final api = await ApiService.getInstance();
      final postsData = await api.getPosts(page: _currentPage);

      setState(() {
        _posts.addAll(postsData.map((p) => Post.fromJson(p)).toList());
        _currentPage++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = theme.iconTheme.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Militant',
          style: TextStyle(
            color: Color(0xFFBE1E1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.shield, color: iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModerationScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? _buildHomeContent()
          : _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  materialPageRoute(builder: (_) => const CreatePostScreen()),
                );
                if (result == true) {
                  _loadPosts(refresh: true);
                }
              },
              backgroundColor: const Color(0xFFBE1E1E),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _screens = [
              const SizedBox.shrink(),
              const GroupsScreen(),
              const EventsScreen(),
              const MessagesScreen(),
              const ProfileScreen(),
            ];
          });
        },
        backgroundColor: theme.cardColor,
        selectedItemColor: const Color(0xFFBE1E1E),
        unselectedItemColor: isDark ? const Color(0xFF888888) : Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: lang.translate('home_title'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.group),
            label: lang.translate('groups_title'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.event),
            label: lang.translate('events_title'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.message),
            label: lang.translate('messages_title'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: lang.translate('profile_title'),
          ),
        ],
      ),
    );
  }

  MaterialPageRoute materialPageRoute({
    required Widget Function(BuildContext) builder,
  }) {
    return MaterialPageRoute(builder: builder);
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () => _loadPosts(refresh: true),
      color: const Color(0xFFBE1E1E),
      child: _posts.isEmpty && _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView.builder(
              itemCount: _posts.length + 2, // +2 pour stories et padding
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const StoriesBar();
                }
                
                if (index == _posts.length + 1) {
                  if (_isLoading) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBE1E1E),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox(height: 80);
                  }
                }

                return PostCard(post: _posts[index - 1]);
              },
            ),
    );
  }
}
