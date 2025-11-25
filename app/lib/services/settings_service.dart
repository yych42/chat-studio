import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _apiEndpointKey = 'api_endpoint';
  static const String _modelNameKey = 'model_name';
  static const String _apiKeyKey = 'api_key';
  static const String _expandThinkingKey = 'expand_thinking_by_default';
  static const String _exportThinkingKey = 'export_thinking_traces';
  static const String _thinkingTagKey = 'thinking_tag_name';
  static const String _defaultEndpoint = 'http://localhost:3000';
  static const String _defaultModelName = 'gpt-4';
  static const String _defaultThinkingTag = 'thoughts';

  Future<String> getApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiEndpointKey) ?? _defaultEndpoint;
  }

  Future<void> setApiEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiEndpointKey, endpoint);
  }

  Future<String> getModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelNameKey) ?? _defaultModelName;
  }

  Future<void> setModelName(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelNameKey, modelName);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
  }

  Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  Future<bool> getExpandThinkingByDefault() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expandThinkingKey) ?? false;
  }

  Future<void> setExpandThinkingByDefault(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expandThinkingKey, value);
  }

  Future<bool> getExportThinkingTraces() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_exportThinkingKey) ?? true;
  }

  Future<void> setExportThinkingTraces(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_exportThinkingKey, value);
  }

  Future<String> getThinkingTagName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_thinkingTagKey) ?? _defaultThinkingTag;
  }

  Future<void> setThinkingTagName(String tagName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_thinkingTagKey, tagName);
  }
}
