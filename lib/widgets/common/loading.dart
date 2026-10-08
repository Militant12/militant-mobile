import 'package:flutter/material.dart';

import '../../services/language_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/theme_context.dart';

/// Indicateur de chargement centré, aux couleurs du thème.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          color: context.colors.primary,
          semanticsLabel: LanguageService.instance.translate('loading'),
        ),
      ),
    );
  }
}

/// Bloc gris qui pulse, pour dessiner des squelettes de chargement.
///
/// Plusieurs [SkeletonBox] placés sous un même [SkeletonPulse] pulsent
/// ensemble ; seuls, ils pulsent chacun de leur côté.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppTokens.radius8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
    if (SkeletonPulse.isActive(context)) return box;
    return SkeletonPulse(child: box);
  }
}

/// Anime l'opacité de ses descendants pour signaler un chargement.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  /// Vrai si [context] est déjà sous un [SkeletonPulse].
  static bool isActive(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SkeletonPulseScope>() != null;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage système « réduire les animations ».
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulseScope(
      child: Semantics(
        label: LanguageService.instance.translate('loading'),
        child: ExcludeSemantics(
          child: FadeTransition(opacity: _controller, child: widget.child),
        ),
      ),
    );
  }
}

class _SkeletonPulseScope extends InheritedWidget {
  const _SkeletonPulseScope({required super.child});

  @override
  bool updateShouldNotify(_SkeletonPulseScope oldWidget) => false;
}

/// Squelette d'une ligne de liste : avatar + deux lignes de texte.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key, this.avatarRadius = 20});

  final double avatarRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space8,
      ),
      child: Row(
        children: [
          SkeletonBox(height: avatarRadius * 2, circle: true),
          const SizedBox(width: AppTokens.space12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: SkeletonBox(height: 12),
                ),
                SizedBox(height: AppTokens.space8),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  child: SkeletonBox(height: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste de [SkeletonListTile] qui pulsent ensemble.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => const SkeletonListTile(),
      ),
    );
  }
}
