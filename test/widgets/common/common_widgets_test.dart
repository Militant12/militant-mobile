import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/theme/app_colors.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/common.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.dark(),
  home: Scaffold(body: child),
);

void main() {
  group('AppAvatar', () {
    testWidgets('affiche l’initiale sur fond rouge sans image', (tester) async {
      await tester.pumpWidget(_app(const AppAvatar(name: 'émile')));
      expect(find.text('É'), findsOneWidget);
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('É'), matching: find.byType(Container)),
      );
      expect(box.color, AppColors.militantRed);
    });

    testWidgets('respecte le rayon demandé', (tester) async {
      await tester.pumpWidget(
        _app(const Center(child: AppAvatar(name: 'A', radius: 14))),
      );
      expect(tester.getSize(find.byType(AppAvatar)), const Size(28, 28));
    });

    testWidgets('est annoncé avec le nom aux lecteurs d’écran', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const AppAvatar(name: 'Louise')));
      expect(find.bySemanticsLabel('Louise'), findsOneWidget);
      handle.dispose();
    });
  });

  group('EmptyState', () {
    testWidgets('affiche titre, message et action', (tester) async {
      await tester.pumpWidget(
        _app(
          EmptyState(
            icon: Icons.inbox,
            title: 'Aucun message',
            message: 'Écrivez à vos camarades',
            action: TextButton(onPressed: () {}, child: const Text('Écrire')),
          ),
        ),
      );
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Aucun message'), findsOneWidget);
      expect(find.text('Écrivez à vos camarades'), findsOneWidget);
      expect(find.text('Écrire'), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('masque l’erreur technique et relance', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          ErrorState(
            error: Exception('SocketException: Failed host lookup'),
            onRetry: () => retries++,
          ),
        ),
      );
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Connexion au serveur'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });

    testWidgets('sans onRetry, pas de bouton', (tester) async {
      await tester.pumpWidget(_app(const ErrorState()));
      expect(find.text('Réessayer'), findsNothing);
    });
  });

  group('Chargement', () {
    testWidgets('AppLoader utilise la couleur principale', (tester) async {
      await tester.pumpWidget(_app(const AppLoader()));
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppColors.militantRed);
    });

    testWidgets('SkeletonList partage une seule animation', (tester) async {
      await tester.pumpWidget(_app(const SkeletonList(itemCount: 3)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SkeletonListTile), findsNWidgets(3));
      expect(find.byType(SkeletonPulse), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SkeletonList),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('SkeletonBox seul pulse de lui-même', (tester) async {
      await tester.pumpWidget(_app(const SkeletonBox(width: 40)));
      expect(find.byType(SkeletonPulse), findsOneWidget);
    });

    testWidgets('s’arrête si les animations sont désactivées', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _app(const SkeletonList(itemCount: 1)),
        ),
      );
      // Ne doit pas boucler : pumpAndSettle échouerait si l'animation tournait.
      await tester.pumpAndSettle();
    });
  });
}
