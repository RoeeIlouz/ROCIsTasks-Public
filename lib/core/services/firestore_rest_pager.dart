import 'dart:convert';

import 'package:http/http.dart' as http;

/// Reads a whole Firestore REST collection.
///
/// `documents.list` returns one page per call (about 20 documents unless a
/// page size is given). A timetable synced from a university calendar has
/// 150+ events, so the single call used before silently dropped most of them.
/// This follows `nextPageToken` and returns one response whose body is
/// `{"documents": [...]}` with every page merged. A non-200 page is returned
/// as is, so callers keep their existing status handling.
Future<http.Response> getAllFirestorePages(
  Uri url,
  Map<String, String> headers, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
  int pageSize = 300,
  int maxPages = 50,
}) async {
  final c = client ?? http.Client();
  try {
    final documents = <dynamic>[];
    String? token;
    for (var page = 0; page < maxPages; page++) {
      final res = await c
          .get(
            url.replace(
              queryParameters: {
                ...url.queryParameters,
                'pageSize': '$pageSize',
                'pageToken': ?token,
              },
            ),
            headers: headers,
          )
          .timeout(timeout);
      if (res.statusCode != 200) return res;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      documents.addAll(json['documents'] as List<dynamic>? ?? const []);
      token = json['nextPageToken'] as String?;
      if (token == null || token.isEmpty) break;
    }
    return http.Response(
      jsonEncode({'documents': documents}),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  } finally {
    if (client == null) c.close();
  }
}
