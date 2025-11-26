import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/conversation_state.dart';
import '../services/database_service.dart';
import 'message_item.dart';
import 'add_message_form.dart';
// Note: ConversationAnnotation has been merged into this file as a floating toolbar

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

  // Controllers for toolbar
  final ShadPopoverController _statusPopoverController = ShadPopoverController();
  final ShadPopoverController _notesPopoverController = ShadPopoverController();
  late TextEditingController _notesController;
  bool _notesDirty = false;

  @override
  void initState() {
    super.initState();
    _currentConversation = widget.conversation;
    _notesController = TextEditingController(text: widget.conversation?.state.comment ?? '');
    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    _statusPopoverController.dispose();
    _notesPopoverController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConversationEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversation?.id != oldWidget.conversation?.id) {
      setState(() {
        _currentConversation = widget.conversation;
        _showAddForm = false;
        _notesController.text = widget.conversation?.state.comment ?? '';
        _notesDirty = false;
      });
    }
  }

  void _onNotesChanged() {
    if (!_notesDirty && _notesController.text != (_currentConversation?.state.comment ?? '')) {
      setState(() => _notesDirty = true);
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

  void _updateStatus(String status) {
    if (_currentConversation == null) return;
    final updatedState = _currentConversation!.state.copyWith(status: status);
    final updatedConversation = _currentConversation!.copyWith(state: updatedState);
    _saveConversation(updatedConversation);
    _statusPopoverController.hide();
  }

  void _saveNotes() {
    if (_currentConversation == null) return;
    final updatedState = _currentConversation!.state.copyWith(comment: _notesController.text);
    final updatedConversation = _currentConversation!.copyWith(state: updatedState);
    _saveConversation(updatedConversation);
    setState(() => _notesDirty = false);
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'need_review':
        return Colors.purple;
      case 'incomplete':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return LucideIcons.circleCheck;
      case 'need_review':
        return LucideIcons.eye;
      case 'incomplete':
        return LucideIcons.loader;
      default:
        return LucideIcons.circleQuestionMark;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'need_review':
        return 'Need Review';
      case 'incomplete':
        return 'Incomplete';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (_currentConversation == null) {
      return Align(
        alignment: const Alignment(-0.3, 0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.mousePointerClick,
                size: 24,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(height: 10),
              Text(
                'Select a conversation',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose from the list on the left, or create a new one.',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final currentStatus = _currentConversation!.state.status;
    final hasNotes = _currentConversation!.state.comment?.isNotEmpty ?? false;

    return Stack(
      children: [
        // Messages list (main content)
        ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 56),
          children: [
            // Messages
            _currentConversation!.messages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
                    child: Center(
                      child: Text(
                        'No messages yet',
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

            // Add message form
            if (_showAddForm)
              AddMessageForm(
                conversationHistory: _currentConversation!.messages,
                onAdd: _handleAddMessage,
                onCancel: () => setState(() => _showAddForm = false),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ShadButton.outline(
                  onPressed: () => setState(() => _showAddForm = true),
                  size: ShadButtonSize.sm,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, size: 14),
                      SizedBox(width: 4),
                      Text('Add'),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Floating toolbar at bottom
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.colorScheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  // Status popover
                  ShadPopover(
                    controller: _statusPopoverController,
                    anchor: const ShadAnchor(
                      childAlignment: Alignment.topCenter,
                      overlayAlignment: Alignment.bottomCenter,
                    ),
                    popover: (context) => Container(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusOption(
                            label: 'Completed',
                            icon: LucideIcons.circleCheck,
                            color: Colors.green,
                            isSelected: currentStatus == 'completed',
                            onTap: () => _updateStatus('completed'),
                          ),
                          _StatusOption(
                            label: 'Need Review',
                            icon: LucideIcons.eye,
                            color: Colors.purple,
                            isSelected: currentStatus == 'need_review',
                            onTap: () => _updateStatus('need_review'),
                          ),
                          _StatusOption(
                            label: 'Incomplete',
                            icon: LucideIcons.loader,
                            color: Colors.orange,
                            isSelected: currentStatus == 'incomplete',
                            onTap: () => _updateStatus('incomplete'),
                          ),
                        ],
                      ),
                    ),
                    child: _ExpandingToolbarButton(
                      onPressed: () => _statusPopoverController.toggle(),
                      icon: _getStatusIcon(currentStatus),
                      label: _getStatusLabel(currentStatus),
                      color: _getStatusColor(currentStatus),
                      showChevron: true,
                    ),
                  ),

                  // Notes popover
                  ShadPopover(
                    controller: _notesPopoverController,
                    anchor: const ShadAnchor(
                      childAlignment: Alignment.topCenter,
                      overlayAlignment: Alignment.bottomCenter,
                    ),
                    popover: (context) => Container(
                      width: 280,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShadInput(
                            controller: _notesController,
                            placeholder: const Text('Add notes...'),
                            minLines: 3,
                            maxLines: 5,
                          ),
                          if (_notesDirty) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ShadButton(
                                  onPressed: () {
                                    _saveNotes();
                                    _notesPopoverController.hide();
                                  },
                                  size: ShadButtonSize.sm,
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    child: _ExpandingToolbarButton(
                      onPressed: () => _notesPopoverController.toggle(),
                      icon: hasNotes ? LucideIcons.stickyNote : LucideIcons.fileText,
                      label: 'Notes',
                      color: hasNotes ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                    ),
                  ),

                  // Duplicate button
                  _ExpandingToolbarButton(
                    onPressed: _handleDuplicate,
                    icon: LucideIcons.copy,
                    label: 'Duplicate',
                    color: theme.colorScheme.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      onPressed: onTap,
      size: ShadButtonSize.sm,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            const Icon(LucideIcons.check, size: 12)
          else
            const SizedBox(width: 12),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ExpandingToolbarButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final bool showChevron;

  const _ExpandingToolbarButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.showChevron = false,
  });

  @override
  State<_ExpandingToolbarButton> createState() => _ExpandingToolbarButtonState();
}

class _ExpandingToolbarButtonState extends State<_ExpandingToolbarButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onExit() {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _isHovered ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.muted.withOpacity(0.6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.color,
              ),
              SizeTransition(
                sizeFactor: _expandAnimation,
                axis: Axis.horizontal,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.color,
                        ),
                      ),
                      if (widget.showChevron) ...[
                        const SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronDown,
                          size: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
