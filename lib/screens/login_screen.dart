import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_switcher_service.dart';
import '../services/api_service.dart';
import '../services/incoming_call_service.dart';
import '../services/language_service.dart';
import '../services/message_notification_service.dart';
import '../services/notification_reply_service.dart';
import '../services/message_navigation_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import '../utils/error_helper.dart';

class LoginScreen extends StatefulWidget {
  final SavedAccount? fallbackAccount;
  final bool replaceStackOnAuth;

  const LoginScreen({
    super.key,
    this.fallbackAccount,
    this.replaceStackOnAuth = false,
  });

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
  List<SavedAccount> _savedAccounts = [];
  bool _isLoading = false;
  bool _showServerField = false;
  bool _requires2FA = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedServerUrl();
    _loadSavedAccounts();
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

  Future<void> _loadSavedAccounts() async {
    final accounts = await AccountSwitcherService.loadAccounts();
    if (!mounted) return;
    setState(() {
      _savedAccounts = accounts;
    });
  }

  String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  Future<void> _openHomeAfterAuth(ApiService api, int? loggedUserId) async {
    try {
      await api.initializeOneSignal();

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (loggedUserId != null) {
          final externalId = ApiService.oneSignalExternalIdFromUserId(
            loggedUserId,
          );
          if (externalId.isNotEmpty) {
            print('OneSignal Login with External ID: $externalId');
            OneSignal.login(externalId);
          }
        }
      }
    } catch (e) {
      print('OneSignal dynamic init error: $e');
    }

    try {
      await IncomingCallService.instance.initialize();
      await MessageNotificationService.instance.initialize();
      await NotificationReplyService.instance.initialize();
    } catch (e) {
      print('Incoming call init error: $e');
    }

