class QuickNoteData {
  final String title;
  final String content;
  final String folderUri;
  final String folderName;
  final bool isExistingNote;
  final String? existingNoteUri;

  QuickNoteData({
    required this.title,
    required this.content,
    required this.folderUri,
    required this.folderName,
    this.isExistingNote = false,
    this.existingNoteUri,
  });

  // Create a copy with updated fields
  QuickNoteData copyWith({
    String? title,
    String? content,
    String? folderUri,
    String? folderName,
    bool? isExistingNote,
    String? existingNoteUri,
  }) {
    return QuickNoteData(
      title: title ?? this.title,
      content: content ?? this.content,
      folderUri: folderUri ?? this.folderUri,
      folderName: folderName ?? this.folderName,
      isExistingNote: isExistingNote ?? this.isExistingNote,
      existingNoteUri: existingNoteUri ?? this.existingNoteUri,
    );
  }

  // Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'folderUri': folderUri,
      'folderName': folderName,
      'isExistingNote': isExistingNote,
      'existingNoteUri': existingNoteUri,
    };
  }

  // Create from JSON
  factory QuickNoteData.fromJson(Map<String, dynamic> json) {
    return QuickNoteData(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      folderUri: json['folderUri'] ?? '',
      folderName: json['folderName'] ?? 'Root',
      isExistingNote: json['isExistingNote'] ?? false,
      existingNoteUri: json['existingNoteUri'],
    );
  }

  // Validation methods
  bool get isValid => title.trim().isNotEmpty && content.trim().isNotEmpty;
  bool get hasContent => content.trim().isNotEmpty;
  bool get hasTitle => title.trim().isNotEmpty;

  @override
  String toString() {
    return 'QuickNoteData(title: $title, folderName: $folderName, isExistingNote: $isExistingNote)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickNoteData &&
        other.title == title &&
        other.content == content &&
        other.folderUri == folderUri &&
        other.folderName == folderName &&
        other.isExistingNote == isExistingNote &&
        other.existingNoteUri == existingNoteUri;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      content,
      folderUri,
      folderName,
      isExistingNote,
      existingNoteUri,
    );
  }
}
