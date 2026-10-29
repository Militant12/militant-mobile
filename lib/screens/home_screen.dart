import 'package:flutter/material.dart';
import 'home_feed_screen.dart';
import 'events_screen.dart';
import 'groups_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import '../services/language_service.dart';
import '../services/deep_link_service.dart';
import '../services/message_navigation_service.dart';
import '../widgets/incoming_call_banner.dart';
import '../services/api_service.dart';
import '../services/notification_badge_service.dart';
import 'banned_screen.dart';

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
    NotificationBadgeService.instance.start();
    _initScreens();
    _checkBanStatus();
    // Initialize deep link handling and flush pending deep links & notifications after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService().initialize();
      DeepLinkService().flushPendingDeepLink();
      MessageNavigationService.instance.flushPendingNotification();
      NotificationBadgeService.instance.refresh();
    });
  }

  Future<void> _checkBanStatus() async {
    try {
      final api = await ApiService.getInstance();
      final ban = await api.getMyBanStatus();
      if (ban != null && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => BannedScreen(ban: ban)),
          (route) => false,
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    NotificationBadgeService.instance.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh profile and notification badge when app resumes
    if (state == AppLifecycleState.resumed) {
      _profileKey.currentState?.refreshProfile();
      NotificationBadgeService.instance.refresh();
    }
  }

  void _initScreens() {
    _screens = [
      const HomeFeedScreen(),
      const GroupsScreen(),
      const EventsScreen(),
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
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: const Icon(Icons.groups),
        label: lang.translate('groups_title'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_outlined),
        selectedIcon: const Icon(Icons.event),
        label: lang.translate('agenda_title'),
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
