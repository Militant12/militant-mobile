import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

/// État vide centré : icône, titre, message optionnel et action optionnelle.
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
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: muted),
            const SizedBox(height: AppTokens.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.space8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.space16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
