import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';

class ConversationList extends StatefulWidget {
  final List<Conversation> conversations;
  final String? selectedConversationId;
  final Set<String> selectedConversationIds;
  final Function(String) onSelectConversation;
  final Function(Set<String>) onSelectionChanged;
  final Function(String) onDeleteConversation;
  final VoidCallback onNewConversation;
  final String? statusFilter;
  final Function(String?) onFilterChange;
  final String sortBy;
  final bool sortAscending;
  final Function(String) onSortByChange;
  final Function(bool) onSortOrderChange;

  const ConversationList({
    super.key,
    required this.conversations,
    this.selectedConversationId,
    required this.selectedConversationIds,
    required this.onSelectConversation,
    required this.onSelectionChanged,
    required this.onDeleteConversation,
    required this.onNewConversation,
    this.statusFilter,
    required this.onFilterChange,
    required this.sortBy,
    required this.sortAscending,
    required this.onSortByChange,
    required this.onSortOrderChange,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  int? _lastSelectedIndex;

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

  String _getPreviewText(Conversation conversation) {
    if (conversation.messages.isEmpty) {
      return 'No messages';
    }
    final firstMessage = conversation.messages.first.content;
    return firstMessage.length > 50
        ? '${firstMessage.substring(0, 50)}...'
        : firstMessage;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      children: [
        // Header with controls
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.background,
            border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New conversation button
              ShadButton(
                onPressed: widget.onNewConversation,
                size: ShadButtonSize.sm,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus, size: 16),
                    SizedBox(width: 6),
                    Text('New Conversation'),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Filter and sort row
              Row(
                children: [
                  // Status filter - takes more space as primary filter
                  Expanded(
                    flex: 3,
                    child: ShadSelect<String>(
                      placeholder: const Text('Status'),
                      initialValue: widget.statusFilter ?? 'all',
                      onChanged: (value) {
                        widget.onFilterChange(value == 'all' ? null : value);
                      },
                      selectedOptionBuilder:
                          (context, value) {
                            final isFiltered = value != 'all';
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.listFilter,
                                  size: 14,
                                  color: isFiltered
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.mutedForeground,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  value == 'all'
                                      ? 'All status'
                                      : value == 'completed'
                                      ? 'Completed'
                                      : value == 'need_review'
                                      ? 'Review'
                                      : value == 'incomplete'
                                      ? 'Incomplete'
                                      : value,
                                  style: TextStyle(
                                    color: isFiltered
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                              ],
                            );
                          },
                      options: const [
                        ShadOption(value: 'all', child: Text('All status')),
                        ShadOption(value: 'completed', child: Text('Completed')),
                        ShadOption(value: 'need_review', child: Text('Need Review')),
                        ShadOption(value: 'incomplete', child: Text('Incomplete')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort dropdown - compact
                  Expanded(
                    flex: 2,
                    child: ShadSelect<String>(
                      placeholder: const Text('Sort'),
                      initialValue: widget.sortBy,
                      onChanged: (value) {
                        if (value == '__toggle_order__') {
                          widget.onSortOrderChange(!widget.sortAscending);
                        } else if (value != null) {
                          widget.onSortByChange(value);
                        }
                      },
                      selectedOptionBuilder:
                          (context, value) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.sortAscending
                                    ? LucideIcons.arrowUp
                                    : LucideIcons.arrowDown,
                                size: 14,
                                color: theme.colorScheme.mutedForeground,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                value == 'date'
                                    ? 'Date'
                                    : value == 'messageCount'
                                    ? 'Msgs'
                                    : value,
                              ),
                            ],
                          ),
                      options: [
                        const ShadOption(value: 'date', child: Text('Date')),
                        const ShadOption(
                          value: 'messageCount',
                          child: Text('Message Count'),
                        ),
                        ShadOption(
                          value: '__toggle_order__',
                          child: Row(
                            children: [
                              Icon(
                                widget.sortAscending
                                    ? LucideIcons.arrowDown
                                    : LucideIcons.arrowUp,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Text(widget.sortAscending ? 'Descending' : 'Ascending'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Conversation list
        Expanded(
          child:
              widget.conversations.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.messageSquare,
                          size: 32,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: 8),
                        Text('No conversations', style: theme.textTheme.small),
                        const SizedBox(height: 4),
                        Text(
                          'Create a new conversation to get started',
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    itemCount: widget.conversations.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.border,
                    ),
                    itemBuilder: (context, index) {
                      final conversation = widget.conversations[index];
                      final isSelected =
                          conversation.id == widget.selectedConversationId;
                      final isMultiSelected = widget.selectedConversationIds
                          .contains(conversation.id);

                      return _ConversationCard(
                        conversation: conversation,
                        isSelected: isSelected,
                        isMultiSelected: isMultiSelected,
                        theme: theme,
                        getStatusIcon: _getStatusIcon,
                        getStatusColor: _getStatusColor,
                        getPreviewText: _getPreviewText,
                        onTap: () {
                          final metaPressed =
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.metaLeft) ||
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.metaRight);
                          final shiftPressed =
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.shiftLeft) ||
                              HardwareKeyboard.instance.logicalKeysPressed
                                  .contains(LogicalKeyboardKey.shiftRight);

                          if (metaPressed &&
                              shiftPressed &&
                              _lastSelectedIndex != null) {
                            final newSelection = Set<String>.from(
                              widget.selectedConversationIds,
                            );
                            final start =
                                _lastSelectedIndex! < index
                                    ? _lastSelectedIndex!
                                    : index;
                            final end =
                                _lastSelectedIndex! < index
                                    ? index
                                    : _lastSelectedIndex!;

                            for (int i = start; i <= end; i++) {
                              newSelection.add(widget.conversations[i].id);
                            }
                            widget.onSelectionChanged(newSelection);
                            setState(() => _lastSelectedIndex = index);
                          } else if (metaPressed) {
                            final newSelection = Set<String>.from(
                              widget.selectedConversationIds,
                            );
                            if (newSelection.contains(conversation.id)) {
                              newSelection.remove(conversation.id);
                            } else {
                              newSelection.add(conversation.id);
                            }
                            widget.onSelectionChanged(newSelection);
                            setState(() => _lastSelectedIndex = index);
                          } else {
                            widget.onSelectionChanged({});
                            widget.onSelectConversation(conversation.id);
                            setState(() => _lastSelectedIndex = index);
                          }
                        },
                        onDelete: () => widget.onDeleteConversation(conversation.id),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _ConversationCard extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final bool isMultiSelected;
  final ShadThemeData theme;
  final IconData Function(String) getStatusIcon;
  final Color Function(String) getStatusColor;
  final String Function(Conversation) getPreviewText;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationCard({
    required this.conversation,
    required this.isSelected,
    required this.isMultiSelected,
    required this.theme,
    required this.getStatusIcon,
    required this.getStatusColor,
    required this.getPreviewText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: widget.isMultiSelected
              ? widget.theme.colorScheme.primary.withOpacity(0.15)
              : widget.isSelected
                  ? widget.theme.colorScheme.accent
                  : _isHovered
                      ? widget.theme.colorScheme.muted.withOpacity(0.5)
                      : Colors.transparent,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.getPreviewText(widget.conversation),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: widget.theme.textTheme.p.copyWith(
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            widget.getStatusIcon(widget.conversation.state.status),
                            color: widget.getStatusColor(widget.conversation.state.status),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.conversation.messages.length} msgs',
                            style: widget.theme.textTheme.muted.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '·',
                              style: widget.theme.textTheme.muted.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, HH:mm').format(widget.conversation.updatedAt),
                            style: widget.theme.textTheme.muted.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: ShadButton.ghost(
                    child: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                    ),
                    onPressed: widget.onDelete,
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
