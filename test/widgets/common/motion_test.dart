import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_motion.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/common.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  group('AppMotion', () {
    testWidgets('les durées tombent à zéro sans animations', (tester) async {
      late Duration normal;
      late Duration reduced;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        normal = AppMotion.of(context, AppMotion.base);
        return const SizedBox();
      })));
      await tester.pumpWidget(_app(reduceMotion: true, Builder(builder: (context) {
        reduced = AppMotion.of(context, AppMotion.base);
        return const SizedBox();
      })));
      expect(normal, const Duration(milliseconds: 300));
      expect(reduced, Duration.zero);
    });
  });

  group('RollingCount', () {
    testWidgets('roule vers le nouveau nombre', (tester) async {
      await tester.pumpWidget(_app(const RollingCount(count: 41)));
      await tester.pumpWidget(_app(const RollingCount(count: 42)));
      await tester.pump(const Duration(milliseconds: 50));
      // Pendant l'animation, l'ancien et le nouveau se croisent.
      expect(find.text('41'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('41'), findsNothing);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('saute directement sans animations', (tester) async {
      await tester.pumpWidget(_app(const RollingCount(count: 41), reduceMotion: true));
      await tester.pumpWidget(_app(const RollingCount(count: 42), reduceMotion: true));
      await tester.pump();
      expect(find.text('41'), findsNothing);
      expect(find.text('42'), findsOneWidget);
    });
  });

  group('LiveBadge', () {
    testWidgets('le point pulse', (tester) async {
      await tester.pumpWidget(_app(const LiveBadge()));
      expect(find.text('EN DIRECT'), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('s’arrête sans animations, le mot reste', (tester) async {
      await tester.pumpWidget(_app(const LiveBadge(), reduceMotion: true));
      expect(find.text('EN DIRECT'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('EmptyState', () {
    const state = EmptyState(
      icon: Icons.event_outlined,
      title: 'Aucun événement',
      message: 'Les rassemblements à venir apparaîtront ici.',
    );

    testWidgets('apparaît en douceur', (tester) async {
      await tester.pumpWidget(_app(state));
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('Aucun événement'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Aucun événement'), findsOneWidget);
    });

    testWidgets('est là d’emblée sans animations', (tester) async {
      await tester.pumpWidget(_app(state, reduceMotion: true));
      expect(
        find.ancestor(of: find.text('Aucun événement'), matching: find.byType(Opacity)),
        findsNothing,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
