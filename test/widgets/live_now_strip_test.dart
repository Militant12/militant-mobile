import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/live_now_strip.dart';

void main() {
  Future<void> pumpStrip(
    WidgetTester tester,
    Future<List<Map<String, dynamic>>> Function() loadLives, {
    int refreshCount = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LiveNowStrip(loadLives: loadLives, refreshCount: refreshCount),
        ),
      ),
    );
    await tester.pump();
  }

  final header = LanguageService.instance.translate('live_tab_discover');

  testWidgets('rien quand aucun live n’est en cours', (tester) async {
    await pumpStrip(tester, () async => []);
    expect(find.text(header), findsNothing);
  });

  testWidgets('rien si le chargement échoue', (tester) async {
    await pumpStrip(tester, () async => throw Exception('réseau'));
    expect(find.text(header), findsNothing);
  });

  testWidgets('affiche les lives en cours', (tester) async {
    await pumpStrip(
      tester,
      () async => [
        {
          'id': 1,
          'username': 'camille',
          'title': 'Manif place de la République',
        },
        {'id': 2, 'username': 'sam', 'title': ''},
      ],
    );
    expect(find.text(header), findsOneWidget);
    expect(find.text('camille'), findsOneWidget);
    expect(find.text('Manif place de la République'), findsOneWidget);
    expect(find.text('sam'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        LanguageService.instance
            .translate('live_now_item')
            .replaceFirst('{user}', 'camille')
            .replaceFirst('{title}', 'Manif place de la République'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('recharge les lives quand le fil est rafraîchi', (tester) async {
    var lives = <Map<String, dynamic>>[
      {'id': 1, 'username': 'camille', 'title': ''},
    ];
    Future<List<Map<String, dynamic>>> load() async => lives;

    await pumpStrip(tester, load);
    expect(find.text('camille'), findsOneWidget);

    // Le live de camille est terminé, celui de sam commence.
    lives = [
      {'id': 2, 'username': 'sam', 'title': ''},
    ];
    await pumpStrip(tester, load, refreshCount: 1);
    expect(find.text('camille'), findsNothing);
    expect(find.text('sam'), findsOneWidget);

    // Plus aucun live : le bandeau disparaît.
    lives = [];
    await pumpStrip(tester, load, refreshCount: 2);
    expect(find.text(header), findsNothing);
  });

  testWidgets('retire les lives si le rechargement échoue', (tester) async {
    var fail = false;
    Future<List<Map<String, dynamic>>> load() async {
      if (fail) throw Exception('réseau');
      return [
        {'id': 1, 'username': 'camille', 'title': ''},
      ];
    }

    await pumpStrip(tester, load);
    expect(find.text('camille'), findsOneWidget);

    fail = true;
    await pumpStrip(tester, load, refreshCount: 1);
    expect(find.text(header), findsNothing);
  });
}
