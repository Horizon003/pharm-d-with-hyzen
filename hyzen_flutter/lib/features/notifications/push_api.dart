import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const pushApiBase = String.fromEnvironment('PUSH_API_BASE');

class PushApi {
  static Future<Map<String, dynamic>> call(
    User user,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (pushApiBase.isEmpty) {
      throw StateError(
        'Push server is not deployed. Configure PUSH_API_BASE after owner setup.',
      );
    }
    final token = await user.getIdToken();
    final client = http.Client();
    try {
      final uri = Uri.parse('$pushApiBase$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? client.get(uri, headers: headers)
                  : client.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 30));
      final data = Map<String, dynamic>.from(jsonDecode(response.body));
      if (response.statusCode >= 400) {
        throw StateError(data['error']?.toString() ?? 'Push request failed.');
      }
      return data;
    } finally {
      client.close();
    }
  }
}
