import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'home_screen.dart';
import '../utils/error_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedCause;

  bool _isLoading = false;
  String? _errorMessage;

  final List<Map<String, String>> _causes = [
    {'value': 'Anarchisme', 'label': 'Anarchisme'},
    {'value': 'Communisme', 'label': 'Communisme'},
    {'value': 'Anarcho-syndicalisme', 'label': 'Anarcho-syndicalisme'},
    {'value': 'Abolition du travail', 'label': 'Abolition du travail'},
    {'value': 'Décroissance', 'label': 'Décroissance'},
    {'value': 'Antifa', 'label': 'Antifa'},
    {'value': 'Squat / ZAD', 'label': 'Squat / ZAD'},
    {'value': 'No Border', 'label': 'No Border'},
    {'value': 'Féminisme libertaire', 'label': 'Féminisme libertaire'},
    {'value': 'Anticolonialisme', 'label': 'Anticolonialisme'},
    {'value': 'Action directe', 'label': 'Action directe'},
  ];

  void _showLanguageDialog(BuildContext context) {
    final lang = LanguageService.instance;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          lang.translate('choose_language'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageTile('Français', 'fr'),
            _buildLanguageTile('English', 'en'),
            _buildLanguageTile('Español', 'es'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(String name, String code) {
    final isSelected = LanguageService.instance.value.languageCode == code;
    return ListTile(
      title: Text(
        name,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFFBE1E1E))
          : null,
      onTap: () {
        Navigator.pop(context);
        LanguageService.instance.setLanguage(code);
        setState(() {});
      },
    );
  }

  Future<void> _register() async {
    final lang = LanguageService.instance;
    // Validation
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = lang.translate('username_required');
      });
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = lang.translate('email_required_msg');
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = lang.translate('password_min_length_6');
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = lang.translate('passwords_not_match');
      });
      return;
    }

    if (_selectedCause == null) {
      setState(() {
        _errorMessage = lang.translate('choose_main_cause');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = await ApiService.getInstance();

      final result = await api.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        cause: _selectedCause,
      );

      if (result['success'] == true && mounted) {
        // Auto-login après inscription
        final loginResult = await api.login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

        if (loginResult['success'] == true && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? lang.translate('register_error');
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = getFriendlyErrorMessage(e);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Language selector at the top
              Align(
                alignment: Alignment.topRight,
                child: TextButton.icon(
                  onPressed: () => _showLanguageDialog(context),
                  icon: const Icon(Icons.language, color: Color(0xFFBE1E1E)),
                  label: Text(
                    lang.translate('language_title'),
                    style: const TextStyle(color: Color(0xFFBE1E1E)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Logo
              SvgPicture.asset('assets/logo.svg', width: 80, height: 80),
              const SizedBox(height: 24),

              // Titre
              Text(
                lang.translate('create_account'),
                style: TextStyle(
                  color:
                      theme.textTheme.displayLarge?.color ??
                      (isDark ? Colors.white : Colors.black),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.translate('join_community'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFAAAAAA) : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

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

              // Champ username
              _buildTextField(
                controller: _usernameController,
                label: lang.translate('username_label'),
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              // Champ email
              _buildTextField(
                controller: _emailController,
                label: lang.translate('email_label'),
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Champ cause
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCause,
                  decoration: InputDecoration(
                    labelText: lang.translate('your_main_cause'),
                    labelStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF888888)
                          : Colors.grey[600],
                    ),
                    prefixIcon: Icon(
                      Icons.flag,
                      color: isDark
                          ? const Color(0xFF888888)
                          : Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
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
                  dropdownColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  items: _causes.map((cause) {
                    return DropdownMenuItem<String>(
                      value: cause['value'],
                      child: Text(cause['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCause = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Champ password
              _buildTextField(
                controller: _passwordController,
                label: lang.translate('password_label'),
                icon: Icons.lock,
                isPassword: true,
              ),
              const SizedBox(height: 16),

              // Champ confirmation password
              _buildTextField(
                controller: _confirmPasswordController,
                label: lang.translate('confirm_password'),
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 24),

              // Bouton inscription
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _register(),
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
                          lang.translate('sign_up'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Lien vers connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${lang.translate('login_link').split('?')[0]}? ',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFAAAAAA)
                          : Colors.grey[600],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      lang.translate('login_button'),
                      style: const TextStyle(
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
    TextInputType? keyboardType,
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
