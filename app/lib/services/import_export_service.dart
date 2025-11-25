import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/conversation_state.dart';
import 'settings_service.dart';

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();
  final SettingsService _settings = SettingsService();

  factory ImportExportService() {
    return _instance;
  }

  ImportExportService._internal();

  // Parse content and extract thinking from common tag patterns
  // Supports: <thoughts>, <thinking>, <reasoning>, or custom tags
  Message _parseMessageWithThinking(Map<String, dynamic> json) {
    String content = json['content'] as String;
    String? thinking = json['thinking'] as String?;

    // If thinking is already in the JSON, use it directly
    if (thinking != null && thinking.isNotEmpty) {
      return Message(
        role: json['role'] as String,
        content: content,
        thinking: thinking,
      );
    }

    // Try to parse from common thinking tag patterns in content
    // Supports: thoughts, thinking, reasoning, or any single-word tag
    final regex = RegExp(r'^<(\w+)>([\s\S]*?)</\1>\n?');
    final match = regex.firstMatch(content);
    if (match != null) {
      final tagName = match.group(1)!.toLowerCase();
      // Only extract if it looks like a thinking tag
      if (['thoughts', 'thinking', 'reasoning', 'thought', 'reflection'].contains(tagName)) {
        thinking = match.group(2);
        content = content.substring(match.end);
      }
    }

    return Message(
      role: json['role'] as String,
      content: content,
      thinking: thinking,
    );
  }

  Future<List<Conversation>?> importFromJsonl({String? projectId}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jsonl'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final lines = await file.readAsLines();

        final conversations = <Conversation>[];
        final uuid = Uuid();

        for (var line in lines) {
          if (line.trim().isEmpty) continue;

          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final now = DateTime.now();

            // Parse messages (with thinking extraction from <thoughts> tags)
            final messagesList = json['messages'] as List;
            final messages = messagesList
                .map((m) => _parseMessageWithThinking(m as Map<String, dynamic>))
                .toList();

            // Parse state
            ConversationState state;
            if (json.containsKey('state')) {
              state = ConversationState.fromJson(json['state'] as Map<String, dynamic>);
            } else {
              state = ConversationState.initial();
            }

            // Create conversation with generated ID
            conversations.add(Conversation(
              id: uuid.v4(),
              projectId: projectId ?? 'default',
              messages: messages,
              state: state,
              createdAt: now,
              updatedAt: now,
            ));
          } catch (e) {
            // Skip invalid lines
            print('Error parsing line: $e');
          }
        }

        return conversations;
      }
    } catch (e) {
      print('Error importing file: $e');
      rethrow;
    }

    return null;
  }

  Future<void> exportToJsonl(List<Conversation> conversations, {bool onlyCompleted = false}) async {
    try {
      // Get export settings
      final includeThinking = await _settings.getExportThinkingTraces();
      final tagName = await _settings.getThinkingTagName();

      // Filter conversations if needed
      var conversationsToExport = conversations;
      if (onlyCompleted) {
        conversationsToExport = conversations
            .where((c) => c.state.status == 'completed')
            .toList();
      }

      // Convert to JSONL format with configured thinking options
      final lines = conversationsToExport
          .map((c) => jsonEncode(c.toJsonlFormatForExport(
            includeThinking: includeThinking,
            tagName: tagName,
          )))
          .join('\n');

      // Prompt user to save file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = onlyCompleted
          ? 'completed_conversations_$timestamp.jsonl'
          : 'conversations_$timestamp.jsonl';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save conversations',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['jsonl'],
      );

      if (outputPath != null) {
        // Write to file
        final file = File(outputPath);
        await file.writeAsString(lines);
        print('Exported to: $outputPath');
      } else {
        // User cancelled the save dialog
        throw Exception('Export cancelled');
      }
    } catch (e) {
      print('Error exporting file: $e');
      rethrow;
    }
  }

  Future<void> exportSingleToJsonl(Conversation conversation) async {
    try {
      // Get export settings
      final includeThinking = await _settings.getExportThinkingTraces();
      final tagName = await _settings.getThinkingTagName();

      // Convert to JSONL format with configured thinking options
      final line = jsonEncode(conversation.toJsonlFormatForExport(
        includeThinking: includeThinking,
        tagName: tagName,
      ));

      // Prompt user to save file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'conversation_$timestamp.jsonl';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save conversation',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['jsonl'],
      );

      if (outputPath != null) {
        // Write to file
        final file = File(outputPath);
        await file.writeAsString(line);
        print('Exported to: $outputPath');
      } else {
        // User cancelled the save dialog
        throw Exception('Export cancelled');
      }
    } catch (e) {
      print('Error exporting file: $e');
      rethrow;
    }
  }

  Future<void> exportSingleProgressiveToJsonl(Conversation conversation, {bool rlFormat = false}) async {
    try {
      // Get export settings
      final includeThinking = await _settings.getExportThinkingTraces();
      final tagName = await _settings.getThinkingTagName();

      final allLines = <String>[];
      final messages = conversation.messages;

      // Find all indices where assistant messages appear
      final assistantIndices = <int>[];
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].role == 'assistant') {
          assistantIndices.add(i);
        }
      }

      // For each assistant message, create a line with messages up to that point
      for (var assistantIndex in assistantIndices) {
        if (rlFormat) {
          // RL format: {"messages": [...], "gold": "..."}
          final messagesBeforeAssistant = messages.sublist(0, assistantIndex);
          final messagesJson = messagesBeforeAssistant.map((m) => m.toJsonForExport(
            includeThinking: includeThinking,
            tagName: tagName,
          )).toList();
          final assistantMessage = messages[assistantIndex];
          String goldContent = assistantMessage.content;
          if (includeThinking && assistantMessage.thinking != null && assistantMessage.thinking!.isNotEmpty) {
            goldContent = '<$tagName>${assistantMessage.thinking}</$tagName>\n${assistantMessage.content}';
          }
          allLines.add(jsonEncode({
            'messages': messagesJson,
            'gold': goldContent,
          }));
        } else {
          // Standard format: [...] with thinking in content
          final messagesUpToHere = messages.sublist(0, assistantIndex + 1);
          final messagesJson = messagesUpToHere.map((m) => m.toJsonForExport(
            includeThinking: includeThinking,
            tagName: tagName,
          )).toList();
          allLines.add(jsonEncode(messagesJson));
        }
      }

      // Prompt user to save file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'progressive_conversation_$timestamp.jsonl';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save progressive conversation',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['jsonl'],
      );

      if (outputPath != null) {
        // Write to file
        final file = File(outputPath);
        await file.writeAsString(allLines.join('\n'));
        print('Exported progressive format to: $outputPath');
      } else {
        // User cancelled the save dialog
        throw Exception('Export cancelled');
      }
    } catch (e) {
      print('Error exporting progressive file: $e');
      rethrow;
    }
  }

  Future<void> exportProgressiveToJsonl(List<Conversation> conversations, {bool onlyCompleted = false, bool rlFormat = false}) async {
    try {
      // Get export settings
      final includeThinking = await _settings.getExportThinkingTraces();
      final tagName = await _settings.getThinkingTagName();

      // Filter conversations if needed
      var conversationsToExport = conversations;
      if (onlyCompleted) {
        conversationsToExport = conversations
            .where((c) => c.state.status == 'completed')
            .toList();
      }

      final allLines = <String>[];

      // Process each conversation
      for (var conversation in conversationsToExport) {
        final messages = conversation.messages;

        // Find all indices where assistant messages appear
        final assistantIndices = <int>[];
        for (var i = 0; i < messages.length; i++) {
          if (messages[i].role == 'assistant') {
            assistantIndices.add(i);
          }
        }

        // For each assistant message, create a line with messages up to that point
        for (var assistantIndex in assistantIndices) {
          if (rlFormat) {
            // RL format: {"messages": [...], "gold": "..."}
            final messagesBeforeAssistant = messages.sublist(0, assistantIndex);
            final messagesJson = messagesBeforeAssistant.map((m) => m.toJsonForExport(
              includeThinking: includeThinking,
              tagName: tagName,
            )).toList();
            final assistantMessage = messages[assistantIndex];
            String goldContent = assistantMessage.content;
            if (includeThinking && assistantMessage.thinking != null && assistantMessage.thinking!.isNotEmpty) {
              goldContent = '<$tagName>${assistantMessage.thinking}</$tagName>\n${assistantMessage.content}';
            }
            allLines.add(jsonEncode({
              'messages': messagesJson,
              'gold': goldContent,
            }));
          } else {
            // Standard format: [...] with thinking in content
            final messagesUpToHere = messages.sublist(0, assistantIndex + 1);
            final messagesJson = messagesUpToHere.map((m) => m.toJsonForExport(
              includeThinking: includeThinking,
              tagName: tagName,
            )).toList();
            allLines.add(jsonEncode(messagesJson));
          }
        }
      }

      // Prompt user to save file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = onlyCompleted
          ? 'progressive_completed_$timestamp.jsonl'
          : 'progressive_$timestamp.jsonl';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save progressive conversations',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['jsonl'],
      );

      if (outputPath != null) {
        // Write to file
        final file = File(outputPath);
        await file.writeAsString(allLines.join('\n'));
        print('Exported progressive format to: $outputPath');
      } else {
        // User cancelled the save dialog
        throw Exception('Export cancelled');
      }
    } catch (e) {
      print('Error exporting progressive file: $e');
      rethrow;
    }
  }
}
