class Message {
  final String role;
  final String content;
  final String? thinking;

  Message({
    required this.role,
    required this.content,
    this.thinking,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String,
      content: json['content'] as String,
      thinking: json['thinking'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (thinking != null) 'thinking': thinking,
    };
  }

  // For export: embed thinking in content with custom tag
  // If includeThinking is false, thinking is omitted entirely
  // tagName allows customizing the XML tag (default: 'thoughts')
  Map<String, dynamic> toJsonForExport({
    bool includeThinking = true,
    String tagName = 'thoughts',
  }) {
    String exportContent = content;
    if (includeThinking && thinking != null && thinking!.isNotEmpty) {
      exportContent = '<$tagName>$thinking</$tagName>\n$content';
    }
    return {
      'role': role,
      'content': exportContent,
    };
  }

  Message copyWith({
    String? role,
    String? content,
    String? thinking,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
    );
  }
}
