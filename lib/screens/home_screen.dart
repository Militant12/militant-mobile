import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
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
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shield, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModerationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
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
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
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
          });
        },
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFFBE1E1E),
        unselectedItemColor: const Color(0xFF888888),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groupes'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Événements'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
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
              itemCount: _posts.length + 1,
              itemBuilder: (context, index) {
                if (index == _posts.length) {
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

                return PostCard(post: _posts[index]);
              },
            ),
    );
  }
}
