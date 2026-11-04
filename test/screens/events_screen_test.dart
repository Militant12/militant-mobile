import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/screens/events_screen.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/stamp.dart';

void main() {
  final lang = LanguageService.instance;

  List<Map<String, dynamic>> events() => [
    {
      'id': 1,
      'title': 'Assemblée générale du collectif',
      'event_date': '2026-11-06 19:00:00',
      'location': 'Bourse du travail, Lyon',
      'participants_count': 42,
      'is_participating': 1,
    },
    {
      'id': 2,
      'title': 'Projection-débat',
      'event_date': '2026-11-06 21:00:00',
      'location': '',
      'participants_count': 1,
      'is_participating': 0,
    },
    {
      'id': 3,
      'title': 'Manifestation pour le logement',
      'event_date': '2026-11-08 14:00:00',
      'location': 'Place Bellecour',
      'participants_count': '318',
      'is_participating': '0',
    },
  ];

  Future<void> pumpAgenda(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: EventsScreen(loadEvents: () async => events()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('regroupe les événements par jour', (tester) async {
    await pumpAgenda(tester);
    expect(find.text('VENDREDI 6 NOVEMBRE'), findsOneWidget);
    expect(find.text('DIMANCHE 8 NOVEMBRE'), findsOneWidget);
    expect(find.text('Assemblée générale du collectif'), findsOneWidget);
    expect(find.text('19:00 · Bourse du travail, Lyon'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
  });

  testWidgets('compte les personnes qui y vont', (tester) async {
    await pumpAgenda(tester);
    expect(find.text('42 personnes y vont'), findsOneWidget);
    expect(find.text(lang.translate('event_person_going')), findsOneWidget);
    expect(find.text('318 personnes y vont'), findsOneWidget);
  });

  testWidgets('tampon et « Je n’y vais plus » quand on y va', (tester) async {
    await pumpAgenda(tester);
    expect(find.byType(Stamp), findsOneWidget);
    expect(find.text(lang.translate('event_not_going')), findsOneWidget);
    expect(find.text(lang.translate('event_going')), findsNWidgets(2));
    expect(find.text(lang.translate('share')), findsNWidgets(3));
  });
}
