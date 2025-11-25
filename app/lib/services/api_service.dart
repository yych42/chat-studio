import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'settings_service.dart';

class ApiService {
  // OpenAI-compatible API service
  final SettingsService _settingsService = SettingsService();

  Future<String> getSuggestedResponse(List<Message> conversationHistory) async {
    try {
      final baseUrl = await _settingsService.getApiEndpoint();
      final modelName = await _settingsService.getModelName();
      final apiKey = await _settingsService.getApiKey();

      // Convert to OpenAI-compatible format
      final messages = conversationHistory.map((m) => {
        'role': m.role,
        'content': m.content,
      }).toList();

      // Build headers
      final headers = {
        'Content-Type': 'application/json',
      };

      // Add Authorization header if API key is provided
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final response = await http.post(
        Uri.parse('$baseUrl/v1/chat/completions'),
        headers: headers,
        body: jsonEncode({
          'model': modelName,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error']?['message'] ?? errorData['error'] ?? 'Failed to get suggestion');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to connect to suggestion API: $e');
    }
  }
}
