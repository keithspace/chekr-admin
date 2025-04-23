class AdminResponse {
  final String title;
  final String description;
  final String response;
  final DateTime timestamp;
  final String respondedBy;
  final bool isNew;

  AdminResponse({
    required this.title,
    required this.description,
    required this.response,
    required this.timestamp,
    required this.respondedBy,
    required this.isNew,
  });

  AdminResponse copyWith({
    String? title,
    String? description,
    String? response,
    DateTime? timestamp,
    String? respondedBy,
    bool? isNew,
  }) {
    return AdminResponse(
      title: title ?? this.title,
      description: description ?? this.description,
      response: response ?? this.response,
      timestamp: timestamp ?? this.timestamp,
      respondedBy: respondedBy ?? this.respondedBy,
      isNew: isNew ?? this.isNew,
    );
  }
}
