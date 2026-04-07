import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

import 'services/theme_manager.dart';
import 'services/language_service.dart';
import 'services/api_service.dart';
import 'services/incoming_call_service.dart';
import 'services/message_notification_service.dart';
import 'services/notification_reply_service.dart';
import 'services/user_status_service.dart';
import 'widgets/incoming_call_banner.dart';

// Import OneSignal
import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OneSignal Debugging only on supported platforms
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  }

  // Register FVP with options to handle more formats and network streams better
  fvp.registerWith(
    options: {'hwdec': 'auto', 'network-timeout': '10', 'ytdl-format': 'best'},
  );
  await ThemeManager.instance.loadTheme();
  await LanguageService.instance.loadLanguage();
  runApp(const MilitantApp());
}

class MilitantApp extends StatelessWidget {
  const MilitantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.instance,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LanguageService.instance,
          builder: (context, locale, __) {
            return MaterialApp(
              navigatorKey: appNavigatorKey,
              title: 'Militant',
              locale: locale,
              themeMode: mode,
              theme: ThemeData(
                brightness: Brightness.light,
                primaryColor: const Color(0xFFBE1E1E),
                scaffoldBackgroundColor: Colors.white,
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFFBE1E1E),
                  secondary: Color(0xFFBE1E1E),
                  surface: Colors.white,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  iconTheme: IconThemeData(color: Colors.black),
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                primaryColor: const Color(0xFFBE1E1E),
                scaffoldBackgroundColor: const Color(0xFF121212),
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFBE1E1E),
                  secondary: Color(0xFFBE1E1E),
                  surface: Color(0xFF1E1E1E),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  iconTheme: IconThemeData(color: Colors.white),
                ),
                useMaterial3: true,
              ),
              home: const SplashScreen(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animController.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    try {
      print('=== SPLASH: Début vérification auth ===');
      final prefs = await SharedPreferences.getInstance();
      print('=== SPLASH: SharedPreferences chargé ===');

      final token = prefs.getString('api_token');
      final baseUrl = prefs.getString('base_url');

      print('=== SPLASH: Token = ${token != null ? "présent" : "absent"} ===');
      print('=== SPLASH: BaseURL = $baseUrl ===');

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 800));
      print('=== SPLASH: Animation terminée ===');

      if (!mounted) return;

      // Simple check: if we have token AND base_url, go to HomeScreen
      // HomeScreen will handle any errors and redirect to login if needed
      if (token != null &&
          token.isNotEmpty &&
          baseUrl != null &&
          baseUrl.isNotEmpty) {
        print(
          '=== SPLASH: Token et URL présents, navigation vers HomeScreen ===',
        );

        // Initialiser OneSignal, appels entrants, messages et bannière
        try {
          final api = await ApiService.getInstance();
          await api.initializeOneSignal();
          await IncomingCallService.instance.initialize();
          await MessageNotificationService.instance.initialize();
          await NotificationReplyService.instance.initialize();
          await UserStatusService.instance.load();
          // Démarrer le listener global d'appels — la bannière apparaît dans tous les chats
          IncomingCallController.instance.startListening();
          // Login to OneSignal with cached user ID, or recover it from profile if needed
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            var userId = prefs.getInt('user_id');
            userId ??= await api.getCurrentUserId();
            if (userId != null) {
              await prefs.setInt('user_id', userId);
            }

            final externalId = ApiService.oneSignalExternalIdFromUserId(userId);
            if (externalId.isNotEmpty) {
              print(
                '=== SPLASH: OneSignal Login with External ID: $externalId ===',
              );
              OneSignal.login(externalId);
            }
          }

          print('=== SPLASH: OneSignal + appels entrants initialises ===');
        } catch (e) {
          print('=== SPLASH: Erreur init OneSignal/appels entrants: $e ===');
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        print(
          '=== SPLASH: Pas de token ou base_url, navigation vers LoginScreen ===',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('=== SPLASH: Erreur: $e ===');
      // Always fallback to login on any error
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo SVG Militant
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFBE1E1E).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: SvgPicture.asset(
                      'assets/logo.svg',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'MILITANT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Réseau social militant',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: const Color(0xFFBE1E1E),
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
