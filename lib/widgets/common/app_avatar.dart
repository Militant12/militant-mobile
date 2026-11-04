import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/app_theme.dart';
import '../../theme/theme_context.dart';

/// Avatar rond commun (utilisateur, groupe, page).
///
/// [url] doit déjà être résolue (`ApiService.getImageUrl`). Sans image, ou si
/// elle ne se charge pas, affiche les initiales de [name] (deux au plus) sur
/// `surface-alt`, ou le logo Militant si [name] est vide.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.url,
    this.name,
    this.radius = 20,
    this.semanticLabel,
    this.online = false,
  });

  final String? url;
  final String? name;
  final double radius;

  /// Libellé lu par les lecteurs d'écran (par défaut : [name]).
  final String? semanticLabel;

  /// Affiche la pastille verte « en ligne » en bas à droite.
  final bool online;

  double get _size => radius * 2;

  /// « Collectif Banlieues » → « CB », « camille » → « C ».
  String? get _initials {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2);
    if (words.isEmpty) return null;
    return words.map((w) => w.characters.first.toUpperCase()).join();
  }

  Widget _fallback(BuildContext context) {
    final initials = _initials;
    if (initials == null) {
      return SvgPicture.asset(
        'assets/logo.svg',
        width: _size,
        height: _size,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: _size,
      height: _size,
      color: context.colors.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Text(
        initials,
        maxLines: 1,
        style: TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.fallback,
          color: context.colors.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: radius * (initials.characters.length > 1 ? 0.7 : 0.8),
          height: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final src = url?.trim();
    final Widget image;
    if (src == null || src.isEmpty) {
      image = _fallback(context);
    } else if (src.toLowerCase().endsWith('.svg')) {
      image = SvgPicture.network(
        src,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholderBuilder: (context) => _fallback(context),
      );
    } else {
      image = Image(
        image: CachedNetworkImageProvider(src),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _fallback(context),
      );
    }

    // Fond gris visible pendant le chargement de l'image.
    Widget avatar = ClipOval(
      child: ColoredBox(
        color: context.colors.surfaceContainerHigh,
        child: SizedBox.square(dimension: _size, child: image),
      ),
    );
    if (online) {
      final dot = (radius * 0.6).clamp(8.0, 16.0);
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: context.tokens.success,
                shape: BoxShape.circle,
                // Liseré couleur de surface pour détacher la pastille.
                border: Border.all(color: context.colors.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    final label = semanticLabel ?? name;
    return Semantics(
      label: label,
      image: label != null,
      excludeSemantics: true,
      child: avatar,
    );
  }
}
