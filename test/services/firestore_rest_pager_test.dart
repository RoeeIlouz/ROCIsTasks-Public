import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocis_tasks/core/services/firestore_rest_pager.dart';

void main() {
  final url = Uri.parse('https://firestore.example/v1/docs/events?key=K');

  test('follows nextPageToken and merges every page', () async {
    final tokensSeen = <String?>[];
    final client = MockClient((req) async {
      final token = req.url.queryParameters['pageToken'];
      tokensSeen.add(token);
      expect(req.url.queryParameters['key'], 'K');
      expect(req.url.queryParameters['pageSize'], '300');
      final body = token == null
          ? {
              'documents': [
                {'name': 'a'},
                {'name': 'b'},
              ],
              'nextPageToken': 't1',
            }
          : token == 't1'
          ? {
              'documents': [
                {'name': 'c'},
              ],
              'nextPageToken': 't2',
            }
          : {
              'documents': [
                {'name': 'd'},
              ],
            };
      return http.Response(jsonEncode(body), 200);
    });

    final res = await getAllFirestorePages(url, const {}, client: client);

    final names = (jsonDecode(res.body)['documents'] as List)
        .map((d) => d['name'])
        .toList();
    expect(res.statusCode, 200);
    expect(names, ['a', 'b', 'c', 'd']);
    expect(tokensSeen, [null, 't1', 't2']);
  });

  test('an empty collection returns an empty documents list', () async {
    final client = MockClient((_) async => http.Response('{}', 200));
    final res = await getAllFirestorePages(url, const {}, client: client);
    expect(jsonDecode(res.body)['documents'], isEmpty);
  });

  test('a failing page is returned unchanged', () async {
    final client = MockClient((_) async => http.Response('nope', 403));
    final res = await getAllFirestorePages(url, const {}, client: client);
    expect(res.statusCode, 403);
  });

  test('stops after maxPages if the token never ends', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        jsonEncode({
          'documents': [{}],
          'nextPageToken': 'again',
        }),
        200,
      );
    });
    await getAllFirestorePages(url, const {}, client: client, maxPages: 3);
    expect(calls, 3);
  });
}
