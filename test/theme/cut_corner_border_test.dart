import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/theme/cut_corner_border.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 120, 48);

  group('CutCornerBorder', () {
    test('coupe le coin bas-droit, arrondit les trois autres', () {
      final path = AppShapes.medium.getOuterPath(rect);
      // Centre et milieux des bords : dedans.
      expect(path.contains(const Offset(60, 24)), isTrue);
      expect(path.contains(const Offset(119, 24)), isTrue);
      expect(path.contains(const Offset(60, 47)), isTrue);
      // Les coins arrondis enlèvent le sommet, mais pas plus.
      expect(path.contains(const Offset(0.5, 0.5)), isFalse);
      expect(path.contains(const Offset(4, 4)), isTrue);
      // Le coin coupé : la diagonale x + y = 120 + 48 − 12 sépare.
      expect(path.contains(const Offset(119, 47)), isFalse);
      expect(path.contains(const Offset(116, 44)), isFalse);
      expect(path.contains(const Offset(110, 40)), isTrue);
    });

    test('reste valide sur une forme plus petite que la coupe', () {
      final path = AppShapes.large.getOuterPath(const Rect.fromLTWH(0, 0, 20, 10));
      expect(path.getBounds(), const Rect.fromLTWH(0, 0, 20, 10));
    });

    test('copyWith garde la coupe et change le contour', () {
      const side = BorderSide(color: Colors.red, width: 2);
      final copy = AppShapes.small.copyWith(side: side);
      expect(copy.side, side);
      expect(copy.cut, AppShapes.small.cut);
      expect(copy.radius, AppShapes.small.radius);
    });

    test('se laisse interpoler (animation au survol)', () {
      final open = AppShapes.medium.copyWith(cut: 16);
      final half = ShapeBorder.lerp(AppShapes.medium, open, 0.5);
      expect(half, isA<CutCornerBorder>());
      expect((half! as CutCornerBorder).cut, 14);
    });

    test('dessine son contour sans erreur', () {
      final recorder = ui.PictureRecorder();
      AppShapes.medium
          .copyWith(side: const BorderSide(width: 1.5))
          .paint(ui.Canvas(recorder), rect);
      recorder.endRecording();
    });
  });

  group('thème', () {
    Future<OutlinedBorder?> shapeOf(WidgetTester tester, Widget button) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Center(child: button)),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(of: find.byWidget(button), matching: find.byType(Material)).first,
      );
      return material.shape as OutlinedBorder?;
    }

    testWidgets('les boutons ont le coin coupé et 48px de haut', (tester) async {
      for (final button in [
        FilledButton(onPressed: () {}, child: const Text('Publier')),
        OutlinedButton(onPressed: () {}, child: const Text('Partager')),
        ElevatedButton(onPressed: () {}, child: const Text('Suivre')),
        TextButton(onPressed: () {}, child: const Text('Voir tout')),
      ]) {
        expect(await shapeOf(tester, button), isA<CutCornerBorder>());
      }
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(40),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('Publier')),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(FilledButton)).height, 48);
    });

    testWidgets('le contour du bouton secondaire suit la coupe', (tester) async {
      final shape = await shapeOf(
        tester,
        OutlinedButton(onPressed: () {}, child: const Text('Partager')),
      );
      expect(shape!.side.color, AppTheme.light().colorScheme.outline);
    });

    test('bouton flottant, chips et barre du bas', () {
      final theme = AppTheme.dark();
      expect(theme.floatingActionButtonTheme.shape, AppShapes.large);
      expect(theme.chipTheme.shape, AppShapes.small);
      expect(theme.navigationBarTheme.indicatorShape, AppShapes.small);
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.primaryContainer,
      );
    });
  });
}
