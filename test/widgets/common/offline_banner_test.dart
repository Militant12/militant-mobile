import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/theme/app_theme.dart';
import 'package:militant/widgets/common/offline_banner.dart';

void main() {
  final offlineText = LanguageService.instance.translate('offline_banner');

  Future<StreamController<List<ConnectivityResult>>> pumpBanner(
    WidgetTester tester, {
    required List<ConnectivityResult> initial,
  }) async {
    final changes = StreamController<List<ConnectivityResult>>();
    addTearDown(changes.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => OfflineBanner(
          connectivityChanges: changes.stream,
          checkConnectivity: () async => initial,
          child: child!,
        ),
        home: const Scaffold(body: Text('Contenu')),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('rien n’est affiché quand le réseau est là', (tester) async {
    await pumpBanner(tester, initial: [ConnectivityResult.wifi]);
    expect(find.text(offlineText), findsNothing);
    expect(find.text('Contenu'), findsOneWidget);
  });

  testWidgets('le bandeau apparaît hors ligne puis disparaît', (tester) async {
    final changes = await pumpBanner(
      tester,
      initial: [ConnectivityResult.wifi],
    );

    changes.add([ConnectivityResult.none]);
    await tester.pumpAndSettle();
    expect(find.text(offlineText), findsOneWidget);
    expect(find.text('Contenu'), findsOneWidget);

    changes.add([ConnectivityResult.mobile]);
    await tester.pumpAndSettle();
    expect(find.text(offlineText), findsNothing);
  });

  testWidgets('hors ligne dès le démarrage', (tester) async {
    await pumpBanner(tester, initial: [ConnectivityResult.none]);
    expect(find.text(offlineText), findsOneWidget);
  });
}
