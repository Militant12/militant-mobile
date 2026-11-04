import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le rouge vient du thème : `colors.primary` pour un aplat,
/// `colors.onPrimaryContainer` pour du texte ou une icône, lisible dans les
/// deux thèmes. `AppColors.militantRed` reste permis là où le fond est
/// toujours sombre (appels, lives, lecteur vidéo) ou dans des palettes fixes.
void main() {
  const allowed = {
    'lib/screens/call_screen.dart',
    'lib/screens/group_call_screen.dart',
    'lib/screens/live_screen.dart',
    'lib/services/incoming_call_service.dart',
    'lib/widgets/incoming_call_banner.dart',
    'lib/widgets/video_player_widget.dart',
    'lib/widgets/full_screen_video_page.dart',
    // Couleurs de statut, de plateformes et dégradés décoratifs.
    'lib/services/user_status_service.dart',
    'lib/widgets/linkable_text.dart',
    'lib/widgets/technician_badge.dart',
    'lib/screens/page_detail_screen.dart',
  };

  test('les écrans thémés ne codent plus le rouge en dur', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      final path = entity.path;
      if (entity is! File || !path.endsWith('.dart')) continue;
      if (path.startsWith('lib/theme/')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('AppColors.militantRed')) continue;
        // Le dégradé d'en-tête de page est le seul usage permis ici.
        if (path == 'lib/screens/page_detail_screen.dart' &&
            lines[i].contains('colors: [AppColors.militantRed')) {
          continue;
        }
        if (allowed.contains(path) &&
            path != 'lib/screens/page_detail_screen.dart') {
          continue;
        }
        offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
