import 'package:flutter/foundation.dart';

class LiveKitConfig {
  const LiveKitConfig._();

  static const String serverUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: '',
  );
  static const String apiKey = String.fromEnvironment(
    'LIVEKIT_API_KEY',
    defaultValue: '',
  );
  static const String apiSecret = String.fromEnvironment(
    'LIVEKIT_API_SECRET',
    defaultValue: '',
  );
  static const String tokenEndpoint = String.fromEnvironment(
    'LIVEKIT_TOKEN_ENDPOINT',
    defaultValue: 'https://api.militant.revlibertaire.com/v1/lives.php?path=token',
  );

  static bool get hasServerUrl => serverUrl.trim().isNotEmpty;
  static bool get hasTokenEndpoint => tokenEndpoint.trim().isNotEmpty;
  static bool get hasEmbeddedDevCredentials =>
      apiKey.trim().isNotEmpty && apiSecret.trim().isNotEmpty;

  static bool get canGenerateTokenOnDevice =>
      !kReleaseMode && hasEmbeddedDevCredentials;
}
