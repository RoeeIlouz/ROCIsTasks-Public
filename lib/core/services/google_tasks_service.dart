import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rocis_tasks/core/services/auth_service.dart';
import 'package:rocis_tasks/core/services/logger_service.dart';

class GoogleTasksService {
  final AuthService _authService;
  String? _cachedTaskListId;

  GoogleTasksService(this._authService);

  // Throws exception if token expired or unavailable
  Future<String> _getAccessToken() async {
    final token = await _authService.getGoogleAccessToken();
    if (token == null) {
      throw GoogleTokenExpiredException('Google Tasks access token expired or invalid.');
    }
    return token;
  }

  Future<String> _getOrCreateTaskList(String token) async {
    if (_cachedTaskListId != null) return _cachedTaskListId!;

    try {
      // 1. List all lists
      final listResponse = await http.get(
        Uri.parse('https://tasks.googleapis.com/v1/users/@me/lists'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (listResponse.statusCode == 401) {
        throw GoogleTokenExpiredException();
      }

      if (listResponse.statusCode == 200) {
        final data = json.decode(listResponse.body);
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item['title'] == 'ROCIs Tasks') {
            _cachedTaskListId = item['id'] as String;
            return _cachedTaskListId!;
          }
        }
      }

      // 2. Not found, create it
      final createResponse = await http.post(
        Uri.parse('https://tasks.googleapis.com/v1/users/@me/lists'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'title': 'ROCIs Tasks'}),
      );

      if (createResponse.statusCode == 401) {
        throw GoogleTokenExpiredException();
      }

      if (createResponse.statusCode == 200 || createResponse.statusCode == 201) {
        final data = json.decode(createResponse.body);
        _cachedTaskListId = data['id'] as String;
        return _cachedTaskListId!;
      }

      throw Exception('Failed to create ROCIs Tasks list: ${createResponse.statusCode}');
    } catch (e, s) {
      AppLogger.error('Error getting/creating ROCIs Tasks list', error: e, stack: s);
      rethrow;
    }
  }

  Future<String?> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String? categoryName,
  }) async {
    try {
      final token = await _getAccessToken();
      final listId = await _getOrCreateTaskList(token);

      final fullTitle = categoryName != null && categoryName.trim().isNotEmpty
          ? '$title [$categoryName]'
          : title;

      final body = <String, dynamic>{
        'title': fullTitle,
        'notes': description ?? '',
      };

      if (dueDate != null) {
        // Tasks API expects RFC 3339 formatted date-time, e.g. "2026-07-02T00:00:00.000Z"
        final midnightUtc = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
        body['due'] = midnightUtc.toIso8601String();
      }

      final response = await http.post(
        Uri.parse('https://tasks.googleapis.com/v1/lists/$listId/tasks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 401) {
        throw GoogleTokenExpiredException();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['id'] as String?;
      }

      AppLogger.error('Failed to create Google task. Status: ${response.statusCode}, Body: ${response.body}');
      return null;
    } catch (e) {
      if (e is GoogleTokenExpiredException) rethrow;
      AppLogger.error('Error creating Google task', error: e);
      return null;
    }
  }

  Future<bool> updateTask({
    required String taskId,
    required String title,
    String? description,
    DateTime? dueDate,
    required bool isCompleted,
    String? categoryName,
  }) async {
    try {
      final token = await _getAccessToken();
      final listId = await _getOrCreateTaskList(token);

      final fullTitle = categoryName != null && categoryName.trim().isNotEmpty
          ? '$title [$categoryName]'
          : title;

      final body = <String, dynamic>{
        'id': taskId,
        'title': fullTitle,
        'notes': description ?? '',
        'status': isCompleted ? 'completed' : 'needsAction',
      };

      // Reset completedAt status appropriately if completing
      if (isCompleted) {
        body['completed'] = DateTime.now().toUtc().toIso8601String();
      } else {
        body['completed'] = null;
      }

      if (dueDate != null) {
        final midnightUtc = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
        body['due'] = midnightUtc.toIso8601String();
      } else {
        body['due'] = null;
      }

      final response = await http.put(
        Uri.parse('https://tasks.googleapis.com/v1/lists/$listId/tasks/$taskId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 401) {
        throw GoogleTokenExpiredException();
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }

      // If the task was not found (404), maybe it was deleted on Google Tasks.
      if (response.statusCode == 404) {
        AppLogger.warning('Google task $taskId not found. Deletion/re-sync needed.');
        return false;
      }

      AppLogger.error('Failed to update Google task. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      if (e is GoogleTokenExpiredException) rethrow;
      AppLogger.error('Error updating Google task', error: e);
      return false;
    }
  }

  Future<bool> deleteTask({
    required String taskId,
  }) async {
    try {
      final token = await _getAccessToken();
      final listId = await _getOrCreateTaskList(token);

      final response = await http.delete(
        Uri.parse('https://tasks.googleapis.com/v1/lists/$listId/tasks/$taskId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        throw GoogleTokenExpiredException();
      }

      if (response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404) {
        return true;
      }

      AppLogger.error('Failed to delete Google task. Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e) {
      if (e is GoogleTokenExpiredException) rethrow;
      AppLogger.error('Error deleting Google task', error: e);
      return false;
    }
  }
}
