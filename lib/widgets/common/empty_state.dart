import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
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
          // Les éléments montent l'un après l'autre en apparaissant.
          children: [
            _Rise(order: 0, child: EmptyStateVignette(icon: icon)),
            const SizedBox(height: AppTokens.space24),
            _Rise(
              order: 1,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: context.text.titleLarge,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppTokens.space8),
              // Une ligne d'environ 32 caractères, plus facile à lire.
              _Rise(
                order: 2,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.space24),
              _Rise(order: 3, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Monte de 12px en apparaissant, [order] × 60 ms après le premier élément.
/// Sans animation, l'élément est là d'emblée.
class _Rise extends StatelessWidget {
  const _Rise({required this.order, required this.child});

  final int order;
  final Widget child;

  static const Duration _stagger = Duration(milliseconds: 60);

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final delay = _stagger * order;
    final total = AppMotion.slow + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.enter,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: child,
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
