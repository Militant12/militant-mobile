import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:militant/services/api_service.dart';
import 'package:militant/utils/error_helper.dart';

void main() {
  Future<Object> errorFrom(
    Future<void> Function(ApiService api) call,
    http.Response response,
  ) async {
    late Object error;
    await http.runWithClient(() async {
      final api = ApiService(baseUrl: 'https://api.example.test', token: 't');
      try {
        await call(api);
        fail('l’appel aurait dû échouer');
      } catch (e) {
        error = e;
      }
    }, () => MockClient((_) async => response));
    return error;
  }

  test('bookmarkPost transmet le message de l’API', () async {
    final error = await errorFrom(
      (api) => api.bookmarkPost(1),
      http.Response('{"error":"Post déjà enregistré"}', 409),
    );
    expect(getFriendlyErrorMessage(error), 'Post déjà enregistré');
  });

  test('removeBookmark transmet le message de l’API', () async {
    final error = await errorFrom(
      (api) => api.removeBookmark(1),
      http.Response('{"error":"Favori introuvable"}', 404),
    );
    expect(getFriendlyErrorMessage(error), 'Favori introuvable');
  });

  test('sans message de l’API, le texte de repli reste lisible', () async {
    final error = await errorFrom(
      (api) => api.bookmarkPost(1),
      http.Response('', 500),
    );
    expect(getFriendlyErrorMessage(error), 'Erreur de sauvegarde');
  });
}
