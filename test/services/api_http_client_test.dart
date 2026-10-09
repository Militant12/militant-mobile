import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:militant/services/api_http_client.dart';
import 'package:militant/services/api_service.dart';

void main() {
  final rateLimited = MockClient(
    (_) async => http.Response('{"error":"Rate limit exceeded"}', 429),
  );

  test('une réponse 429 lève une ApiException', () async {
    final client = ApiHttpClient(rateLimited);
    await expectLater(
      client.get(Uri.parse('https://api.example.test/v1/posts.php')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.isRateLimited, 'isRateLimited', isTrue),
      ),
    );
  });

  test('les autres réponses sont renvoyées telles quelles', () async {
    final client = ApiHttpClient(
      MockClient((_) async => http.Response('{"error":"nope"}', 500)),
    );
    final response = await client.get(Uri.parse('https://api.example.test'));
    expect(response.statusCode, 500);
    expect(jsonDecode(response.body), {'error': 'nope'});
  });

  test('ApiService transmet le 429 au lieu d’une erreur générique', () async {
    await http.runWithClient(() async {
      final api = ApiService(baseUrl: 'https://api.example.test', token: 't');
      await expectLater(api.getProfile(), throwsA(isA<ApiException>()));
      await expectLater(api.getPosts(), throwsA(isA<ApiException>()));
    }, () => rateLimited);
  });
}
