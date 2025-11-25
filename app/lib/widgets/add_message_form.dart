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

    return ShadCard(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add New Message',
            style: theme.textTheme.large,
          ),
          const SizedBox(height: 12),

          // Role selector
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role',
                style: theme.textTheme.small,
              ),
              const SizedBox(height: 6),
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
          const SizedBox(height: 12),

          // Thinking input (only for assistant messages)
          if (_selectedRole == 'assistant') ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thinking (optional)',
                  style: theme.textTheme.small,
                ),
                const SizedBox(height: 6),
                ShadInput(
                  controller: _thinkingController,
                  placeholder: const Text('Optional thinking/reasoning trace...'),
                  minLines: 2,
                  maxLines: null,
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Content input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Message Content',
                style: theme.textTheme.small,
              ),
              const SizedBox(height: 6),
              ShadInput(
                controller: _contentController,
                placeholder: const Text('Enter message content...'),
                minLines: 3,
                maxLines: null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // AI Suggestion button (only for assistant messages)
          if (_selectedRole == 'assistant') ...[
            ShadButton(
              onPressed: _isLoadingSuggestion ? null : _getSuggestion,
              enabled: !_isLoadingSuggestion,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingSuggestion)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(LucideIcons.lightbulb, size: 20),
                  const SizedBox(width: 8),
                  Text(_isLoadingSuggestion ? 'Getting suggestion...' : 'Get AI Suggestion'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Error message
          if (_errorMessage != null) ...[
            ShadAlert.destructive(
              title: const Text('Error'),
              description: Text(_errorMessage!),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.outline(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ShadButton(
                onPressed: _contentController.text.trim().isEmpty ? null : _handleSubmit,
                enabled: _contentController.text.trim().isNotEmpty,
                child: const Text('Add Message'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
