import '../services/api_http_client.dart';
import '../services/language_service.dart';

/// Le serveur a refusé la requête parce qu'il en reçoit trop (HTTP 429).
bool isRateLimitError(Object? error) =>
    error is ApiException && error.isRateLimited;

/// Nettoie et formate les erreurs pour ne jamais afficher de messages techniques
/// (comme ClientException, SocketException, URLs internes, ports, codes d'erreur OS) aux utilisateurs.
String getFriendlyErrorMessage(dynamic error, [LanguageService? lang]) {
  final l = lang ?? LanguageService.instance;
  if (error == null) return l.translate('error_generic');
  if (isRateLimitError(error)) return l.translate('error_rate_limited');
  final errorStr = error.toString();

  // Détection des erreurs réseau / socket / connexion
  final isNetworkError =
      errorStr.contains('SocketException') ||
      errorStr.contains('ClientException') ||
      errorStr.contains('Connection refused') ||
      errorStr.contains('connection abort') ||
      errorStr.contains('Connection reset') ||
      errorStr.contains('Connection closed') ||
      errorStr.contains('Failed host lookup') ||
      errorStr.contains('Network is unreachable') ||
      errorStr.contains('errno =') ||
      errorStr.contains('TimeoutException') ||
      errorStr.contains('HandshakeException') ||
      errorStr.contains('HttpException') ||
      errorStr.contains('XMLHttpRequest') ||
      errorStr.contains('Software caused connection');

  if (isNetworkError) {
    return l.translate('error_network');
  }

  if (errorStr.contains('FormatException') ||
      errorStr.contains('Unexpected character')) {
    return l.translate('error_data_format');
  }

  // Nettoyage des préfixes techniques Dart
  var clean = errorStr;
  if (clean.startsWith('Exception: ')) {
    clean = clean.substring('Exception: '.length);
  }

  // Masquer les URLs internes si présentes
  if (clean.contains('uri=http') ||
      clean.contains('address =') ||
      clean.contains('port =') ||
      clean.contains('api.militant.revlibertaire.com')) {
    return l.translate('error_server_communication');
  }

  return clean.trim().isNotEmpty ? clean : l.translate('error_generic');
}
