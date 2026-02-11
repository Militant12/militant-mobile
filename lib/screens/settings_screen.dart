import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentLanguage = 'fr';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final api = await ApiService.getInstance();
      final prefs = await api.getPreferences();
      if (mounted) {
        setState(() {
          _currentLanguage = prefs['language'] ?? 'fr';
        });
      }
    } catch (_) {
      // Ignore errors for main settings screen load
    }
  }

  Future<void> _updateLanguage(String lang) async {
    setState(() => _currentLanguage = lang);
    try {
      final api = await ApiService.getInstance();
      await api.updatePreferences({'language': lang});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Langue mise à jour')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          _buildOption(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Gérer les notifications',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.lock,
            title: 'Sécurité',
            subtitle: 'Changer de mot de passe',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.privacy_tip,
            title: 'Confidentialité',
            subtitle: 'Paramètres de confidentialité',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.language,
            title: 'Langue',
            subtitle: _getLanguageName(_currentLanguage),
            onTap: () => _showLanguageDialog(context),
          ),
          _buildOption(
            context,
            icon: Icons.dark_mode,
            title: 'Thème',
            subtitle: 'Sombre',
            onTap: () => _showThemeDialog(context),
          ),
          _buildOption(
            context,
            icon: Icons.info,
            title: 'À propos',
            subtitle: 'Version 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    if (code == 'en') return 'English';
    if (code == 'es') return 'Español';
    return 'Français';
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFBE1E1E)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Choisir le thème',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Sombre',
                style: TextStyle(color: Colors.white),
              ),
              leading: const Icon(Icons.dark_mode, color: Color(0xFFBE1E1E)),
              trailing: const Icon(Icons.check, color: Color(0xFFBE1E1E)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Clair', style: TextStyle(color: Colors.white)),
              leading: const Icon(Icons.light_mode, color: Colors.white70),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thème clair bientôt disponible'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Choisir la langue',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageTile('Français', 'fr', '🇫🇷'),
            _buildLanguageTile('English', 'en', '🇺🇸'),
            _buildLanguageTile('Español', 'es', '🇪🇸'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(String name, String code, String flag) {
    final isSelected = _currentLanguage == code;
    return ListTile(
      title: Text(name, style: const TextStyle(color: Colors.white)),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFFBE1E1E))
          : null,
      onTap: () {
        Navigator.pop(context);
        _updateLanguage(code);
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Militant',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color(0xFFBE1E1E),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.bolt, color: Colors.white),
      ),
      children: [
        const Text('Le réseau social de combat.'),
        const SizedBox(height: 16),
        const Text('© 2026 Militant Inc.'),
      ],
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      await api.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe modifié avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${e.toString().replaceAll("Exception: ", "")}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Changer de mot de passe',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) => v!.length < 8 ? 'Minimun 8 caractères' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) => v != _newPasswordController.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mettre à jour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;

  // Default values
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _likes = true;
  bool _comments = true;
  bool _follows = true;
  bool _mentions = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final api = await ApiService.getInstance();
      final prefs = await api.getPreferences();

      if (mounted) {
        setState(() {
          _pushEnabled = prefs['notifications_push'] ?? true;
          _emailEnabled = prefs['notifications_email'] ?? false;
          _likes = prefs['notifications_likes'] ?? true;
          _comments = prefs['notifications_comments'] ?? true;
          _follows = prefs['notifications_follows'] ?? true;
          _mentions = prefs['notifications_mentions'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    // Optimistic update
    setState(() {
      if (key == 'notifications_push')
        _pushEnabled = value;
      else if (key == 'notifications_email')
        _emailEnabled = value;
      else if (key == 'notifications_likes')
        _likes = value;
      else if (key == 'notifications_comments')
        _comments = value;
      else if (key == 'notifications_follows')
        _follows = value;
      else if (key == 'notifications_mentions')
        _mentions = value;
    });

    try {
      final api = await ApiService.getInstance();
      await api.updatePreferences({key: value});
    } catch (e) {
      // Revert on error (could typically implement revert logic here)
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView(
              children: [
                _buildSectionHeader('Canaux'),
                _buildSwitch(
                  'Notifications push',
                  'Sur cet appareil',
                  _pushEnabled,
                  (v) => _updatePreference('notifications_push', v),
                ),
                _buildSwitch(
                  'E-mails',
                  'Recevoir des résumés par mail',
                  _emailEnabled,
                  (v) => _updatePreference('notifications_email', v),
                ),

                if (_pushEnabled || _emailEnabled) ...[
                  _buildSectionHeader('Interactions'),
                  _buildSwitch(
                    'J\'aime',
                    'Quand quelqu\'un aime vos posts',
                    _likes,
                    (v) => _updatePreference('notifications_likes', v),
                  ),
                  _buildSwitch(
                    'Commentaires',
                    'Quand quelqu\'un commente',
                    _comments,
                    (v) => _updatePreference('notifications_comments', v),
                  ),
                  _buildSwitch(
                    'Abonnements',
                    'Nouveaux abonnés',
                    _follows,
                    (v) => _updatePreference('notifications_follows', v),
                  ),
                  _buildSwitch(
                    'Mentions',
                    'Quand on vous mentionne',
                    _mentions,
                    (v) => _updatePreference('notifications_mentions', v),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFBE1E1E),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFBE1E1E),
      tileColor: const Color(0xFF121212),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _isLoading = true;

  bool _isPrivate = false;
  bool _allowMessages = true;
  bool _showOnlineStatus = true;
  bool _showReadReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final api = await ApiService.getInstance();
      final prefs = await api.getPreferences();

      if (mounted) {
        setState(() {
          _isPrivate = prefs['privacy_private_account'] ?? false;
          _allowMessages = prefs['privacy_allow_messages'] ?? true;
          _showOnlineStatus = prefs['privacy_online_status'] ?? true;
          _showReadReceipts = prefs['privacy_read_receipts'] ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silent fail or default values
      }
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() {
      if (key == 'privacy_private_account')
        _isPrivate = value;
      else if (key == 'privacy_allow_messages')
        _allowMessages = value;
      else if (key == 'privacy_online_status')
        _showOnlineStatus = value;
      else if (key == 'privacy_read_receipts')
        _showReadReceipts = value;
    });

    try {
      final api = await ApiService.getInstance();
      await api.updatePreferences({key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de sauvegarde')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Confidentialité',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView(
              children: [
                _buildSwitch(
                  'Compte privé',
                  'Seuls vos abonnés peuvent voir vos posts et médias',
                  _isPrivate,
                  (v) => _updatePreference('privacy_private_account', v),
                ),
                const Divider(color: Colors.white10),
                _buildSwitch(
                  'Messages privés',
                  'Autoriser tout le monde à vous envoyer des messages',
                  _allowMessages,
                  (v) => _updatePreference('privacy_allow_messages', v),
                ),
                _buildSwitch(
                  'Statut en ligne',
                  'Afficher quand vous êtes actif',
                  _showOnlineStatus,
                  (v) => _updatePreference('privacy_online_status', v),
                ),
                _buildSwitch(
                  'Confirmations de lecture',
                  'Voir quand vos messages sont lus',
                  _showReadReceipts,
                  (v) => _updatePreference('privacy_read_receipts', v),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFBE1E1E),
      tileColor: const Color(0xFF121212),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
