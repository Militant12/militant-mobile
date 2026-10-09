import 'package:http/http.dart' as http;

/// Erreur HTTP de l'API qui garde le code de statut, pour que l'interface
/// puisse afficher un message adapté (voir `getFriendlyErrorMessage`).
class ApiException implements Exception {
  const ApiException(this.statusCode, [this.message = '']);

  final int statusCode;
  final String message;

  /// Le serveur limite le nombre de requêtes (`429 Too Many Requests`).
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() =>
      'ApiException($statusCode)'
      '${message.isEmpty ? '' : ': $message'}';
}

/// Client HTTP utilisé par `ApiService`.
///
/// Une réponse 429 lève une [ApiException] au lieu d'être renvoyée : sinon
/// chaque méthode la traiterait comme une erreur quelconque (« Erreur de
/// chargement… ») et l'utilisateur ne saurait pas qu'il suffit d'attendre.
class ApiHttpClient extends http.BaseClient {
  ApiHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode == 429) {
      await response.stream.drain<void>();
      throw const ApiException(429, 'Rate limit exceeded');
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
