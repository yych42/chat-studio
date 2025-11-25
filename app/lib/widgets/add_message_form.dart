import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class AddMessageForm extends StatefulWidget {
  final Function(Message) onAdd;
  final List<Message> conversationHistory;
  final VoidCallback onCancel;

  const AddMessageForm({
    super.key,
    required this.onAdd,
    required this.conversationHistory,
    required this.onCancel,
  });

  @override
  State<AddMessageForm> createState() => _AddMessageFormState();
}

class _AddMessageFormState extends State<AddMessageForm> {
  final _contentController = TextEditingController();
  final _thinkingController = TextEditingController();
  late String _selectedRole;
  bool _isLoadingSuggestion = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set role based on last message - flip to opposite role
    if (widget.conversationHistory.isEmpty) {
      _selectedRole = 'user';
    } else {
      final lastRole = widget.conversationHistory.last.role;
      _selectedRole = lastRole == 'user' ? 'assistant' : 'user';
    }

    _contentController.addListener(() {
      setState(() {}); // Rebuild when text changes
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _thinkingController.dispose();
    super.dispose();
  }

  Future<void> _getSuggestion() async {
    setState(() {
      _isLoadingSuggestion = true;
      _errorMessage = null;
    });

    try {
      final suggestion = await ApiService().getSuggestedResponse(widget.conversationHistory);

      setState(() {
        _contentController.text = suggestion;
        _isLoadingSuggestion = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestion = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _handleSubmit() {
    if (_contentController.text.trim().isEmpty) return;

    final thinkingText = _thinkingController.text.trim();
    final message = Message(
      role: _selectedRole,
      content: _contentController.text.trim(),
      thinking: thinkingText.isEmpty ? null : thinkingText,
    );

    widget.onAdd(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: theme.colorScheme.border),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Message',
                style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              // Role selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role',
                    style: theme.textTheme.small,
                  ),
                  const SizedBox(height: 4),
                  ShadSelect<String>(
                    placeholder: const Text('Select role'),
                    initialValue: _selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                    selectedOptionBuilder: (context, value) => Text(
                      value == 'user' ? 'User' :
                      value == 'assistant' ? 'Assistant' : value,
                    ),
                    options: const [
                      ShadOption(value: 'user', child: Text('User')),
                      ShadOption(value: 'assistant', child: Text('Assistant')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Thinking input (only for assistant messages)
              if (_selectedRole == 'assistant') ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thinking (optional)',
                      style: theme.textTheme.small,
                    ),
                    const SizedBox(height: 4),
                    ShadInput(
                      controller: _thinkingController,
                      placeholder: const Text('Optional thinking/reasoning trace...'),
                      minLines: 2,
                      maxLines: null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Content input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content',
                    style: theme.textTheme.small,
                  ),
                  const SizedBox(height: 4),
                  ShadInput(
                    controller: _contentController,
                    placeholder: const Text('Enter message content...'),
                    minLines: 2,
                    maxLines: null,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // AI Suggestion button (only for assistant messages)
              if (_selectedRole == 'assistant') ...[
                ShadButton(
                  onPressed: _isLoadingSuggestion ? null : _getSuggestion,
                  enabled: !_isLoadingSuggestion,
                  size: ShadButtonSize.sm,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLoadingSuggestion)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(LucideIcons.lightbulb, size: 16),
                      const SizedBox(width: 6),
                      Text(_isLoadingSuggestion ? 'Getting suggestion...' : 'Get AI Suggestion'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Error message
              if (_errorMessage != null) ...[
                ShadAlert.destructive(
                  title: const Text('Error'),
                  description: Text(_errorMessage!),
                ),
                const SizedBox(height: 8),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.outline(
                    onPressed: widget.onCancel,
                    size: ShadButtonSize.sm,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  ShadButton(
                    onPressed: _contentController.text.trim().isEmpty ? null : _handleSubmit,
                    enabled: _contentController.text.trim().isNotEmpty,
                    size: ShadButtonSize.sm,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
