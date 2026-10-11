import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:militant/services/api_service.dart';
import 'package:militant/services/language_service.dart';
import 'package:militant/utils/error_helper.dart';

void main() {
  const html =
      '<html><body><b>Fatal error</b> in /var/www/stories.php</body></html>';

  Future<Object> createStoryError(http.Response response) async {
    late Object error;
    await http.runWithClient(() async {
      final api = ApiService(baseUrl: 'https://api.example.test', token: 't');
      try {
        await api.createStory(media: 'https://example.test/a.jpg');
        fail('createStory aurait dû échouer');
      } catch (e) {
        error = e;
      }
    }, () => MockClient((_) async => response));
    return error;
  }

  test('une réponse 200 illisible donne « erreur de réception »', () async {
    final error = await createStoryError(http.Response(html, 200));
    expect(
      getFriendlyErrorMessage(error),
      LanguageService.instance.translate('error_data_format'),
    );
  });

  test('une erreur serveur n’affiche jamais le HTML brut', () async {
    final error = await createStoryError(http.Response(html, 500));
    final message = getFriendlyErrorMessage(error);
    expect(message, isNot(contains('<')));
    expect(message, isNot(contains('Exception')));
  });

  test('le message d’erreur de l’API est conservé', () async {
    final error = await createStoryError(
      http.Response('{"error":"Fichier trop volumineux"}', 400),
    );
    expect(getFriendlyErrorMessage(error), 'Fichier trop volumineux');
  });
}
