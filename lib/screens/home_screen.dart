import 'package:flutter/material.dart';
import 'home_feed_screen.dart';
import 'live_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
import '../services/language_service.dart';
import '../services/deep_link_service.dart';
import '../widgets/incoming_call_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  // Définition directe des écrans
  late final List<Widget> _screens;
  final GlobalKey<ProfileScreenState> _profileKey =
      GlobalKey<ProfileScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScreens();
    // Initialize deep link handling after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh profile when app resumes
    if (state == AppLifecycleState.resumed) {
      _profileKey.currentState?.refreshProfile();
    }
  }

  void _initScreens() {
    _screens = [
      const HomeFeedScreen(),
      const CommunityScreen(), // Menu grille
      const LiveScreen(),
      const MessagesScreen(),
      ProfileScreen(key: _profileKey),
    ];
  }

  List<NavigationDestination> _buildDestinations() {
    final lang = LanguageService.instance;
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: lang.translate('home_title'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.grid_view_outlined),
        selectedIcon: const Icon(Icons.grid_view),
        label: lang.translate('community_nav_title'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.live_tv_outlined),
        selectedIcon: const Icon(Icons.live_tv),
        label: 'Live',
      ),
      NavigationDestination(
        icon: const Icon(Icons.message_outlined),
        selectedIcon: const Icon(Icons.message),
        label: lang.translate('messages_title'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: lang.translate('profile_title'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex < _screens.length ? _selectedIndex : 0,
            children: _screens,
          ),
          // Bannière d'appel entrant — visible dans toute l'app, démarre automatiquement
          const IncomingCallBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex < _screens.length ? _selectedIndex : 0,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: _buildDestinations(),
      ),
    );
  }
}
