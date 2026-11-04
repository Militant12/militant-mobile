import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

/// État vide centré : vignette, titre, message optionnel et action
/// optionnelle. L'écran dit ce qui apparaîtra ici et propose l'action qui le
/// remplit.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Bouton affiché sous le texte (ex. « Créer un groupe »).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = context.tokens.textMuted;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space24,
          vertical: AppTokens.space32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateVignette(icon: icon),
            const SizedBox(height: AppTokens.space24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.space8),
              // Une ligne d'environ 32 caractères, plus facile à lire.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(color: muted),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Le carré du logo, coupé par sa diagonale (rouge en haut à gauche, noir en
/// bas à droite), avec l'icône du sujet par-dessus.
class EmptyStateVignette extends StatelessWidget {
  const EmptyStateVignette({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final noir = context.tokens.noir;
    return ExcludeSemantics(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radius20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.primary, colors.primary, noir, noir],
            stops: const [0, 0.5, 0.5, 1],
          ),
        ),
        child: Icon(icon, size: 32, color: colors.onPrimary),
      ),
    );
  }
}
