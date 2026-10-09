import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../theme/theme_context.dart';
import 'login_screen.dart';

class BannedScreen extends StatelessWidget {
  final Map<String, dynamic> ban;

  const BannedScreen({super.key, required this.ban});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isPermanent = ban['is_permanent'] == 1 || ban['is_permanent'] == true;
    final expiresAt = ban['expires_at'];
    final reason = ban['reason'] ?? lang.translate('banned_reason_unspecified');
    final colors = context.colors;
    final muted = context.tokens.textMuted;
    final warning = context.isDark ? Colors.orange : Colors.orange.shade800;

    String durationText;
    if (isPermanent) {
      durationText = lang.translate('banned_permanent');
    } else if (expiresAt != null) {
      try {
        final expiry = DateTime.parse(expiresAt.replaceAll(' ', 'T'));
        final now = DateTime.now();
        final remaining = expiry.difference(now);
        if (remaining.inDays > 0) {
          durationText = lang
              .translate('banned_days_left')
              .replaceAll('{count}', '${remaining.inDays}');
        } else if (remaining.inHours > 0) {
          durationText = lang
              .translate('banned_hours_left')
              .replaceAll('{count}', '${remaining.inHours}');
        } else {
          durationText = lang.translate('banned_expires_soon');
        }
      } catch (_) {
        durationText = lang.translate('banned_duration_unknown');
      }
    } else {
      durationText = lang.translate('banned_duration_unknown');
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block,
                    size: 56,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Titre
                Text(
                  lang.translate('banned_title'),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Durée
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPermanent
                        ? colors.primary.withValues(alpha: 0.2)
                        : warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    durationText,
                    style: TextStyle(
                      color: isPermanent ? colors.primary : warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Raison
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.translate('banned_reason'),
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Info transparence
                Text(
                  lang.translate('banned_community_notice'),
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Bouton déconnexion
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final api = await ApiService.getInstance();
                      await api.clearToken();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    icon: Icon(Icons.logout, color: muted),
                    label: Text(
                      lang.translate('logout'),
                      style: TextStyle(color: muted),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.outline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
