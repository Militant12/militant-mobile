import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MilitantBadge extends StatelessWidget {
  final String? badgeId;
  final double size;

  const MilitantBadge({super.key, required this.badgeId, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (badgeId == null || badgeId!.isEmpty) {
      return const SizedBox.shrink();
    }

    final badgePath = _getBadgePath(badgeId!);

    if (badgePath == null) {
      return const SizedBox.shrink();
    }

    // Déterminer si c'est un SVG ou une image
    final isSvg = badgePath.endsWith('.svg');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: ClipOval(
        child: isSvg
            ? SvgPicture.asset(
                badgePath,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : Image.asset(
                badgePath,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  String? _getBadgePath(String badgeId) {
    final badges = {
      'maknosocial': 'assets/badges/militant.svg',
      'antifa': 'assets/badges/antifa.svg',
      'anarchist': 'assets/badges/anarchist.svg',
      'cnt-ait': 'assets/badges/cnt-ait.png',
      'cnt-f': 'assets/badges/cnt-f.jpg',
      'cnt-so': 'assets/badges/cnt-so.png',
      'fa': 'assets/badges/fa.png',
      'ocl': 'assets/badges/ocl.gif',
      'cga': 'assets/badges/cga.svg',
      'ucl': 'assets/badges/ucl.jpg',
      'fll': 'assets/badges/fll.jpg',
      'slm': 'assets/badges/slm.png',
    };

    return badges[badgeId];
  }
}
