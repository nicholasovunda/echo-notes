import 'dart:async';
import 'dart:convert';
import 'package:echonotes/prompt_transcript.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;

  Future<String> sendToGroq(String transcript) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not configured');
    }

    final prompt = buildRouterPrompt(transcript);
    final messages = [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": prompt},
    ];

    int attempt = 0;
    while (attempt <= _maxRetries) {
      attempt++;
      try {
        final response = await _makeRequest(
          apiKey: apiKey,
          messages: messages,
        ).timeout(_timeout);

        return _handleResponse(response);
      } catch (e) {
        if (attempt > _maxRetries) {
          rethrow;
        }
        await Future.delayed(Duration(seconds: 1 * attempt));
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<http.Response> _makeRequest({
    required String apiKey,
    required List<Map<String, String>> messages,
  }) async {
    return await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        "model": "mixtral-8x7b-32768",
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 1024,
      }),
    );
  }

  String _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return json['choices'][0]['message']['content'] as String;
      case 400:
        throw Exception('Invalid request: ${response.body}');
      case 401:
        throw Exception('Authentication failed - check your API key');
      case 429:
        throw Exception('Rate limit exceeded - please wait');
      case 500:
        throw Exception('Server error - try again later');
      default:
        throw Exception(
          'Request failed with status ${response.statusCode}: ${response.body}',
        );
    }
  }
}
