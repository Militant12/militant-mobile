import '../services/language_service.dart';

/// Nettoie et formate les erreurs pour ne jamais afficher de messages techniques
/// (comme ClientException, SocketException, URLs internes, ports, codes d'erreur OS) aux utilisateurs.
String getFriendlyErrorMessage(dynamic error, [LanguageService? lang]) {
  if (error == null) return 'Une erreur est survenue';
  final errorStr = error.toString();
  final l = lang ?? LanguageService.instance;

  // Détection des erreurs réseau / socket / connexion
  final isNetworkError = errorStr.contains('SocketException') ||
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
    return 'Connexion au serveur impossible. Vérifiez votre connexion internet.';
  }

  if (errorStr.contains('FormatException') || errorStr.contains('Unexpected character')) {
    return 'Erreur de réception des données du serveur.';
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
    return 'Erreur de communication avec le serveur.';
  }

  return clean.trim().isNotEmpty ? clean : l.translate('error_generic');
}