    if (!mounted) return;
    final homeRoute = MaterialPageRoute(builder: (_) => const HomeScreen());
    if (widget.replaceStackOnAuth) {
      Navigator.of(context).pushAndRemoveUntil(homeRoute, (route) => false);
    } else {
      Navigator.of(context).pushReplacement(homeRoute);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IncomingCallService.instance.flushPendingAndroidIncomingIntent();
      MessageNavigationService.instance.flushPendingNotification();
    });
  }

  Future<void> _switchToSavedAccount(SavedAccount account) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final previousAccount =
        await AccountSwitcherService.activeSessionSnapshot();

    try {
      await AccountSwitcherService.activateAccount(account);
      final api = await ApiService.getInstance();
      final profile = await api.getProfile();

      final prefs = await SharedPreferences.getInstance();
      final userId = _extractUserId(profile) ?? account.userId;
      if (userId != null) {
        await prefs.setInt('user_id', userId);
      }

      await AccountSwitcherService.saveAccount(
        baseUrl: account.baseUrl,
        token: account.token,
        username:
            _extractString(profile, ['username', 'name']) ?? account.username,
        userId: userId,
        avatarUrl: _extractString(profile, ['avatar_url', 'avatar']),
      );

      await _openHomeAfterAuth(api, userId);
    } catch (e) {
      if (previousAccount != null) {
        await AccountSwitcherService.activateAccount(previousAccount);
      } else {
        final api = await ApiService.getInstance();
        await api.clearToken();
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = LanguageService.instance.translate(
          'saved_session_expired',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreFallbackAccount(SavedAccount? previousAccount) async {
    if (previousAccount != null) {
      await AccountSwitcherService.activateAccount(previousAccount);
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final previousAccount =
        widget.fallbackAccount ??
        await AccountSwitcherService.activeSessionSnapshot();
    if (previousAccount != null) {
      await AccountSwitcherService.upsertAccount(previousAccount);
    }

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
        await _restoreFallbackAccount(previousAccount);
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

        if (previousAccount != null) {
          await AccountSwitcherService.upsertAccount(previousAccount);
        }

        final token = result['token']?.toString() ?? api.token;
        if (token != null && token.isNotEmpty) {
          final user = result['user'];
          final userData = user is Map<String, dynamic> ? user : result;
          await AccountSwitcherService.saveAccount(
            baseUrl: serverUrl,
            token: token,
            username:
                _extractString(userData, ['username', 'name']) ??
                _usernameController.text.trim(),
            userId: loggedUserId,
            avatarUrl: _extractString(userData, ['avatar_url', 'avatar']),
          );
          await _loadSavedAccounts();
        }

        await _openHomeAfterAuth(api, loggedUserId);
      } else {
        await _restoreFallbackAccount(previousAccount);
        setState(() {
          _errorMessage =
              result['message'] ??
              LanguageService.instance.translate('login_error');
        });
      }
    } catch (e) {
      await _restoreFallbackAccount(previousAccount);
      setState(() {
        _errorMessage = getFriendlyErrorMessage(e);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final lang = LanguageService.instance;
    final emailController = TextEditingController(
      text: _usernameController.text.contains('@')
          ? _usernameController.text.trim()
          : '',
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final isDark = theme.brightness == Brightness.dark;
          String? dialogError;
          bool isSubmitting = false;

          return StatefulBuilder(
            builder: (context, dialogSetState) {
              Future<void> submit() async {
                final email = emailController.text.trim();
                if (email.isEmpty) {
                  dialogSetState(() {
                    dialogError = lang.translate('email_required_msg');
                  });
                  return;
                }

                dialogSetState(() {
                  isSubmitting = true;
                  dialogError = null;
                });

                try {
                  final api = await ApiService.getInstance();
                  final serverUrl = ApiService.normalizeBaseUrl(
                    _serverController.text.trim(),
                  );
                  api.baseUrl = serverUrl;

                  final result = await api.requestPasswordReset(email);
                  final message = result['message']?.toString();
                  if (result['success'] == false) {
                    throw Exception(
                      message != null && message.isNotEmpty
                          ? message
                          : lang.translate('login_error'),
                    );
                  }

                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        message != null && message.isNotEmpty
                            ? message
                            : lang.translate('forgot_password_success'),
                      ),
                    ),
                  );
                } catch (e) {
                  if (!dialogContext.mounted) return;
                  dialogSetState(() {
                    dialogError = getFriendlyErrorMessage(e);
                    isSubmitting = false;
                  });
                }
              }

              return AlertDialog(
                backgroundColor: theme.scaffoldBackgroundColor,
                title: Text(
                  lang.translate('forgot_password_title'),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('forgot_password_hint'),
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFAAAAAA)
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !isSubmitting,
                      onSubmitted: (_) => submit(),
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: InputDecoration(
                        labelText: lang.translate('email_label'),
                        labelStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF888888)
                              : Colors.grey[600],
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: isDark
                              ? const Color(0xFF888888)
                              : Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFBE1E1E),
                          ),
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: Text(lang.translate('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBE1E1E),
                      foregroundColor: Colors.white,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(lang.translate('forgot_password_send')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      emailController.dispose();
    }
  }

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

  Widget _buildSavedAccountsSection(bool isDark) {
    final lang = LanguageService.instance;
    final visibleAccounts = _savedAccounts.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            lang.translate('quick_accounts'),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...visibleAccounts.map((account) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFBE1E1E),
                foregroundColor: Colors.white,
                backgroundImage:
                    account.avatarUrl != null && account.avatarUrl!.isNotEmpty
                    ? NetworkImage(account.avatarUrl!)
                    : null,
                child: account.avatarUrl == null || account.avatarUrl!.isEmpty
                    ? Text(account.initial)
                    : null,
              ),
              title: Text(
                account.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                account.baseUrl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? const Color(0xFFAAAAAA) : Colors.grey[700],
                ),
              ),
              trailing: IconButton(
                tooltip: lang.translate('remove_saved_account'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: _isLoading
                    ? null
                    : () async {
                        await AccountSwitcherService.removeAccount(account.id);
                        await _loadSavedAccounts();
                      },
              ),
              onTap: _isLoading ? null : () => _switchToSavedAccount(account),
            ),
          );
        }),
      ],
    );
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
              const SizedBox(height: 20),

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
                lang.translate('app_subtitle'),
                style: TextStyle(
                  color: isDark ? const Color(0xFFAAAAAA) : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),

              if (_savedAccounts.isNotEmpty && !_requires2FA) ...[
                _buildSavedAccountsSection(isDark),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 16),

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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      lang.translate('forgot_password'),
                      style: const TextStyle(
                        color: Color(0xFFBE1E1E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  lang.translate('two_fa_required'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.translate('two_fa_code_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _totpController,
                  label: lang.translate('two_fa_code_label'),
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
                  child: Text(
                    lang.translate('back_to_login'),
                    style: const TextStyle(color: Color(0xFFBE1E1E)),
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
                      ? lang.translate('hide_server')
                      : lang.translate('change_server'),
                  style: const TextStyle(color: Color(0xFFBE1E1E)),
                ),
              ),
              const SizedBox(height: 24),

              // Lien vers inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${lang.translate('no_account_yet')} ',
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
                    child: Text(
                      lang.translate('sign_up'),
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
    _totpController.dispose();
    super.dispose();
  }
}
