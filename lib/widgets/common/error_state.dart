import 'package:flutter/material.dart';

import '../../services/language_service.dart';
import '../../theme/theme_context.dart';
import '../../utils/error_helper.dart';
import 'empty_state.dart';

/// État d'erreur centré avec bouton « Réessayer ».
///
/// [error] est passé à `getFriendlyErrorMessage` : pas de message technique
/// affiché à l'utilisateur.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.error,
    this.title,
    this.onRetry,
    this.icon = Icons.wifi_off_outlined,
  });

  final Object? error;

  /// Titre (par défaut : « Erreur » traduit).
  final String? title;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    return EmptyState(
      icon: icon,
      title: title ?? lang.translate('error_generic'),
      message: error == null ? null : getFriendlyErrorMessage(error, lang),
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(lang.translate('retry')),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
              ),
            ),
    );
  }
}
