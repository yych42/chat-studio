import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import '../models/conversation.dart';
import '../models/project.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../services/settings_service.dart';
import '../widgets/conversation_list.dart';
import '../widgets/conversation_editor.dart';
import '../widgets/project_management_dialog.dart';
import '../pages/settings_page.dart';

// Undo action types
class UndoAction {
  final String type; // 'delete', 'clearAll'
  final List<Conversation> conversations;

  UndoAction({required this.type, required this.conversations});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  final ImportExportService _importExport = ImportExportService();
  final SettingsService _settings = SettingsService();
  final ShadPopoverController _exportPopoverController = ShadPopoverController();
  final ShadPopoverController _projectPopoverController = ShadPopoverController();

  List<Conversation> _conversations = [];
  List<Project> _projects = [];
  String? _selectedConversationId;
  String? _selectedProjectId = 'default';
  String? _statusFilter;
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isLoading = true;

  // Multi-select state
  Set<String> _selectedConversationIds = {};

  // Undo/redo stacks
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];

  // Export options
  bool _useRlFormat = false;

  // Display settings
  bool _expandThinkingByDefault = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadConversations();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final expandThinking = await _settings.getExpandThinkingByDefault();
    setState(() {
      _expandThinkingByDefault = expandThinking;
    });
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getAllProjects();
    setState(() {
      _projects = projects;
      // If selected project doesn't exist, fall back to first project or null
      if (_selectedProjectId != null && !projects.any((p) => p.id == _selectedProjectId)) {
        _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
      }
    });
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);

    List<Conversation> conversations;
    if (_selectedProjectId != null) {
      conversations = await _db.getConversationsByProject(_selectedProjectId!);
    } else {
      conversations = await _db.getAllConversations();
    }

    // Apply status filter
    if (_statusFilter != null && _statusFilter != 'all') {
      conversations = conversations.where((c) => c.state.status == _statusFilter).toList();
    }

    // Apply sorting
    if (_sortBy == 'date') {
      conversations.sort((a, b) {
        int comparison = a.updatedAt.compareTo(b.updatedAt);
        return _sortAscending ? comparison : -comparison;
      });
    } else if (_sortBy == 'messageCount') {
      conversations.sort((a, b) {
        int comparison = a.messages.length.compareTo(b.messages.length);
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  Future<void> _createNewConversation() async {
    if (_selectedProjectId == null) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('Please select a project first'),
          ),
        );
      }
      return;
    }

    final uuid = Uuid();
    final newConversation = Conversation.create(uuid.v4(), projectId: _selectedProjectId!);
    await _db.createConversation(newConversation);

    await _loadConversations();

    setState(() {
      _selectedConversationId = newConversation.id;
    });
  }

  Future<void> _deleteConversation(String id) async {
    final conversation = _conversations.firstWhere((c) => c.id == id);

    // Add to undo stack
    _undoStack.add(UndoAction(type: 'delete', conversations: [conversation]));
    _redoStack.clear(); // Clear redo stack on new action

    await _db.deleteConversation(id);

    if (_selectedConversationId == id) {
      setState(() => _selectedConversationId = null);
    }

    await _loadConversations();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: const Text('Conversation deleted. Press Cmd+Z to undo.'),
        ),
      );
    }
  }

  Future<void> _deleteSelectedConversations() async {
    if (_selectedConversationIds.isEmpty) return;

    final conversationsToDelete = _conversations
        .where((c) => _selectedConversationIds.contains(c.id))
        .toList();

    // Add to undo stack
    _undoStack.add(UndoAction(type: 'delete', conversations: conversationsToDelete));
    _redoStack.clear();

    for (final conversation in conversationsToDelete) {
      await _db.deleteConversation(conversation.id);
    }

    if (_selectedConversationIds.contains(_selectedConversationId)) {
      setState(() => _selectedConversationId = null);
    }

    setState(() => _selectedConversationIds.clear());
    await _loadConversations();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: Text('Deleted ${conversationsToDelete.length} conversations. Press Cmd+Z to undo.'),
        ),
      );
    }
  }

  Future<void> _clearAllConversations() async {
    // Add to undo stack
    _undoStack.add(UndoAction(type: 'clearAll', conversations: List.from(_conversations)));
    _redoStack.clear();

    await _db.clearAllConversations();
    setState(() {
      _selectedConversationId = null;
      _selectedConversationIds.clear();
    });
    await _loadConversations();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: const Text('All conversations cleared. Press Cmd+Z to undo.'),
        ),
      );
    }
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    _redoStack.add(action);

    // Restore conversations
    for (final conversation in action.conversations) {
      await _db.createConversation(conversation);
    }

    await _loadConversations();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: Text('Undid ${action.type}. ${action.conversations.length} conversation(s) restored.'),
        ),
      );
    }
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty) return;

    final action = _redoStack.removeLast();
    _undoStack.add(action);

    // Re-delete conversations
    for (final conversation in action.conversations) {
      await _db.deleteConversation(conversation.id);
    }

    await _loadConversations();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: Text('Redid ${action.type}. ${action.conversations.length} conversation(s) deleted.'),
        ),
      );
    }
  }

  Future<void> _importConversations() async {
    if (_selectedProjectId == null) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('Please select a project first'),
          ),
        );
      }
      return;
    }

    try {
      final conversations = await _importExport.importFromJsonl(projectId: _selectedProjectId);

      if (conversations != null && conversations.isNotEmpty) {
        await _db.importConversations(conversations);
        await _loadConversations();

        if (mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              description: Text('Imported ${conversations.length} conversations to ${_selectedProject?.name ?? "project"}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error importing: $e'),
          ),
        );
      }
    }
  }

  Future<void> _exportConversations({bool onlyCompleted = false}) async {
    try {
      // If there are selected conversations, export those instead
      final conversationsToExport = _selectedConversationIds.isNotEmpty
          ? _conversations.where((c) => _selectedConversationIds.contains(c.id)).toList()
          : _conversations;

      await _importExport.exportToJsonl(conversationsToExport, onlyCompleted: onlyCompleted);

      if (mounted) {
        final count = conversationsToExport.length;
        ShadToaster.of(context).show(
          ShadToast(
            description: Text(
              _selectedConversationIds.isNotEmpty
                  ? 'Exported $count selected conversation(s)'
                  : onlyCompleted
                      ? 'Exported completed conversations'
                      : 'Exported all conversations',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error exporting: $e'),
          ),
        );
      }
    }
  }

  Future<void> _exportProgressiveConversations({bool onlyCompleted = false}) async {
    try {
      // If there are selected conversations, export those instead
      final conversationsToExport = _selectedConversationIds.isNotEmpty
          ? _conversations.where((c) => _selectedConversationIds.contains(c.id)).toList()
          : _conversations;

      await _importExport.exportProgressiveToJsonl(conversationsToExport, onlyCompleted: onlyCompleted, rlFormat: _useRlFormat);

      if (mounted) {
        final count = conversationsToExport.length;
        ShadToaster.of(context).show(
          ShadToast(
            description: Text(
              _selectedConversationIds.isNotEmpty
                  ? 'Exported $count selected conversation(s) (progressive)'
                  : onlyCompleted
                      ? 'Exported completed conversations (progressive)'
                      : 'Exported all conversations (progressive)',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error exporting progressive: $e'),
          ),
        );
      }
    }
  }

  Future<void> _exportSelectedConversation() async {
    if (_selectedConversation == null) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('No conversation selected'),
          ),
        );
      }
      return;
    }

    try {
      await _importExport.exportSingleToJsonl(_selectedConversation!);

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: const Text('Exported selected conversation'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error exporting: $e'),
          ),
        );
      }
    }
  }

  Future<void> _exportSelectedProgressiveConversation() async {
    if (_selectedConversation == null) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('No conversation selected'),
          ),
        );
      }
      return;
    }

    try {
      await _importExport.exportSingleProgressiveToJsonl(_selectedConversation!, rlFormat: _useRlFormat);

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: const Text('Exported selected conversation (progressive)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error exporting progressive: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showProjectManagementDialog() async {
    await showShadDialog(
      context: context,
      builder: (context) => ProjectManagementDialog(
        projects: _projects,
        onProjectCreated: () {
          _loadProjects();
          _loadConversations();
        },
        onProjectUpdated: () {
          _loadProjects();
        },
        onProjectDeleted: (deletedProjectId) {
          if (_selectedProjectId == deletedProjectId) {
            setState(() => _selectedProjectId = _projects.isNotEmpty ? _projects.first.id : null);
          }
          _loadProjects();
          _loadConversations();
        },
      ),
    );
  }

  Future<void> _moveConversationsToProject() async {
    // Get conversations to move
    final conversationsToMove = _selectedConversationIds.isNotEmpty
        ? _conversations.where((c) => _selectedConversationIds.contains(c.id)).toList()
        : _selectedConversation != null
            ? [_selectedConversation!]
            : <Conversation>[];

    if (conversationsToMove.isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('No conversation selected'),
          ),
        );
      }
      return;
    }

    // Show dialog to select target project
    final targetProjectId = await showShadDialog<String>(
      context: context,
      builder: (context) => ShadDialog(
        title: Text('Move ${conversationsToMove.length} conversation(s) to project'),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final project in _projects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShadButton(
                    onPressed: () => Navigator.pop(context, project.id),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.folder, size: 16),
                        const SizedBox(width: 12),
                        Text(project.name),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (targetProjectId == null) return;

    try {
      // Move all conversations to the target project
      for (final conversation in conversationsToMove) {
        final updatedConversation = conversation.copyWith(
          projectId: targetProjectId,
        );
        await _db.updateConversation(updatedConversation);
      }

      // Clear multi-select
      setState(() => _selectedConversationIds.clear());

      // Reload conversations
      await _loadConversations();

      if (mounted) {
        final targetProject = _projects.firstWhere((p) => p.id == targetProjectId);
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Moved ${conversationsToMove.length} conversation(s) to "${targetProject.name}"'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: Text('Error moving conversations: $e'),
          ),
        );
      }
    }
  }

  Conversation? get _selectedConversation {
    if (_selectedConversationId == null) return null;
    try {
      return _conversations.firstWhere((c) => c.id == _selectedConversationId);
    } catch (e) {
      return null;
    }
  }

  Project? get _selectedProject {
    if (_selectedProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _selectedProjectId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
          if (_undoStack.isNotEmpty) _undo();
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): () {
          if (_redoStack.isNotEmpty) _redo();
        },
      },
      child: FocusScope(
        autofocus: true,
        child: Focus(
          autofocus: true,
          canRequestFocus: true,
          child: Scaffold(
      body: Column(
        children: [
          // Custom title bar with window controls
          DragToMoveArea(
            child: GestureDetector(
              onDoubleTap: () async {
                final isMaximized = await windowManager.isMaximized();
                if (isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 30, bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.background,
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Chat Studio',
                      style: theme.textTheme.h4,
                    ),
                    const SizedBox(width: 24),
                // Project selector
                ShadPopover(
                  controller: _projectPopoverController,
                  popover: (context) => IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final project in _projects)
                            ShadButton.ghost(
                              onPressed: () {
                                setState(() => _selectedProjectId = project.id);
                                _loadConversations();
                                _projectPopoverController.hide();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (project.id == _selectedProjectId)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(LucideIcons.check, size: 16),
                                    ),
                                  Text(project.name),
                                ],
                              ),
                            ),
                          const Divider(),
                          ShadButton.ghost(
                            onPressed: () {
                              _projectPopoverController.hide();
                              _showProjectManagementDialog();
                            },
                            child: const Row(
                              children: [
                                Icon(LucideIcons.settings, size: 16),
                                SizedBox(width: 8),
                                Text('Manage Projects'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: ShadButton.outline(
                    onPressed: () => _projectPopoverController.toggle(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.folder, size: 16),
                        const SizedBox(width: 8),
                        Text(_selectedProject?.name ?? 'No Project'),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevronDown, size: 16),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Import/Export menu
                ShadPopover(
                  controller: _exportPopoverController,
                  popover: (context) => IntrinsicWidth(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _importConversations();
                            },
                            child: const Row(
                              children: [
                                Icon(LucideIcons.upload, size: 16),
                                SizedBox(width: 8),
                                Text('Import...'),
                              ],
                            ),
                          ),
                          const Divider(),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportSelectedConversation();
                            },
                            child: const Text('Export Selected'),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportConversations();
                            },
                            child: const Text('Export All'),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportConversations(onlyCompleted: true);
                            },
                            child: const Text('Export Completed'),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                ShadCheckbox(
                                  value: _useRlFormat,
                                  onChanged: (value) {
                                    setState(() => _useRlFormat = value ?? false);
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text('Internal RL standard'),
                              ],
                            ),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportSelectedProgressiveConversation();
                            },
                            child: const Text('Progressive: Selected'),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportProgressiveConversations();
                            },
                            child: const Text('Progressive: All'),
                          ),
                          ShadButton.ghost(
                            onPressed: () {
                              _exportPopoverController.hide();
                              _exportProgressiveConversations(onlyCompleted: true);
                            },
                            child: const Text('Progressive: Completed'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: ShadTooltip(
                    builder: (context) => const Text('Import / Export'),
                    child: ShadButton.ghost(
                      child: const Icon(LucideIcons.fileDown, size: 20),
                      onPressed: () => _exportPopoverController.toggle(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Move to project (only show when selection exists)
                if (_selectedConversationIds.isNotEmpty || _selectedConversation != null)
                  ShadTooltip(
                    builder: (context) => const Text('Move to project'),
                    child: ShadButton.ghost(
                      child: const Icon(LucideIcons.folderInput, size: 20),
                      onPressed: _moveConversationsToProject,
                    ),
                  ),
                if (_selectedConversationIds.isNotEmpty || _selectedConversation != null)
                  const SizedBox(width: 4),
                // Delete (only show when selection exists)
                if (_selectedConversationIds.isNotEmpty)
                  ShadTooltip(
                    builder: (context) => const Text('Delete selected'),
                    child: ShadButton.ghost(
                      child: const Icon(LucideIcons.trash2, size: 20),
                      onPressed: _deleteSelectedConversations,
                    ),
                  ),
                if (_selectedConversationIds.isNotEmpty)
                  const SizedBox(width: 4),
                // Settings
                ShadTooltip(
                  builder: (context) => const Text('Settings'),
                  child: ShadButton.ghost(
                    child: const Icon(LucideIcons.settings, size: 20),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                      _loadSettings();
                    },
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      // Left panel - Conversation list (1/3 width)
                      SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: ConversationList(
                          conversations: _conversations,
                          selectedConversationId: _selectedConversationId,
                          selectedConversationIds: _selectedConversationIds,
                          onSelectConversation: (id) {
                            setState(() => _selectedConversationId = id);
                          },
                          onSelectionChanged: (ids) {
                            setState(() => _selectedConversationIds = ids);
                          },
                          onDeleteConversation: _deleteConversation,
                          onNewConversation: _createNewConversation,
                          statusFilter: _statusFilter,
                          onFilterChange: (filter) {
                            setState(() => _statusFilter = filter);
                            _loadConversations();
                          },
                          sortBy: _sortBy,
                          sortAscending: _sortAscending,
                          onSortByChange: (sortBy) {
                            setState(() => _sortBy = sortBy);
                            _loadConversations();
                          },
                          onSortOrderChange: (ascending) {
                            setState(() => _sortAscending = ascending);
                            _loadConversations();
                          },
                        ),
                      ),

                      // Vertical divider
                      Container(
                        width: 1,
                        color: theme.colorScheme.border,
                      ),

                      // Right panel - Conversation editor (2/3 width)
                      Expanded(
                        flex: 2,
                        child: ConversationEditor(
                          key: ValueKey(_selectedConversationId),
                          conversation: _selectedConversation,
                          onConversationUpdated: _loadConversations,
                          onDuplicate: (newId) {
                            _loadConversations().then((_) {
                              setState(() => _selectedConversationId = newId);
                            });
                          },
                          onNewConversation: _createNewConversation,
                          expandThinkingByDefault: _expandThinkingByDefault,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }
}
