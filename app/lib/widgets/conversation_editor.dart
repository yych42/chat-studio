import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/conversation_state.dart';
import '../services/database_service.dart';
import 'message_item.dart';
import 'add_message_form.dart';
import 'conversation_annotation.dart';

class ConversationEditor extends StatefulWidget {
  final Conversation? conversation;
  final VoidCallback onConversationUpdated;
  final Function(String) onDuplicate;
  final VoidCallback? onNewConversation;
  final bool expandThinkingByDefault;

  const ConversationEditor({
    super.key,
    this.conversation,
    required this.onConversationUpdated,
    required this.onDuplicate,
    this.onNewConversation,
    this.expandThinkingByDefault = false,
  });

  @override
  State<ConversationEditor> createState() => _ConversationEditorState();
}

class _ConversationEditorState extends State<ConversationEditor> {
  final DatabaseService _db = DatabaseService();
  bool _showAddForm = false;
  Conversation? _currentConversation;

  @override
  void initState() {
    super.initState();
    _currentConversation = widget.conversation;
  }

  @override
  void didUpdateWidget(ConversationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversation?.id != oldWidget.conversation?.id) {
      setState(() {
        _currentConversation = widget.conversation;
        _showAddForm = false;
      });
    }
  }

  Future<void> _saveConversation(Conversation conversation) async {
    await _db.updateConversation(conversation);
    setState(() {
      _currentConversation = conversation;
    });
    widget.onConversationUpdated();
  }

  void _handleAddMessage(Message message) {
    if (_currentConversation == null) return;

    final updatedMessages = [..._currentConversation!.messages, message];
    final updatedConversation = _currentConversation!.copyWith(
      messages: updatedMessages,
    );

    _saveConversation(updatedConversation);
    setState(() {
      _showAddForm = false;
    });
  }

  void _handleUpdateMessage(int index, Message message) {
    if (_currentConversation == null) return;

    final updatedMessages = [..._currentConversation!.messages];
    updatedMessages[index] = message;

    final updatedConversation = _currentConversation!.copyWith(
      messages: updatedMessages,
    );

    _saveConversation(updatedConversation);
  }

  void _handleDeleteMessage(int index) {
    if (_currentConversation == null) return;

    final updatedMessages = [..._currentConversation!.messages];
    updatedMessages.removeAt(index);

    final updatedConversation = _currentConversation!.copyWith(
      messages: updatedMessages,
    );

    _saveConversation(updatedConversation);
  }

  void _handleUpdateState(ConversationState state) {
    if (_currentConversation == null) return;

    final updatedConversation = _currentConversation!.copyWith(
      state: state,
    );

    _saveConversation(updatedConversation);
  }

  Future<void> _handleDuplicate() async {
    if (_currentConversation == null) return;

    final uuid = Uuid();
    final duplicatedConversation = Conversation(
      id: uuid.v4(),
      projectId: _currentConversation!.projectId,
      messages: _currentConversation!.messages,
      state: _currentConversation!.state,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.createConversation(duplicatedConversation);
    widget.onDuplicate(duplicatedConversation.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (_currentConversation == null) {
      return Align(
        alignment: const Alignment(-0.3, 0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.mousePointerClick,
                size: 32,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a conversation',
                style: theme.textTheme.large.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose from the list on the left, or create a new one with the button above.',
                style: theme.textTheme.muted,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Conversation',
                      style: theme.textTheme.large,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentConversation!.messages.length} messages',
                      style: theme.textTheme.small,
                    ),
                  ],
                ),
              ),
              ShadButton.ghost(
                child: const Icon(LucideIcons.copy, size: 20),
                onPressed: _handleDuplicate,
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              // Conversation annotation
              Padding(
                padding: const EdgeInsets.all(12),
                child: ConversationAnnotation(
                  state: _currentConversation!.state,
                  onUpdate: _handleUpdateState,
                ),
              ),

              // Messages
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ShadCard(
                  padding: EdgeInsets.zero,
                  child: _currentConversation!.messages.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No messages yet. Add a message to get started.',
                              style: TextStyle(color: theme.colorScheme.mutedForeground),
                            ),
                          ),
                        )
                      : Column(
                          children: List.generate(
                            _currentConversation!.messages.length,
                            (index) {
                              final message = _currentConversation!.messages[index];
                              return MessageItem(
                                key: ValueKey('${_currentConversation!.id}-$index'),
                                message: message,
                                index: index,
                                conversation: _currentConversation!,
                                onUpdate: (updatedMessage) => _handleUpdateMessage(index, updatedMessage),
                                onDelete: () => _handleDeleteMessage(index),
                                expandThinkingByDefault: widget.expandThinkingByDefault,
                              );
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Add message form
              if (_showAddForm)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: AddMessageForm(
                    conversationHistory: _currentConversation!.messages,
                    onAdd: _handleAddMessage,
                    onCancel: () => setState(() => _showAddForm = false),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ShadButton(
                    onPressed: () => setState(() => _showAddForm = true),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 20),
                        SizedBox(width: 8),
                        Text('Add Message'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
