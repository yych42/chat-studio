import 'message.dart';
import 'conversation_state.dart';

class Conversation {
  final String id;
  final String projectId;
  final List<Message> messages;
  final ConversationState state;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.projectId,
    required this.messages,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.create(String id, {String projectId = 'default'}) {
    final now = DateTime.now();
    return Conversation(
      id: id,
      projectId: projectId,
      messages: [],
      state: ConversationState.initial(),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? 'default',
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
      state: ConversationState.fromJson(json['state'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'messages': messages.map((m) => m.toJson()).toList(),
      'state': state.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // For JSONL export format (without id, createdAt, updatedAt)
  Map<String, dynamic> toJsonlFormat() {
    return {
      'messages': messages.map((m) => m.toJson()).toList(),
      'state': state.toJson(),
    };
  }

  // For JSONL export format with configurable thinking export options
  Map<String, dynamic> toJsonlFormatForExport({
    bool includeThinking = true,
    String tagName = 'thoughts',
  }) {
    return {
      'messages': messages.map((m) => m.toJsonForExport(
        includeThinking: includeThinking,
        tagName: tagName,
      )).toList(),
      'state': state.toJson(),
    };
  }

  Conversation copyWith({
    String? id,
    String? projectId,
    List<Message>? messages,
    ConversationState? state,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      messages: messages ?? this.messages,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
