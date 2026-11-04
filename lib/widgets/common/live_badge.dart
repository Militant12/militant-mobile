import 'package:flutter/material.dart';

import '../../services/language_service.dart';
import '../../theme/app_motion.dart';
import '../../theme/cut_corner_border.dart';
import '../../theme/theme_context.dart';

/// Pastille « En direct » : aplat rouge, libellé en capitales (`eyebrow`),
/// coin bas-droit coupé comme les boutons puisqu'elle invite à rejoindre le
/// live. Son point pulse doucement, sauf si le système demande moins
/// d'animations ; le mot reste.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key});

  static const Duration pulse = Duration(milliseconds: 900);

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: LiveBadge.pulse,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = LanguageService.instance.translate('live_tab_discover');
    return DecoratedBox(
      decoration: ShapeDecoration(color: colors.primary, shape: AppShapes.small),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _pulse.drive(Tween(begin: 0.35, end: 1)),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.onPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: context.eyebrow.copyWith(color: colors.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
