import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Register FVP with options to handle more formats and network streams better
  fvp.registerWith(
    options: {
      'hwdec': 'auto', // Try hardware decoding but fallback safely
      'network-timeout': '10', // Increase timeout
      'ytdl-format': 'best', // In case it's a stream URL
    },
  );
  runApp(const MilitantApp());
}

class MilitantApp extends StatelessWidget {
  const MilitantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Militant',
      theme: ThemeData(
        primaryColor: const Color(0xFFBE1E1E),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFBE1E1E),
          secondary: const Color(0xFFBE1E1E),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    if (mounted) {
      if (token != null) {
        // Utilisateur connecté, aller à l'accueil
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // Pas connecté, aller au login
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo (vous pouvez utiliser SvgPicture.asset si vous avez le logo)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFBE1E1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.people, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              'Militant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Color(0xFFBE1E1E)),
          ],
        ),
      ),
    );
  }
}
