import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/common.dart';
import 'package:militant/widgets/post_card.dart';

void main() {
  testWidgets('les squelettes de post pulsent ensemble', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: SkeletonPulse(
              child: Column(children: [PostCardSkeleton(), PostCardSkeleton()]),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PostCardSkeleton), findsNWidgets(2));
    // Les SkeletonBox réutilisent l'animation parente au lieu d'en créer une.
    expect(find.byType(SkeletonPulse), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
