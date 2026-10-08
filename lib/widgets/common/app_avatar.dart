import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/theme_context.dart';

/// Avatar rond commun (utilisateur, groupe, page).
///
/// [url] doit déjà être résolue (`ApiService.getImageUrl`). Sans image, ou si
/// elle ne se charge pas, affiche l'initiale de [name] sur fond rouge, ou le
/// logo Militant si [name] est vide.
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

  String? get _initial {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed.characters.first.toUpperCase();
  }

  Widget _fallback(BuildContext context) {
    final initial = _initial;
    if (initial == null) {
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
      color: context.colors.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: context.colors.onPrimary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
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
      image = Image.network(
        src,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, __) => _fallback(context),
      );
    }

    Widget avatar = ClipOval(
      child: SizedBox.square(dimension: _size, child: image),
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
