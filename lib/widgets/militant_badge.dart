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
        color: Colors
            .white, // Fond blanc pour faire ressortir les logos foncés comme FA ou l'A cerclé
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
      'militant': 'assets/badges/militant.svg',
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
      'iwa-ait': 'assets/badges/iwa-ait.png',
      'iww': 'assets/badges/iww.svg',
      'iaf-ifa': 'assets/badges/iaf-ifa.png',
      'cnt-ait-e': 'assets/badges/cnt-ait-e.jpg',
      'ulet-ait': 'assets/badges/ulet-ait.png',
      'anarchist-front': 'assets/badges/anarchist-front.png',
      'cci': 'assets/badges/cci.png',
      'cob-ait': 'assets/badges/cob-ait.png',
      'controverses': 'assets/badges/controverses.png',
      'fai': 'assets/badges/fai.png',
      'fora-ait': 'assets/badges/fora-ait.jpg',
      'garap': 'assets/badges/garap.png',
      'gigc': 'assets/badges/gigc.png',
      'kras-ait': 'assets/badges/kras-ait.png',
      'nsf-iaa': 'assets/badges/nsf-iaa.png',
      'ols': 'assets/badges/ols.png',
      'organisation-anarchiste': 'assets/badges/organisation-anarchiste.png',
      'priama-akcia': 'assets/badges/priama-akcia.png',
      'so-ait': 'assets/badges/so-ait.png',
      'solfed': 'assets/badges/solfed.jpg',
      'tci': 'assets/badges/tci.png',
      'was-ait': 'assets/badges/was-ait.png',
      'wsf': 'assets/badges/wsf.jpg',
    };

    return badges[badgeId];
  }
}
