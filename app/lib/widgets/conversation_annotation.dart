import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/conversation_state.dart';

class ConversationAnnotation extends StatefulWidget {
  final ConversationState state;
  final Function(ConversationState) onUpdate;

  const ConversationAnnotation({
    super.key,
    required this.state,
    required this.onUpdate,
  });

  @override
  State<ConversationAnnotation> createState() => _ConversationAnnotationState();
}

class _ConversationAnnotationState extends State<ConversationAnnotation> {
  late TextEditingController _commentController;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.state.comment);
    _commentController.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    if (!_isDirty && _commentController.text != widget.state.comment) {
      setState(() => _isDirty = true);
    }
  }

  void _updateStatus(String status) {
    final updatedState = widget.state.copyWith(status: status);
    widget.onUpdate(updatedState);
    setState(() => _isDirty = false);
  }

  void _saveComment() {
    final updatedState = widget.state.copyWith(comment: _commentController.text);
    widget.onUpdate(updatedState);
    setState(() => _isDirty = false);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: theme.textTheme.small,
              ),
              const SizedBox(height: 8),

              // Status buttons
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusButton(
                    label: _getStatusLabel('completed'),
                    icon: _getStatusIcon('completed'),
                    color: _getStatusColor('completed'),
                    isSelected: widget.state.status == 'completed',
                    onPressed: () => _updateStatus('completed'),
                  ),
                  _StatusButton(
                    label: _getStatusLabel('need_review'),
                    icon: _getStatusIcon('need_review'),
                    color: _getStatusColor('need_review'),
                    isSelected: widget.state.status == 'need_review',
                    onPressed: () => _updateStatus('need_review'),
                  ),
                  _StatusButton(
                    label: _getStatusLabel('incomplete'),
                    icon: _getStatusIcon('incomplete'),
                    color: _getStatusColor('incomplete'),
                    isSelected: widget.state.status == 'incomplete',
                    onPressed: () => _updateStatus('incomplete'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Comments/Notes section
              Text(
                'Notes',
                style: theme.textTheme.small,
              ),
              const SizedBox(height: 6),
              ShadInput(
                controller: _commentController,
                placeholder: const Text('Add notes or comments...'),
                minLines: 2,
                maxLines: 2,
                trailing: _isDirty
                    ? IconButton(
                        icon: const Icon(LucideIcons.save, size: 18),
                        onPressed: _saveComment,
                      )
                    : null,
              ),
              if (_isDirty) ...[
                const SizedBox(height: 4),
                Text(
                  'Unsaved changes',
                  style: theme.textTheme.small?.copyWith(
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.border),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return ShadButton(
        onPressed: onPressed,
        backgroundColor: color,
        foregroundColor: Colors.white,
        size: ShadButtonSize.sm,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      );
    } else {
      return ShadButton.outline(
        onPressed: onPressed,
        size: ShadButtonSize.sm,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      );
    }
  }
}
