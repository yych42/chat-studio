class ConversationState {
  final String status;
  final String comment;

  ConversationState({
    required this.status,
    required this.comment,
  });

  factory ConversationState.initial() {
    return ConversationState(
      status: 'incomplete',
      comment: '',
    );
  }

  factory ConversationState.fromJson(Map<String, dynamic> json) {
    return ConversationState(
      status: json['status'] as String,
      comment: json['comment'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'comment': comment,
    };
  }

  ConversationState copyWith({
    String? status,
    String? comment,
  }) {
    return ConversationState(
      status: status ?? this.status,
      comment: comment ?? this.comment,
    );
  }
}
