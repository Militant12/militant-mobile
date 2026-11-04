import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// Compteur qui roule au lieu de sauter : vers le haut quand il augmente,
/// vers le bas quand il baisse.
class RollingCount extends StatefulWidget {
  const RollingCount({super.key, required this.count, this.style});

  final int count;
  final TextStyle? style;

  @override
  State<RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<RollingCount> {
  bool _up = true;

  @override
  void didUpdateWidget(RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) _up = widget.count > oldWidget.count;
  }

  @override
  Widget build(BuildContext context) {
    final direction = _up ? 1.0 : -1.0;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.quick),
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.standard,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          // Le nouveau chiffre arrive d'en bas (ou d'en haut s'il baisse),
          // l'ancien part de l'autre côté.
          final incoming = child.key == ValueKey<int>(widget.count);
          final begin = Offset(0, (incoming ? direction : -direction) * 0.8);
          return SlideTransition(
            position: Tween(begin: begin, end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(
          '${widget.count}',
          key: ValueKey<int>(widget.count),
          style: widget.style,
        ),
      ),
    );
  }
}
