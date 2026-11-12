import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:militant/services/api_service.dart';

void main() {
  /// Simule l'API : [total] commentaires principaux, découpés comme
  /// `array_slice` côté PHP, avec `total_pages` en flottant (`ceil`).
  http.Response pageOf(Uri url, int total) {
    final page = int.parse(url.queryParameters['page'] ?? '1');
    final perPage = int.parse(url.queryParameters['per_page'] ?? '20');
    final start = (page - 1) * perPage;
    final ids = [
      for (var i = start; i < total && i < start + perPage; i++) i + 1,
    ];
    return http.Response(
      jsonEncode({
        'success': true,
        'data': [
          for (final id in ids) {'id': id, 'replies': []},
        ],
        'total': total,
        'page': page,
        'per_page': perPage,
        'total_pages': (total / perPage).ceilToDouble(),
      }),
      200,
    );
  }

  Future<(List<dynamic>, List<Uri>)> load(
    Future<List<dynamic>> Function(ApiService api) call,
    int total,
  ) async {
    final requests = <Uri>[];
    late List<dynamic> comments;
    await http.runWithClient(
      () async {
        final api = ApiService(baseUrl: 'https://api.example.test', token: 't');
        comments = await call(api);
      },
      () => MockClient((request) async {
        requests.add(request.url);
        return pageOf(request.url, total);
      }),
    );
    return (comments, requests);
  }

  test(
    'getComments charge les commentaires au-delà de la première page',
    () async {
      final (comments, requests) = await load((api) => api.getComments(7), 120);
      expect(comments.map((c) => c['id']), List.generate(120, (i) => i + 1));
      expect(requests, hasLength(3));
      expect(requests.first.path, '/v1/comments.php');
      expect(requests.first.queryParameters['post_id'], '7');
    },
  );

  test('getGroupPostComments charge aussi toutes les pages', () async {
    final (comments, requests) = await load(
      (api) => api.getGroupPostComments(7),
      51,
    );
    expect(comments, hasLength(51));
    expect(requests, hasLength(2));
    expect(requests.first.path, '/v1/group_comments.php');
  });

  test('une seule requête quand tout tient sur une page', () async {
    final (comments, requests) = await load((api) => api.getComments(7), 3);
    expect(comments, hasLength(3));
    expect(requests, hasLength(1));
  });

  test('aucun commentaire : une seule requête, liste vide', () async {
    final (comments, requests) = await load((api) => api.getComments(7), 0);
    expect(comments, isEmpty);
    expect(requests, hasLength(1));
  });

  test('une page en erreur fait échouer le chargement', () async {
    late Object error;
    await http.runWithClient(
      () async {
        final api = ApiService(baseUrl: 'https://api.example.test', token: 't');
        try {
          await api.getComments(7);
          fail('le chargement aurait dû échouer');
        } catch (e) {
          error = e;
        }
      },
      () => MockClient((request) async {
        if (request.url.queryParameters['page'] == '2') {
          return http.Response('', 500);
        }
        return pageOf(request.url, 120);
      }),
    );
    expect(error.toString(), contains('Erreur de chargement des commentaires'));
  });
}
