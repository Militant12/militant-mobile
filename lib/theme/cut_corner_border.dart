import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Le coin coupé de Militant : trois coins arrondis et le coin bas-droit
/// coupé à 45°, parallèle à la diagonale du logo. Les deux angles de la
/// coupe sont adoucis par [cutRadius].
///
/// Réservé à ce qu'on peut toucher : boutons, chips, indicateur de l'onglet
/// actif, bouton flottant, pastille En direct. Les cartes, champs et images
/// gardent leurs quatre coins arrondis.
/// Les trois tailles de la charte.
abstract final class AppShapes {
  /// Chips, indicateur de l'onglet actif, pastille En direct (`cut-sm`).
  static const CutCornerBorder small = CutCornerBorder(
    radius: 8,
    cut: 8,
    cutRadius: 3,
  );

  /// Boutons (`cut-md`).
  static const CutCornerBorder medium = CutCornerBorder();

  /// Bouton flottant (`cut-lg`).
  static const CutCornerBorder large = CutCornerBorder(
    radius: 20,
    cut: 16,
    cutRadius: 5,
  );
}

class CutCornerBorder extends OutlinedBorder {
  const CutCornerBorder({
    super.side,
    this.radius = 12,
    this.cut = 12,
    this.cutRadius = 4,
  });

  /// Rayon des trois coins arrondis.
  final double radius;

  /// Longueur de la coupe, mesurée sur chacun des deux bords.
  final double cut;

  /// Rayon des deux angles de la coupe.
  final double cutRadius;

  /// Distance entre l'angle de la coupe et le début de son arrondi :
  /// `cutRadius · tan(22,5°)`, la coupe déviant le bord de 45°.
  static final double _tangentFactor = math.tan(math.pi / 8);

  Path _path(Rect rect, double radius, double cut, double cutRadius) {
    final maxSize = math.min(rect.width, rect.height) / 2;
    final r = radius.clamp(0.0, maxSize);
    final c = cut.clamp(0.0, maxSize);
    // L'arrondi ne doit pas dépasser la moitié de la coupe.
    final d = math.min(cutRadius * _tangentFactor, c / 2);
    final cr = d / _tangentFactor;
    final diagonal = d / math.sqrt2;
    final path = Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.top + r),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.right, rect.bottom - c - d);
    if (cr > 0) {
      path.arcToPoint(
        Offset(rect.right - diagonal, rect.bottom - c + diagonal),
        radius: Radius.circular(cr),
      );
    }
    path.lineTo(rect.right - c + diagonal, rect.bottom - diagonal);
    if (cr > 0) {
      path.arcToPoint(
        Offset(rect.right - c - d, rect.bottom),
        radius: Radius.circular(cr),
      );
    }
    return path
      ..lineTo(rect.left + r, rect.bottom)
      ..arcToPoint(
        Offset(rect.left, rect.bottom - r),
        radius: Radius.circular(r),
      )
      ..lineTo(rect.left, rect.top + r)
      ..arcToPoint(
        Offset(rect.left + r, rect.top),
        radius: Radius.circular(r),
      )
      ..close();
  }

  /// Forme décalée de [delta] vers l'intérieur (négatif : l'extérieur), en
  /// gardant les bords parallèles.
  Path _offsetPath(Rect rect, double delta) {
    return _path(
      rect.deflate(delta),
      math.max(0, radius - delta),
      // Une coupe à 45° décalée de delta raccourcit de delta · (2 − √2) sur
      // chaque bord.
      math.max(0, cut - delta * (2 - math.sqrt2)),
      math.max(0, cutRadius - delta),
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _offsetPath(rect, side.strokeInset);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect, radius, cut, cutRadius);

  @override
  bool get preferPaintInterior => true;

  @override
  void paintInterior(
    Canvas canvas,
    Rect rect,
    Paint paint, {
    TextDirection? textDirection,
  }) {
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty || side.style == BorderStyle.none || side.width == 0) {
      return;
    }
    final ring = _offsetPath(rect, -side.strokeOutset)
      ..addPath(_offsetPath(rect, side.strokeInset), Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(ring, Paint()..color = side.color);
  }

  @override
  CutCornerBorder copyWith({
    BorderSide? side,
    double? radius,
    double? cut,
    double? cutRadius,
  }) {
    return CutCornerBorder(
      side: side ?? this.side,
      radius: radius ?? this.radius,
      cut: cut ?? this.cut,
      cutRadius: cutRadius ?? this.cutRadius,
    );
  }

  @override
  ShapeBorder scale(double t) => CutCornerBorder(
    side: side.scale(t),
    radius: radius * t,
    cut: cut * t,
    cutRadius: cutRadius * t,
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CutCornerBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CutCornerBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  static CutCornerBorder _lerp(CutCornerBorder a, CutCornerBorder b, double t) {
    return CutCornerBorder(
      side: BorderSide.lerp(a.side, b.side, t),
      radius: lerpDouble(a.radius, b.radius, t)!,
      cut: lerpDouble(a.cut, b.cut, t)!,
      cutRadius: lerpDouble(a.cutRadius, b.cutRadius, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CutCornerBorder &&
      other.side == side &&
      other.radius == radius &&
      other.cut == cut &&
      other.cutRadius == cutRadius;

  @override
  int get hashCode => Object.hash(side, radius, cut, cutRadius);

  @override
  String toString() =>
      'CutCornerBorder($side, radius: $radius, cut: $cut, cutRadius: $cutRadius)';
}
