import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:militant/services/api_service.dart';

void main() {
  late List<http.Request> requests;
  late MockClient client;

  setUp(() {
    requests = [];
    client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'PUT') {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      final id = request.url.queryParameters['id'] ?? '1';
      return http.Response(
        jsonEncode({'id': int.parse(id), 'call': requests.length}),
        200,
      );
    });
  });

  ApiService newApi() =>
      ApiService(baseUrl: 'https://api.example.test', token: 't');

  test('concurrent own-profile calls share one request', () async {
    await http.runWithClient(() async {
      final api = newApi();
      final results = await Future.wait(
        List.generate(5, (_) => api.getProfile()),
      );
      expect(requests, hasLength(1));
      expect(results.every((p) => p['id'] == 1), isTrue);

      await api.getProfile();
      expect(requests, hasLength(1));
    }, () => client);
  });

  test('returned maps are copies of the cache', () async {
    await http.runWithClient(() async {
      final api = newApi();
      final first = await api.getProfile();
      first['id'] = 99;
      expect((await api.getProfile())['id'], 1);
    }, () => client);
  });

  test('other users and forceRefresh bypass the cache', () async {
    await http.runWithClient(() async {
      final api = newApi();
      await api.getProfile();
      await api.getProfile(userId: 2);
      await api.getProfile(userId: 2);
      await api.getProfile(forceRefresh: true);
      expect(requests, hasLength(4));
    }, () => client);
  });

  test('profile updates and logout invalidate the cache', () async {
    await http.runWithClient(() async {
      final api = newApi();
      await api.getProfile();
      await api.updateMilitantBadge('x');
      await api.getProfile();
      expect(requests.where((r) => r.method == 'GET'), hasLength(2));

      api.invalidateOwnProfile();
      await api.getProfile();
      expect(requests.where((r) => r.method == 'GET'), hasLength(3));
    }, () => client);
  });

  test('a failed request is not cached', () async {
    var fail = true;
    final flaky = MockClient((request) async {
      requests.add(request);
      if (fail) return http.Response('{"error":"Rate limit exceeded"}', 429);
      return http.Response(jsonEncode({'id': 1}), 200);
    });
    await http.runWithClient(() async {
      final api = newApi();
      await expectLater(api.getProfile(), throwsException);
      fail = false;
      expect((await api.getProfile())['id'], 1);
      expect(requests, hasLength(2));
    }, () => flaky);
  });
}
