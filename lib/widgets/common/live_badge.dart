import 'package:flutter/material.dart';

import '../../services/language_service.dart';
import '../../theme/cut_corner_border.dart';
import '../../theme/theme_context.dart';

/// Pastille « En direct » : aplat rouge, libellé en capitales (`eyebrow`),
/// coin bas-droit coupé comme les boutons puisqu'elle invite à rejoindre le
/// live.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

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
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.onPrimary,
                shape: BoxShape.circle,
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
