import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import 'login_screen.dart';

class BannedScreen extends StatelessWidget {
  final Map<String, dynamic> ban;

  const BannedScreen({super.key, required this.ban});

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isPermanent = ban['is_permanent'] == 1 || ban['is_permanent'] == true;
    final expiresAt = ban['expires_at'];
    final reason = ban['reason'] ?? 'Non spécifié';

    String durationText;
    if (isPermanent) {
      durationText = 'Ban permanent';
    } else if (expiresAt != null) {
      try {
        final expiry = DateTime.parse(expiresAt.replaceAll(' ', 'T'));
        final now = DateTime.now();
        final remaining = expiry.difference(now);
        if (remaining.inDays > 0) {
          durationText = 'Encore ${remaining.inDays} jour(s)';
        } else if (remaining.inHours > 0) {
          durationText = 'Encore ${remaining.inHours} heure(s)';
        } else {
          durationText = 'Expire bientôt';
        }
      } catch (_) {
        durationText = 'Durée inconnue';
      }
    } else {
      durationText = 'Durée inconnue';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
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
                    color: const Color(0xFFBE1E1E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    size: 56,
                    color: Color(0xFFBE1E1E),
                  ),
                ),
                const SizedBox(height: 32),

                // Titre
                const Text(
                  'Compte suspendu',
                  style: TextStyle(
                    color: Colors.white,
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
                        ? const Color(0xFFBE1E1E).withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    durationText,
                    style: TextStyle(
                      color: isPermanent ? const Color(0xFFBE1E1E) : Colors.orange,
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
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Motif :',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Info transparence
                const Text(
                  'Cette sanction a été appliquée automatiquement par la communauté suite à des signalements validés.',
                  style: TextStyle(
                    color: Colors.white38,
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
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    label: const Text(
                      'Se déconnecter',
                      style: TextStyle(color: Colors.white54),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
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
