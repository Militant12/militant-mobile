import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class TwoFactorSettingsScreen extends StatefulWidget {
  const TwoFactorSettingsScreen({super.key});

  @override
  State<TwoFactorSettingsScreen> createState() =>
      _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState extends State<TwoFactorSettingsScreen> {
  bool _isLoading = true;
  bool _isEnabled = false;
  String? _secret;
  String? _otpauthUrl;
  final _codeController = TextEditingController();
  List<String>? _recoveryCodes;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final lang = LanguageService.instance;
    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final status = await api.getTwoFactorStatus();
      setState(() {
        _isEnabled = status['enabled'] ?? false;
        _secret = status['secret'];
        _otpauthUrl = status['otpauth_url'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
      }
    }
  }

  Future<void> _enable() async {
    final lang = LanguageService.instance;
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('enter_6_digit_code'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      final result = await api.enableTwoFactor(_codeController.text);
      setState(() {
        _isEnabled = true;
        _recoveryCodes = List<String>.from(result['recovery_codes'] ?? []);
        _isLoading = false;
      });
      if (mounted) {
        _showRecoveryCodesDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang.translate('error')}: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _disable() async {
    final lang = LanguageService.instance;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('disable_2fa_question')),
        content: Text(lang.translate('account_less_secure')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              lang.translate('disable_2fa'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final api = await ApiService.getInstance();
      await api.disableTwoFactor();
      _loadStatus();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${lang.translate('error')}: $e')));
      }
    }
  }

  void _showRecoveryCodesDialog() {
    final lang = LanguageService.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(lang.translate('recovery_codes')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.translate('recovery_codes_message')),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Column(
                children: _recoveryCodes!
                    .map(
                      (c) => Text(
                        c,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: _recoveryCodes!.join('\n')),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(lang.translate('codes_copied'))));
            },
            child: Text(lang.translate('copy_all')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.translate('saved_codes')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('two_factor_auth'))),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Icon(
                      _isEnabled ? Icons.verified_user : Icons.security,
                      size: 80,
                      color: _isEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isEnabled
                        ? lang.translate('2fa_enabled')
                        : lang.translate('secure_your_account'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isEnabled
                        ? lang.translate('2fa_enabled_message')
                        : lang.translate('2fa_description'),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isEnabled && _secret != null) ...[
                    Text(
                      lang.translate('scan_qr_code'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _otpauthUrl!,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      lang.translate('or_copy_secret'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _secret!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _secret!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(lang.translate('secret_copied'))),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      lang.translate('enter_validation_code'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: lang.translate('six_digit_code'),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFBE1E1E)),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _enable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBE1E1E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(lang.translate('enable_2fa')),
                      ),
                    ),
                  ],
                  if (_isEnabled) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _disable,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: Text(lang.translate('disable_2fa')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
