import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/api_http_client.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/utils/error_helper.dart';

void main() {
  final lang = LanguageService.instance;

  tearDown(() => lang.value = const Locale('fr'));

  test('les erreurs réseau sont traduites', () {
    const error = 'ClientException: Connection refused, uri=http://x';
    expect(
      getFriendlyErrorMessage(error, lang),
      lang.translate('error_network'),
    );

    lang.value = const Locale('en');
    expect(getFriendlyErrorMessage(error, lang), startsWith('Unable to reach'));
  });

  test('trop de requêtes (429) : message dédié', () {
    const error = ApiException(429, 'Rate limit exceeded');
    expect(isRateLimitError(error), isTrue);
    expect(
      getFriendlyErrorMessage(error, lang),
      'Trop de requêtes, réessaie dans un moment.',
    );
    expect(isRateLimitError(Exception('Erreur de chargement')), isFalse);
  });

  test('les URLs internes ne sont jamais affichées', () {
    final message = getFriendlyErrorMessage(
      Exception('Bad response from api.militant.revlibertaire.com'),
      lang,
    );
    expect(message, lang.translate('error_server_communication'));
  });

  test('un message métier est conservé sans le préfixe Exception', () {
    expect(
      getFriendlyErrorMessage(Exception('Pseudo déjà pris'), lang),
      'Pseudo déjà pris',
    );
  });

  test('erreur nulle : message générique', () {
    expect(
      getFriendlyErrorMessage(null, lang),
      lang.translate('error_generic'),
    );
  });
}
