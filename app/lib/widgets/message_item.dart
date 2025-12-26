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
  late TextEditingController _contentController;
  late TextEditingController _thinkingController;
  late FocusNode _contentFocusNode;
  late FocusNode _thinkingFocusNode;
  bool _isLoadingSuggestion = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.message.content);
    _thinkingController = TextEditingController(text: widget.message.thinking ?? '');
    _contentFocusNode = FocusNode();
    _thinkingFocusNode = FocusNode();

    // Save on focus lost
    _contentFocusNode.addListener(_onContentFocusChange);
    _thinkingFocusNode.addListener(_onThinkingFocusChange);
  }

  @override
  void didUpdateWidget(MessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if message changed externally
    if (widget.message.content != oldWidget.message.content &&
        widget.message.content != _contentController.text) {
      _contentController.text = widget.message.content;
    }
    if (widget.message.thinking != oldWidget.message.thinking &&
        widget.message.thinking != _thinkingController.text) {
      _thinkingController.text = widget.message.thinking ?? '';
    }
  }

  @override
  void dispose() {
    _contentFocusNode.removeListener(_onContentFocusChange);
    _thinkingFocusNode.removeListener(_onThinkingFocusChange);
    _contentController.dispose();
    _thinkingController.dispose();
    _contentFocusNode.dispose();
    _thinkingFocusNode.dispose();
    super.dispose();
  }

  void _onContentFocusChange() {
    if (!_contentFocusNode.hasFocus) {
      _saveIfChanged();
    }
  }

  void _onThinkingFocusChange() {
    if (!_thinkingFocusNode.hasFocus) {
      _saveIfChanged();
    }
  }

  void _saveIfChanged() {
    final newContent = _contentController.text;
    final newThinking = _thinkingController.text.trim();
    final oldThinking = widget.message.thinking ?? '';

    if (newContent != widget.message.content || newThinking != oldThinking) {
      final updatedMessage = Message(
        role: widget.message.role,
        content: newContent,
        thinking: newThinking.isEmpty ? null : newThinking,
      );
      widget.onUpdate(updatedMessage);
    }
  }

  void _toggleRole() {
    final newRole = widget.message.role == 'user' ? 'assistant' : 'user';
    final updatedMessage = widget.message.copyWith(role: newRole);
    widget.onUpdate(updatedMessage);
  }

  Future<void> _getSuggestion() async {
    setState(() {
      _isLoadingSuggestion = true;
      _errorMessage = null;
    });

    try {
      final conversationHistory = widget.conversation.messages
          .take(widget.index)
          .toList();

      final suggestion = await ApiService().getSuggestedResponse(conversationHistory);

      setState(() {
        _contentController.text = suggestion;
        _isLoadingSuggestion = false;
      });
      _saveIfChanged();
    } catch (e) {
      setState(() {
        _isLoadingSuggestion = false;
        _errorMessage = e.toString();
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Enter without Shift inserts a newline (default behavior)
    // Shift+Enter also inserts a newline
    // We don't need special handling - just let TextField handle it
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isAssistant = widget.message.role == 'assistant';
    final hasThinking = widget.message.thinking != null && widget.message.thinking!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
          // Role indicator - clickable to toggle role
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggleRole,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: theme.colorScheme.muted.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      widget.message.role.toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.mutedForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Delete button
              ShadButton.ghost(
                onPressed: widget.onDelete,
                child: Icon(LucideIcons.trash2, size: 14, color: theme.colorScheme.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Thinking section (for assistant messages)
          if (isAssistant) ...[
            if (hasThinking) ...[
              // Display thinking in blockquote style
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: theme.colorScheme.mutedForeground.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Focus(
                  onKeyEvent: _handleKeyEvent,
                  child: TextField(
                    controller: _thinkingController,
                    focusNode: _thinkingFocusNode,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              // Placeholder for adding thinking
              GestureDetector(
                onTap: () {
                  _thinkingFocusNode.requestFocus();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.mutedForeground.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _thinkingController,
                      focusNode: _thinkingFocusNode,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Add thinking process here...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5),
                        ),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Main content - directly editable
          Focus(
            onKeyEvent: _handleKeyEvent,
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              style: theme.textTheme.p,
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Enter message...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5),
                ),
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            ShadAlert.destructive(
              title: const Text('Error'),
              description: Text(_errorMessage!),
            ),
          ],

          // AI Suggestion button (only for assistant messages, shown subtly)
          if (isAssistant) ...[
            const SizedBox(height: 8),
            ShadButton.ghost(
              onPressed: _isLoadingSuggestion ? null : _getSuggestion,
              size: ShadButtonSize.sm,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingSuggestion)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    )
                  else
                    Icon(LucideIcons.sparkles, size: 14, color: theme.colorScheme.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    _isLoadingSuggestion ? 'Getting suggestion...' : 'Get suggestion',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
