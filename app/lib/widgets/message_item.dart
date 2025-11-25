import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../services/api_service.dart';

class MessageItem extends StatefulWidget {
  final Message message;
  final int index;
  final Function(Message) onUpdate;
  final VoidCallback onDelete;
  final Conversation conversation;
  final bool expandThinkingByDefault;

  const MessageItem({
    super.key,
    required this.message,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
    required this.conversation,
    this.expandThinkingByDefault = false,
  });

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  bool _isEditing = false;
  late TextEditingController _contentController;
  late TextEditingController _thinkingController;
  late String _selectedRole;
  bool _isLoadingSuggestion = false;
  String? _errorMessage;
  late bool _isThinkingExpanded;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.message.content);
    _thinkingController = TextEditingController(text: widget.message.thinking ?? '');
    _selectedRole = widget.message.role;
    _isThinkingExpanded = widget.expandThinkingByDefault;
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
      // Get all messages up to this point
      final conversationHistory = widget.conversation.messages
          .take(widget.index)
          .toList();

      final suggestion = await ApiService().getSuggestedResponse(conversationHistory);

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

  void _saveChanges() {
    final thinkingText = _thinkingController.text.trim();
    final updatedMessage = Message(
      role: _selectedRole,
      content: _contentController.text,
      thinking: thinkingText.isEmpty ? null : thinkingText,
    );
    widget.onUpdate(updatedMessage);
    setState(() {
      _isEditing = false;
      _errorMessage = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _contentController.text = widget.message.content;
      _thinkingController.text = widget.message.thinking ?? '';
      _selectedRole = widget.message.role;
      _isEditing = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isUser = widget.message.role == 'user';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Role indicator
              ShadBadge(
                backgroundColor: isUser ? Colors.blue : Colors.green,
                child: Text(
                  widget.message.role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Action buttons
              if (!_isEditing) ...[
                ShadButton.ghost(
                  child: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: () => setState(() => _isEditing = true),
                ),
                ShadButton.ghost(
                  child: const Icon(LucideIcons.trash2, size: 18),
                  onPressed: widget.onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

            if (_isEditing) ...[
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
              const SizedBox(height: 8),

              // Thinking editor (only for assistant messages)
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
                const SizedBox(height: 8),
              ],

              // Content editor
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content',
                    style: theme.textTheme.small,
                  ),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _contentController,
                    minLines: 3,
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

              // Save/Cancel buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.outline(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ShadButton(
                    onPressed: _saveChanges,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              // Display mode
              // Thinking section (collapsible, only for assistant messages with thinking)
              if (widget.message.role == 'assistant' && widget.message.thinking != null && widget.message.thinking!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _isThinkingExpanded = !_isThinkingExpanded),
                  child: Row(
                    children: [
                      Icon(
                        _isThinkingExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                        size: 16,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isThinkingExpanded ? 'Hide thinking' : 'Show thinking',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isThinkingExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.muted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.colorScheme.border,
                      ),
                    ),
                    child: SelectableText(
                      widget.message.thinking!,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
              SelectableText(
                widget.message.content,
                style: theme.textTheme.p,
              ),
          ],
        ],
      ),
    );
  }
}
