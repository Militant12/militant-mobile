import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController(
    text: 'https://api.militant.revlibertaire.com',
  );

  bool _isLoading = false;
  bool _showServerField = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = await ApiService.getInstance();
      api.baseUrl = _serverController.text.trim();

      final result = await api.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (result['success'] == true && mounted) {
        // Dynamic initialization of OneSignal
        try {
          // Initialize with server's App ID
          await api.initializeOneSignal();

          // Login to OneSignal for notifications
          if (result['user'] != null && result['user']['id'] != null) {
            OneSignal.login(result['user']['id'].toString());
          }
        } catch (e) {
          print('OneSignal dynamic init error: $e');
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Erreur de connexion';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: ${e.toString()}';
      });
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Logo
              SvgPicture.asset('assets/logo.svg', width: 100, height: 100),
              const SizedBox(height: 24),

              // Titre
              Text(
                lang.translate('app_title'),
                style: TextStyle(
                  color:
                      theme.textTheme.displayLarge?.color ??
                      (isDark ? Colors.white : Colors.black),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Réseau social militant',
                style: TextStyle(
                  color: isDark ? const Color(0xFFAAAAAA) : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),

              // Message d'erreur
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Champ serveur (optionnel)
              if (_showServerField) ...[
                _buildTextField(
                  controller: _serverController,
                  label: lang.translate('server_label'),
                  icon: Icons.dns,
                ),
                const SizedBox(height: 16),
              ],

              // Champ username
              _buildTextField(
                controller: _usernameController,
                label:
                    '${lang.translate('username_label')} / ${lang.translate('email_label')}',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Champ password
              _buildTextField(
                controller: _passwordController,
                label: lang.translate('password_label'),
                icon: Icons.lock,
                isPassword: true,
              ),
              const SizedBox(height: 24),

              // Bouton connexion
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _login(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE1E1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          lang.translate('login_button'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Bouton changer de serveur
              TextButton(
                onPressed: () {
                  setState(() {
                    _showServerField = !_showServerField;
                  });
                },
                child: Text(
                  _showServerField
                      ? 'Masquer le serveur'
                      : 'Changer de serveur',
                  style: const TextStyle(color: Color(0xFFBE1E1E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF888888) : Colors.grey[600],
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? const Color(0xFF888888) : Colors.grey[600],
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBE1E1E)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }
}
