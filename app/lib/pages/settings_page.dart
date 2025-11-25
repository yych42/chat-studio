import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _modelNameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _thinkingTagController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _successMessage;
  bool _expandThinkingByDefault = false;
  bool _exportThinkingTraces = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelNameController.dispose();
    _apiKeyController.dispose();
    _thinkingTagController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final endpoint = await _settingsService.getApiEndpoint();
    final modelName = await _settingsService.getModelName();
    final apiKey = await _settingsService.getApiKey();
    final expandThinking = await _settingsService.getExpandThinkingByDefault();
    final exportThinking = await _settingsService.getExportThinkingTraces();
    final thinkingTag = await _settingsService.getThinkingTagName();
    _endpointController.text = endpoint;
    _modelNameController.text = modelName;
    _apiKeyController.text = apiKey ?? '';
    _thinkingTagController.text = thinkingTag;
    _expandThinkingByDefault = expandThinking;
    _exportThinkingTraces = exportThinking;
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _successMessage = null;
    });

    await _settingsService.setApiEndpoint(_endpointController.text.trim());
    await _settingsService.setModelName(_modelNameController.text.trim());
    await _settingsService.setApiKey(_apiKeyController.text.trim());
    await _settingsService.setExpandThinkingByDefault(_expandThinkingByDefault);
    await _settingsService.setExportThinkingTraces(_exportThinkingTraces);
    await _settingsService.setThinkingTagName(_thinkingTagController.text.trim().isNotEmpty
        ? _thinkingTagController.text.trim()
        : 'thoughts');

    setState(() {
      _isSaving = false;
      _successMessage = 'Settings saved successfully';
    });

    // Clear success message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _successMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.border,
                ),
              ),
            ),
            child: Row(
              children: [
                ShadButton.ghost(
                  child: const Icon(LucideIcons.arrowLeft, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: theme.textTheme.large,
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // API Settings Section
                        ShadCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'API Configuration',
                                style: theme.textTheme.h4,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure the LLM inference endpoint for AI suggestions',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // API Endpoint Input
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Endpoint',
                                    style: theme.textTheme.small,
                                  ),
                                  const SizedBox(height: 8),
                                  ShadInput(
                                    controller: _endpointController,
                                    placeholder: const Text('http://localhost:3000'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The base URL for the suggestion API endpoint',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Model Name Input
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Model Name',
                                    style: theme.textTheme.small,
                                  ),
                                  const SizedBox(height: 8),
                                  ShadInput(
                                    controller: _modelNameController,
                                    placeholder: const Text('gpt-4'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The model name to use for AI suggestions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // API Key Input
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Key',
                                    style: theme.textTheme.small,
                                  ),
                                  const SizedBox(height: 8),
                                  ShadInput(
                                    controller: _apiKeyController,
                                    placeholder: const Text('sk-...'),
                                    obscureText: true,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Optional: API key for authentication (leave empty if not required)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Success message
                              if (_successMessage != null) ...[
                                ShadAlert(
                                  title: const Text('Success'),
                                  description: Text(_successMessage!),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Save button
                              ShadButton(
                                onPressed: _isSaving ? null : _saveSettings,
                                enabled: !_isSaving,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isSaving)
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else
                                      const Icon(LucideIcons.save, size: 16),
                                    const SizedBox(width: 8),
                                    Text(_isSaving ? 'Saving...' : 'Save Settings'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display Settings Section
                        ShadCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Display Settings',
                                style: theme.textTheme.h4,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure how messages are displayed',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Expand Thinking Toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Expand thinking traces by default',
                                          style: theme.textTheme.small,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'When enabled, thinking traces will be expanded by default when viewing messages',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ShadSwitch(
                                    value: _expandThinkingByDefault,
                                    onChanged: (value) {
                                      setState(() => _expandThinkingByDefault = value);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Export Settings Section
                        ShadCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Settings',
                                style: theme.textTheme.h4,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Configure how thinking traces are exported',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Export Thinking Toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Include thinking traces in export',
                                          style: theme.textTheme.small,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'When disabled, thinking traces will be omitted from exported datasets',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ShadSwitch(
                                    value: _exportThinkingTraces,
                                    onChanged: (value) {
                                      setState(() => _exportThinkingTraces = value);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Thinking Tag Name
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thinking tag name',
                                    style: theme.textTheme.small,
                                  ),
                                  const SizedBox(height: 8),
                                  ShadInput(
                                    controller: _thinkingTagController,
                                    placeholder: const Text('thoughts'),
                                    enabled: _exportThinkingTraces,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The XML tag used to wrap thinking traces (e.g., thoughts, thinking, reasoning)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
