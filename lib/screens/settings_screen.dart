import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api_service.dart';
import '../services/theme_manager.dart';
import '../services/language_service.dart';
import 'package:url_launcher/url_launcher.dart';
import './badge_selection_screen.dart';
import './two_factor_settings_screen.dart';
import './edit_profile_screen.dart';

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
    _currentLanguage = LanguageService.instance.value.languageCode;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Language is now handled by LanguageService
  }

  Future<void> _updateLanguage(String lang) async {
    setState(() => _currentLanguage = lang);
    await LanguageService.instance.setLanguage(lang);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${LanguageService.instance.translate('language_title')} updated',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(lang.translate('settings_title'))),
      body: ListView(
        children: [
          _buildOption(
            context,
            icon: Icons.person,
            title: lang.translate('edit_profile_title'),
            subtitle: lang.translate('edit_profile_subtitle'),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (result == true && mounted) {
                // Trigger a rebuild to refresh any cached data
                setState(() {});
              }
            },
          ),
          _buildOption(
            context,
            icon: Icons.flag,
            title: lang.translate('my_militant_badge'),
            subtitle: lang.translate('select_badge_text'),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BadgeSelectionScreen()),
              );
              if (result == true && mounted) {
                // Trigger a rebuild to refresh any cached data
                setState(() {});
              }
            },
          ),
          _buildOption(
            context,
            icon: Icons.notifications,
            title: lang.translate('notifications_title'),
            subtitle: lang.translate('subtitle_notifications'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              // Refresh after notification settings change
              if (mounted) {
                setState(() {});
              }
            },
          ),
          _buildOption(
            context,
            icon: Icons.lock,
            title: lang.translate('security_title'),
            subtitle: lang.translate('subtitle_security'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.security,
            title: lang.translate('two_factor_title'),
            subtitle: lang.translate('two_factor_subtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TwoFactorSettingsScreen(),
                ),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.privacy_tip,
            title: lang.translate('privacy_title'),
            subtitle: lang.translate('subtitle_privacy'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              );
              // Refresh after privacy settings change
              if (mounted) {
                setState(() {});
              }
            },
          ),
          _buildOption(
            context,
            icon: Icons.download,
            title: lang.translate('export_data_title') == 'export_data_title'
                ? 'Exporter mes données'
                : lang.translate('export_data_title'),
            subtitle:
                lang.translate('export_data_subtitle') == 'export_data_subtitle'
                ? 'Télécharger une copie de vos données (JSON)'
                : lang.translate('export_data_subtitle'),
            onTap: _exportData,
          ),
          _buildOption(
            context,
            icon: Icons.language,
            title: lang.translate('language_title'),
            subtitle: _getLanguageName(_currentLanguage),
            onTap: () => _showLanguageDialog(context),
          ),
          _buildOption(
            context,
            icon: Icons.dark_mode,
            title: lang.translate('theme_title'),
            subtitle: isDark
                ? lang.translate('theme_dark')
                : lang.translate('theme_light'),
            onTap: () => _showThemeDialog(context),
          ),
          _buildOption(
            context,
            icon: Icons.info,
            title: lang.translate('about_title'),
            subtitle: lang.translate('version'),
            onTap: () => _showAboutDialog(context),
          ),
          _buildOption(
            context,
            icon: Icons.delete_forever,
            title: lang.translate('delete_account_title'),
            subtitle: lang.translate('delete_account_subtitle'),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      final urlString = '${api.apiUrl}/v1/export.php?token=${api.token}';
      final url = Uri.parse(urlString);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(lang.translate('cannot_open_link'))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${lang.translate('error_generic')}: $e')),
        );
      }
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;
    final subtitleColor = isDark ? const Color(0xFF888888) : Colors.grey[700];
    final titleColor = theme.textTheme.bodyLarge?.color;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: dividerColor)),
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
                    style: TextStyle(color: titleColor, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subtitleColor),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final lang = LanguageService.instance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          lang.translate('choose_theme'),
          style: TextStyle(color: onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                lang.translate('theme_dark'),
                style: TextStyle(color: onSurface),
              ),
              leading: Icon(
                Icons.dark_mode,
                color: isDark ? const Color(0xFFBE1E1E) : onSurface,
              ),
              trailing: isDark
                  ? const Icon(Icons.check, color: Color(0xFFBE1E1E))
                  : null,
              onTap: () {
                Navigator.pop(context);
                ThemeManager.instance.setTheme(true);
              },
            ),
            ListTile(
              title: Text(
                lang.translate('theme_light'),
                style: TextStyle(color: onSurface),
              ),
              leading: Icon(
                Icons.light_mode,
                color: !isDark ? const Color(0xFFBE1E1E) : onSurface,
              ),
              trailing: !isDark
                  ? const Icon(Icons.check, color: Color(0xFFBE1E1E))
                  : null,
              onTap: () {
                Navigator.pop(context);
                ThemeManager.instance.setTheme(false);
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
        backgroundColor: Theme.of(
          context,
        ).scaffoldBackgroundColor, // Use theme/context color
        title: Text(
          LanguageService.instance.translate('choose_language'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
        _updateLanguage(code);
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final lang = LanguageService.instance;
    showAboutDialog(
      context: context,
      applicationName: 'Militant',
      applicationVersion: '1.0.0',
      applicationIcon: SvgPicture.asset(
        'assets/logo.svg',
        width: 80,
        height: 80,
      ),
      children: [
        Text(lang.translate('social_network')),
        const SizedBox(height: 16),
        Text(lang.translate('copyright')),
      ],
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
            lang.translate('delete_account_title'),
            style: const TextStyle(color: Color(0xFFBE1E1E)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.translate('delete_account_warning'),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  labelText: lang.translate('enter_password_to_delete'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                lang.translate('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;
                      setState(() => isLoading = true);
                      try {
                        final api = await ApiService.getInstance();
                        await api.post('/v1/delete_account.php', {
                          'password': passwordController.text,
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lang.translate('delete_account_request_sent'),
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBE1E1E),
                      ),
                    )
                  : Text(
                      lang.translate('delete_account_confirm'),
                      style: const TextStyle(color: Color(0xFFBE1E1E)),
                    ),
            ),
          ],
        ),
      ),
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
    final lang = LanguageService.instance;
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
          SnackBar(content: Text(lang.translate('password_changed'))),
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
    final theme = Theme.of(context);
    final lang = LanguageService.instance;
    final isDark = theme.brightness == Brightness.dark;
    final inputColor = theme.textTheme.bodyLarge?.color;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(lang.translate('change_password_title'))),
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
                style: TextStyle(color: inputColor),
                decoration: InputDecoration(
                  labelText: lang.translate('current_password'),
                  labelStyle: TextStyle(color: labelColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) =>
                    v!.isEmpty ? lang.translate('password_required') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                style: TextStyle(color: inputColor),
                decoration: InputDecoration(
                  labelText: lang.translate('new_password'),
                  labelStyle: TextStyle(color: labelColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) => v!.length < 8
                    ? lang.translate('password_min_length')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: inputColor),
                decoration: InputDecoration(
                  labelText: lang.translate('confirm_password'),
                  labelStyle: TextStyle(color: labelColor),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                  ),
                ),
                validator: (v) => v != _newPasswordController.text
                    ? lang.translate('password_match_error')
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
                    : Text(lang.translate('update_button')),
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
  // bool _emailEnabled = false; // Removed
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
    final lang = LanguageService.instance;
    try {
      final api = await ApiService.getInstance();
      final prefs = await api.getPreferences();

      if (mounted) {
        setState(() {
          _pushEnabled = _toBool(prefs['notifications_push'], true);
          // _emailEnabled = _toBool(prefs['notifications_email'], false);
          _likes = _toBool(prefs['notifications_likes'], true);
          _comments = _toBool(prefs['notifications_comments'], true);
          _follows = _toBool(prefs['notifications_follows'], true);
          _mentions = _toBool(prefs['notifications_mentions'], true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('loading_error')}: ${e.toString()}',
            ),
          ),
        );
      }
    }
  }

  bool _toBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return defaultValue;
  }

  Future<void> _updatePreference(String key, bool value) async {
    // Optimistic update
    setState(() {
      if (key == 'notifications_push') {
        _pushEnabled = value;
      } else if (key == 'notifications_likes') {
        _likes = value;
      } else if (key == 'notifications_comments') {
        _comments = value;
      } else if (key == 'notifications_follows') {
        _follows = value;
      } else if (key == 'notifications_mentions') {
        _mentions = value;
      }
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
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(lang.translate('notifications_title'))),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView(
              children: [
                _buildSectionHeader(
                  lang.translate('notifications_channels_title'),
                ),
                _buildSwitch(
                  lang.translate('notifications_push'),
                  lang.translate('notifications_push_subtitle'),
                  _pushEnabled,
                  (v) => _updatePreference('notifications_push', v),
                ),
                if (_pushEnabled) ...[
                  _buildSectionHeader(
                    lang.translate('notifications_interactions_title'),
                  ),
                  _buildSwitch(
                    lang.translate('notifications_likes'),
                    lang.translate('notifications_likes_subtitle'),
                    _likes,
                    (v) => _updatePreference('notifications_likes', v),
                  ),
                  _buildSwitch(
                    lang.translate('notifications_comments'),
                    lang.translate('notifications_comments_subtitle'),
                    _comments,
                    (v) => _updatePreference('notifications_comments', v),
                  ),
                  _buildSwitch(
                    lang.translate('notifications_follows'),
                    lang.translate('notifications_follows_subtitle'),
                    _follows,
                    (v) => _updatePreference('notifications_follows', v),
                  ),
                  _buildSwitch(
                    lang.translate('notifications_mentions'),
                    lang.translate('notifications_mentions_subtitle'),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFBE1E1E),
      tileColor: theme.scaffoldBackgroundColor, // Seamless with background
      title: Text(
        title,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey,
          fontSize: 12,
        ),
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
          _isPrivate = _toBool(prefs['privacy_private_account'], false);
          _allowMessages = _toBool(prefs['privacy_allow_messages'], true);
          _showOnlineStatus = _toBool(prefs['privacy_online_status'], true);
          _showReadReceipts = _toBool(prefs['privacy_read_receipts'], true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _toBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return defaultValue;
  }

  Future<void> _updatePreference(String key, bool value) async {
    setState(() {
      if (key == 'privacy_private_account') {
        _isPrivate = value;
      } else if (key == 'privacy_allow_messages')
        _allowMessages = value;
      else if (key == 'privacy_online_status')
        _showOnlineStatus = value;
      else if (key == 'privacy_read_receipts')
        _showReadReceipts = value;
    });

    try {
      final api = await ApiService.getInstance();
      await api.updatePreferences({key: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètre mis à jour'),
            duration: Duration(seconds: 1),
          ),
        );
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
    final theme = Theme.of(context);
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(lang.translate('privacy_title'))),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : ListView(
              children: [
                _buildSwitch(
                  lang.translate('privacy_private_account'),
                  lang.translate('privacy_private_subtitle'),
                  _isPrivate,
                  (v) => _updatePreference('privacy_private_account', v),
                ),
                Divider(color: theme.dividerColor),
                _buildSwitch(
                  lang.translate('privacy_allow_messages'),
                  lang.translate('privacy_allow_messages_subtitle'),
                  _allowMessages,
                  (v) => _updatePreference('privacy_allow_messages', v),
                ),
                _buildSwitch(
                  lang.translate('privacy_online_status'),
                  lang.translate('privacy_online_subtitle'),
                  _showOnlineStatus,
                  (v) => _updatePreference('privacy_online_status', v),
                ),
                _buildSwitch(
                  lang.translate('privacy_read_receipts'),
                  lang.translate('privacy_read_receipts_subtitle'),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFBE1E1E),
      tileColor: theme.scaffoldBackgroundColor,
      title: Text(
        title,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }
}
