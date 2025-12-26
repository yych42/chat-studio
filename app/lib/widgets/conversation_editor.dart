import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import 'message_item.dart';
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
  Conversation? _currentConversation;
  final ScrollController _scrollController = ScrollController();

  // Controllers for toolbar
  final ShadPopoverController _statusPopoverController = ShadPopoverController();
  final ShadPopoverController _notesPopoverController = ShadPopoverController();
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _currentConversation = widget.conversation;
    _notesController = TextEditingController(text: widget.conversation?.state.comment ?? '');
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
        _notesController.text = widget.conversation?.state.comment ?? '';
      });
    }
  }

  Future<void> _saveConversation(Conversation conversation, {bool scrollToBottom = false}) async {
    // Preserve scroll position before setState
    final scrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    await _db.updateConversation(conversation);
    setState(() {
      _currentConversation = conversation;
    });
    widget.onConversationUpdated();

    // Restore scroll position after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (scrollToBottom) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        } else {
          // Clamp to valid range in case content shrunk (e.g., message deleted)
          final maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(scrollOffset.clamp(0.0, maxScroll));
        }
      }
    });
  }

  void _handleAddMessage() {
    if (_currentConversation == null) return;

    // Determine the role based on last message (flip to opposite)
    String newRole = 'user';
    if (_currentConversation!.messages.isNotEmpty) {
      final lastRole = _currentConversation!.messages.last.role;
      newRole = lastRole == 'user' ? 'assistant' : 'user';
    }

    final newMessage = Message(
      role: newRole,
      content: '',
    );

    final updatedMessages = [..._currentConversation!.messages, newMessage];
    final updatedConversation = _currentConversation!.copyWith(
      messages: updatedMessages,
    );

    _saveConversation(updatedConversation, scrollToBottom: true);
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
    final hasNotes = _currentConversation!.state.comment.isNotEmpty;

    return Stack(
      children: [
        // Messages list (main content)
        ListView(
          controller: _scrollController,
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

            // Add message button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ShadButton.outline(
                onPressed: _handleAddMessage,
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
              padding: const EdgeInsets.all(5),
              decoration: ShapeDecoration(
                color: theme.colorScheme.background,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: theme.colorScheme.border),
                ),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _FloatingToolbar(
                items: [
                  // Status item
                  _ToolbarItemData(
                    child: ShadPopover(
                      controller: _statusPopoverController,
                      anchor: const ShadAnchor(
                        childAlignment: Alignment.bottomCenter,
                        overlayAlignment: Alignment.topCenter,
                        offset: Offset(0, -6),
                      ),
                      decoration: ShadDecoration.none,
                      shadows: const [],
                      padding: EdgeInsets.zero,
                      popover: (context) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: ShapeDecoration(
                          color: theme.colorScheme.background,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.border),
                          ),
                        ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(currentStatus),
                            size: 14,
                            color: _getStatusColor(currentStatus),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _getStatusLabel(currentStatus),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getStatusColor(currentStatus),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 12,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                    onPressed: () => _statusPopoverController.toggle(),
                  ),
                  // Notes item
                  _ToolbarItemData(
                    child: ShadPopover(
                      controller: _notesPopoverController,
                      anchor: const ShadAnchor(
                        childAlignment: Alignment.bottomCenter,
                        overlayAlignment: Alignment.topCenter,
                        offset: Offset(0, -6),
                      ),
                      decoration: ShadDecoration.none,
                      shadows: const [],
                      padding: EdgeInsets.zero,
                      popover: (context) => Container(
                        width: 240,
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          color: theme.colorScheme.background,
                          shape: RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.border),
                          ),
                        ),
                        child: TextField(
                          controller: _notesController,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.foreground,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Add notes...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.mutedForeground,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          minLines: 3,
                          maxLines: 5,
                          onChanged: (_) => _saveNotes(),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasNotes ? LucideIcons.stickyNote : LucideIcons.fileText,
                            size: 14,
                            color: hasNotes ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasNotes ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onPressed: () => _notesPopoverController.toggle(),
                  ),
                  // Duplicate item
                  _ToolbarItemData(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Duplicate',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                    onPressed: _handleDuplicate,
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
    final theme = ShadTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                child: isSelected
                    ? Icon(LucideIcons.check, size: 12, color: theme.colorScheme.foreground)
                    : null,
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingToolbar extends StatefulWidget {
  final List<_ToolbarItemData> items;

  const _FloatingToolbar({required this.items});

  @override
  State<_FloatingToolbar> createState() => _FloatingToolbarState();
}

class _ToolbarItemData {
  final Widget child;
  final VoidCallback onPressed;

  const _ToolbarItemData({required this.child, required this.onPressed});
}

class _FloatingToolbarState extends State<_FloatingToolbar> with TickerProviderStateMixin {
  int? _hoveredIndex;
  final List<GlobalKey> _itemKeys = [];

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;

  // Current animated values for position/size
  double _indicatorLeft = 0;
  double _indicatorWidth = 0;

  // Start values for animation
  double _startLeft = 0;
  double _startWidth = 0;

  // Target values
  double _targetLeft = 0;
  double _targetWidth = 0;

  @override
  void initState() {
    super.initState();
    // Spring-like animation for sliding
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideController.addListener(_onSlideAnimation);

    // Fade animation for enter/exit
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _initKeys();
  }

  void _initKeys() {
    _itemKeys.clear();
    for (int i = 0; i < widget.items.length; i++) {
      _itemKeys.add(GlobalKey());
    }
  }

  @override
  void didUpdateWidget(_FloatingToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      _initKeys();
    }
  }

  @override
  void dispose() {
    _slideController.removeListener(_onSlideAnimation);
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSlideAnimation() {
    // Use a spring-like curve for smooth, natural movement
    final t = Curves.easeOutCubic.transform(_slideController.value);

    setState(() {
      _indicatorLeft = _startLeft + (_targetLeft - _startLeft) * t;
      _indicatorWidth = _startWidth + (_targetWidth - _startWidth) * t;
    });
  }

  void _onItemHover(int index, bool isHovered) {
    if (isHovered) {
      // Measure the item's position and size
      final key = _itemKeys[index];
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final parentBox = context.findRenderObject() as RenderBox?;
        if (parentBox != null) {
          final parentPosition = parentBox.localToGlobal(Offset.zero);
          final relativeLeft = position.dx - parentPosition.dx;
          final width = renderBox.size.width;

          final wasHovering = _hoveredIndex != null;

          setState(() {
            _hoveredIndex = index;

            if (!wasHovering) {
              // First hover - snap position and fade in
              _indicatorLeft = relativeLeft;
              _indicatorWidth = width;
              _startLeft = relativeLeft;
              _startWidth = width;
              _targetLeft = relativeLeft;
              _targetWidth = width;
              _fadeController.forward();
            } else {
              // Sliding to new position
              _startLeft = _indicatorLeft;
              _startWidth = _indicatorWidth;
              _targetLeft = relativeLeft;
              _targetWidth = width;
              _slideController.forward(from: 0);
            }
          });
        }
      }
    } else {
      // Small delay to allow moving to adjacent items
      Future.delayed(const Duration(milliseconds: 16), () {
        if (mounted && _hoveredIndex == index) {
          setState(() {
            _hoveredIndex = null;
          });
          _fadeController.reverse();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hoverColor = theme.colorScheme.muted;

    return Stack(
      children: [
        // Animated indicator background
        AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            if (_fadeController.value == 0) return const SizedBox.shrink();
            return Positioned(
              left: _indicatorLeft,
              top: 0,
              bottom: 0,
              width: _indicatorWidth,
              child: Container(
                decoration: ShapeDecoration(
                  color: hoverColor.withValues(alpha: _fadeController.value),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            );
          },
        ),
        // Toolbar items
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: List.generate(widget.items.length, (index) {
            final item = widget.items[index];
            return _ToolbarItem(
              key: _itemKeys[index],
              onPressed: item.onPressed,
              onHover: (isHovered) => _onItemHover(index, isHovered),
              child: item.child,
            );
          }),
        ),
      ],
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Function(bool) onHover;

  const _ToolbarItem({
    super.key,
    required this.child,
    required this.onPressed,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: child,
        ),
      ),
    );
  }
}
