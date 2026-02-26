import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/incoming_call_service.dart';
import '../services/language_service.dart';
import '../services/message_notification_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'home_screen.dart';
import 'register_screen.dart';

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

  final _totpController = TextEditingController();
  bool _isLoading = false;
  bool _showServerField = false;
  bool _requires2FA = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedServerUrl();
  }

  Future<void> _loadSavedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('base_url');
    if (raw == null || raw.trim().isEmpty) return;

    final normalized = ApiService.normalizeBaseUrl(raw);
    if (!mounted) return;
    _serverController.text = normalized;

    if (normalized != raw) {
      await prefs.setString('base_url', normalized);
    }
  }

  int? _parseUserId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  int? _extractUserId(Map<String, dynamic> result) {
    final directId = _parseUserId(result['user_id'] ?? result['id']);
    if (directId != null) return directId;

    final user = result['user'];
    if (user is Map<String, dynamic>) {
      return _parseUserId(user['id'] ?? user['user_id']);
    }
    return null;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = await ApiService.getInstance();
      String serverUrl = _serverController.text.trim();
      serverUrl = ApiService.normalizeBaseUrl(serverUrl);
      if (serverUrl.isEmpty) throw Exception('URL du serveur vide');

      api.baseUrl = serverUrl;

      final result = await api.login(
        _usernameController.text.trim(),
        _passwordController.text,
        totp: _requires2FA ? _totpController.text.trim() : null,
      );

      if (result['two_factor_required'] == true) {
        setState(() {
          _requires2FA = true;
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      if (result['success'] == true && mounted) {
        // Sauvegarder l'URL du serveur pour la persistance de session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_url', serverUrl);

        int? loggedUserId = _extractUserId(result);
        loggedUserId ??= await api.getCurrentUserId();
        if (loggedUserId != null) {
          await prefs.setInt('user_id', loggedUserId);
        }

        // Dynamic initialization of OneSignal
        try {
          // Initialize with server's App ID
          await api.initializeOneSignal();

          // Login to OneSignal for notifications only on supported platforms
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            if (loggedUserId != null) {
              final userId = loggedUserId.toString();
              print('OneSignal Login with User ID: $userId');
              OneSignal.login(userId);
            }
          }
        } catch (e) {
          print('OneSignal dynamic init error: $e');
        }

        try {
          await IncomingCallService.instance.initialize();
          await MessageNotificationService.instance.initialize();
        } catch (e) {
          print('Incoming call init error: $e');
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

              // Champ username/password ou TOTP
              if (!_requires2FA) ...[
                // Champ username
                _buildTextField(
                  controller: _usernameController,
                  label: lang.translate('username_label'),
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
              ] else ...[
                Text(
                  'Double authentification requise',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez le code généré par votre application d\'authentification.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _totpController,
                  label: 'Code de validation',
                  icon: Icons.security,
                  keyboardType: TextInputType.number,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _requires2FA = false;
                      _totpController.clear();
                    });
                  },
                  child: const Text(
                    'Retour aux identifiants',
                    style: TextStyle(color: Color(0xFFBE1E1E)),
                  ),
                ),
              ],
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
              const SizedBox(height: 24),

              // Lien vers inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pas encore de compte ? ',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFAAAAAA)
                          : Colors.grey[600],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
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
