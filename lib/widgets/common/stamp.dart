import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

/// Le tampon qui marque un engagement de la personne : « J'y serai » sur un
/// événement, « Rejoint » sur un groupe. Rien d'autre (ni J'aime, ni
/// abonnement), sinon il ne voudrait plus rien dire.
///
/// Cadre double en brand-ink, légèrement de travers, posé à côté du texte et
/// jamais par-dessus. Avec [animate], il arrive grand et penché, s'écrase un
/// peu sur la carte puis se stabilise ; sans animation système, il est là
/// d'emblée.
class Stamp extends StatefulWidget {
  const Stamp({
    super.key,
    required this.label,
    required this.semanticLabel,
    this.animate = false,
  });

  /// Deux mots au plus, mis en capitales par le composant.
  final String label;

  /// Annoncé comme un statut aux lecteurs d'écran (« Tu participes »).
  final String semanticLabel;

  /// Faire arriver le tampon (juste après l'engagement).
  final bool animate;

  static const double _restAngle = -6 * math.pi / 180;

  @override
  State<Stamp> createState() => _StampState();
}

class _StampState extends State<Stamp> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
    value: 1,
  );

  // 1,7 → 0,92 (il s'écrase en touchant la carte) → 1.
  static final Animatable<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.7, end: 0.92).chain(CurveTween(curve: Curves.easeIn)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: AppMotion.enter)),
      weight: 30,
    ),
  ]);
  static final Animatable<double> _angle = Tween(
    begin: -16 * math.pi / 180,
    end: Stamp._restAngle,
  ).chain(CurveTween(curve: AppMotion.enter));
  static final Animatable<double> _opacity = CurveTween(
    curve: const Interval(0, 0.3),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.animate) _land();
    }
  }

  @override
  void didUpdateWidget(Stamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) _land();
  }

  void _land() {
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: widget.animate,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Opacity(
            opacity: _opacity.transform(t),
            child: Transform.rotate(
              angle: _angle.transform(t),
              child: Transform.scale(scale: _scale.transform(t), child: child),
            ),
          );
        },
        child: _StampFace(label: widget.label),
      ),
    );
  }
}

class _StampFace extends StatelessWidget {
  const _StampFace({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onPrimaryContainer;
    // Un trait, un liseré de la couleur de la carte, un second trait.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: ink, width: 2),
        borderRadius: BorderRadius.circular(AppTokens.radius8),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: 1.2),
          borderRadius: BorderRadius.circular(AppTokens.radius8 - 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 16, color: ink),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.3,
                letterSpacing: 1,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
