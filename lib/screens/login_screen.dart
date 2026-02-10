import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              
              // Logo
              SvgPicture.asset(
                'assets/logo.svg',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 24),
              
              // Titre
              const Text(
                'Militant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Réseau social militant',
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
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
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
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
                  label: 'Serveur',
                  icon: Icons.dns,
                ),
                const SizedBox(height: 16),
              ],
              
              // Champ username
              _buildTextField(
                controller: _usernameController,
                label: 'Nom d\'utilisateur ou email',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              
              // Champ password
              _buildTextField(
                controller: _passwordController,
                label: 'Mot de passe',
                icon: Icons.lock,
                isPassword: true,
              ),
              const SizedBox(height: 24),
              
              // Bouton connexion
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE1E1E),
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
                    : const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                  _showServerField ? 'Masquer le serveur' : 'Changer de serveur',
                  style: const TextStyle(
                    color: Color(0xFFBE1E1E),
                  ),
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
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        prefixIcon: Icon(icon, color: const Color(0xFF888888)),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
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
