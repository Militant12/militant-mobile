import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/livekit_config.dart';
import 'api_service.dart';
import 'livekit_runtime_config.dart';

/// Token + optional LiveKit server URL returned by militant-api (`url` field).
class LiveKitJoinCredentials {
  const LiveKitJoinCredentials({required this.token, this.serverUrlFromApi});

  final String token;
  final String? serverUrlFromApi;
}

class LiveKitTokenService {
  const LiveKitTokenService._();

  static Future<LiveKitJoinCredentials> issueJoinCredentials({
    required String roomName,
    required String identity,
    required String displayName,
    required bool canPublish,
    required bool useDeviceOverrides,
    int? liveId,
  }) async {
    if (LiveKitConfig.canGenerateTokenOnDevice) {
      return LiveKitJoinCredentials(
        token: _buildDevToken(
          roomName: roomName,
          identity: identity,
          displayName: displayName,
          canPublish: canPublish,
        ),
        serverUrlFromApi: null,
      );
    }

    final endpoint = await LiveKitRuntimeConfig.effectiveTokenEndpoint(
      useDeviceOverrides: useDeviceOverrides,
    );
    if (endpoint.isNotEmpty) {
      return _fetchTokenFromBackend(
        tokenEndpoint: endpoint,
        roomName: roomName,
        identity: identity,
        displayName: displayName,
        canPublish: canPublish,
        liveId: liveId,
      );
    }

    throw Exception(
      'Aucun endpoint de token LiveKit configure. En production, utilisez LIVEKIT_TOKEN_ENDPOINT ou renseignez l endpoint dans l app (sauvegarde). En dev, vous pouvez lancer l app avec LIVEKIT_API_KEY et LIVEKIT_API_SECRET via --dart-define.',
    );
  }

  static Future<LiveKitJoinCredentials> _fetchTokenFromBackend({
    required String tokenEndpoint,
    required String roomName,
    required String identity,
    required String displayName,
    required bool canPublish,
    int? liveId,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final api = await ApiService.getInstance();
      final authToken = api.token?.trim() ?? '';
      if (authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
    } catch (_) {
      // Keep request possible for endpoints that do not require auth.
    }

    final body = <String, dynamic>{
      'roomName': roomName,
      'identity': identity,
      'name': displayName,
      'canPublish': canPublish,
      'canPublishData': true,
      'canSubscribe': true,
    };
    if (liveId != null) {
      body['liveId'] = liveId;
    }

    final response = await http.post(
      Uri.parse(tokenEndpoint),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? apiMsg;
      try {
        final err = jsonDecode(response.body);
        if (err is Map<String, dynamic>) {
          apiMsg = err['error']?.toString().trim();
        }
      } catch (_) {}
      if (apiMsg != null && apiMsg.isNotEmpty) {
        throw Exception(apiMsg);
      }
      throw Exception(
        'Impossible de recuperer un token LiveKit (${response.statusCode}).',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) {
      final token = data['token']?.toString().trim() ?? '';
      if (token.isNotEmpty) {
        final urlRaw = data['url']?.toString().trim();
        return LiveKitJoinCredentials(
          token: token,
          serverUrlFromApi: urlRaw != null && urlRaw.isNotEmpty ? urlRaw : null,
        );
      }
    }

    throw Exception(
      'La reponse de l endpoint LiveKit ne contient pas de token.',
    );
  }

  static String _buildDevToken({
    required String roomName,
    required String identity,
    required String displayName,
    required bool canPublish,
  }) {
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = <String, dynamic>{
      'iss': LiveKitConfig.apiKey,
      'sub': identity,
      'name': displayName,
      'nbf': now,
      'iat': now,
      'exp': now + 60 * 60 * 6,
      'video': {
        'roomJoin': true,
        'room': roomName,
        'canPublish': canPublish,
        'canPublishData': true,
        'canSubscribe': true,
      },
    };

    final encodedHeader = _base64UrlJson(header);
    final encodedPayload = _base64UrlJson(payload);
    final unsignedToken = '$encodedHeader.$encodedPayload';

    final signature = Hmac(
      sha256,
      utf8.encode(LiveKitConfig.apiSecret),
    ).convert(utf8.encode(unsignedToken));

    final encodedSignature = base64Url
        .encode(signature.bytes)
        .replaceAll('=', '');
    return '$unsignedToken.$encodedSignature';
  }

  static String _base64UrlJson(Map<String, dynamic> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }
}
