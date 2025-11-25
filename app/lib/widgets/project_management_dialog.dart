import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../services/database_service.dart';

class ProjectManagementDialog extends StatefulWidget {
  final List<Project> projects;
  final VoidCallback onProjectCreated;
  final VoidCallback onProjectUpdated;
  final Function(String) onProjectDeleted;

  const ProjectManagementDialog({
    super.key,
    required this.projects,
    required this.onProjectCreated,
    required this.onProjectUpdated,
    required this.onProjectDeleted,
  });

  @override
  State<ProjectManagementDialog> createState() => _ProjectManagementDialogState();
}

class _ProjectManagementDialogState extends State<ProjectManagementDialog> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _nameController = TextEditingController();
  Project? _editingProject;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('Project name cannot be empty'),
          ),
        );
      }
      return;
    }

    final uuid = Uuid();
    final now = DateTime.now();
    final project = Project(
      id: uuid.v4(),
      name: _nameController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await _db.createProject(project);
    _nameController.clear();
    setState(() => _isCreating = false);
    widget.onProjectCreated();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: Text('Created project "${project.name}"'),
        ),
      );
    }
  }

  Future<void> _updateProject() async {
    if (_editingProject == null) return;
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('Project name cannot be empty'),
          ),
        );
      }
      return;
    }

    final updatedProject = _editingProject!.copyWith(
      name: _nameController.text.trim(),
    );

    await _db.updateProject(updatedProject);
    _nameController.clear();
    setState(() => _editingProject = null);
    widget.onProjectUpdated();

    if (mounted) {
      ShadToaster.of(context).show(
        ShadToast(
          description: Text('Updated project "${updatedProject.name}"'),
        ),
      );
    }
  }

  Future<void> _deleteProject(Project project) async {
    if (project.id == 'default') {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            description: const Text('Cannot delete the default project'),
          ),
        );
      }
      return;
    }

    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Delete Project'),
        description: Text('Are you sure you want to delete "${project.name}"? All conversations in this project will be deleted.'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteProject(project.id);
      widget.onProjectDeleted(project.id);

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            description: Text('Deleted project "${project.name}"'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: const Text('Manage Projects'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Create new project section
            if (_isCreating) ...[
              ShadCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('New Project', style: theme.textTheme.small),
                    const SizedBox(height: 8),
                    ShadInput(
                      controller: _nameController,
                      placeholder: const Text('Project name'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton.outline(
                          onPressed: () {
                            _nameController.clear();
                            setState(() => _isCreating = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton(
                          onPressed: _createProject,
                          child: const Text('Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              ShadButton(
                onPressed: () => setState(() => _isCreating = true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 16),
                    SizedBox(width: 8),
                    Text('New Project'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Projects list
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final project in widget.projects)
                      if (_editingProject?.id == project.id) ...[
                        ShadCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Edit Project', style: theme.textTheme.small),
                              const SizedBox(height: 8),
                              ShadInput(
                                controller: _nameController,
                                placeholder: const Text('Project name'),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ShadButton.outline(
                                    onPressed: () {
                                      _nameController.clear();
                                      setState(() => _editingProject = null);
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                  const SizedBox(width: 8),
                                  ShadButton(
                                    onPressed: _updateProject,
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.folder, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(project.name),
                              ),
                              if (project.id != 'default') ...[
                                ShadButton.ghost(
                                  onPressed: () {
                                    _nameController.text = project.name;
                                    setState(() => _editingProject = project);
                                  },
                                  child: const Icon(LucideIcons.pencil, size: 16),
                                ),
                                const SizedBox(width: 4),
                                ShadButton.ghost(
                                  onPressed: () => _deleteProject(project),
                                  child: const Icon(LucideIcons.trash2, size: 16),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
