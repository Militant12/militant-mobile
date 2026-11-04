import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/stamp.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

void main() {
  const stamp = Stamp(label: "J'y serai", semanticLabel: 'Tu participes');

  testWidgets('libellé en capitales, couleur brand-ink, de travers', (tester) async {
    await tester.pumpWidget(_app(stamp));
    final text = tester.widget<Text>(find.text("J'Y SERAI"));
    expect(text.style?.color, AppTheme.dark().colorScheme.onPrimaryContainer);
    expect(text.style?.fontFamily, AppFonts.display);
    final rotation = tester.widget<Transform>(
      find.ancestor(of: find.text("J'Y SERAI"), matching: find.byType(Transform)).last,
    );
    expect(rotation.transform.getRotation().isIdentity(), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('annoncé comme un statut', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(stamp));
    expect(find.bySemanticsLabel('Tu participes'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('arrive en s’animant juste après l’engagement', (tester) async {
    await tester.pumpWidget(
      _app(const Stamp(label: 'Rejoint', semanticLabel: 'Membre', animate: true)),
    );
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('REJOINT'), findsOneWidget);
  });

  testWidgets('posé directement sans animations', (tester) async {
    await tester.pumpWidget(
      _app(
        const Stamp(label: 'Rejoint', semanticLabel: 'Membre', animate: true),
        reduceMotion: true,
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('REJOINT'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1);
  });
}
