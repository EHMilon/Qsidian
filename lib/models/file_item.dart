class FileItem {
  final String uri;
  final String name;
  final bool isDirectory;
  final String displayPath;
  final DateTime? lastAccessed;

  FileItem({
    required this.uri,
    required this.name,
    required this.isDirectory,
    required this.displayPath,
    this.lastAccessed,
  });

  // Create a copy with updated fields
  FileItem copyWith({
    String? uri,
    String? name,
    bool? isDirectory,
    String? displayPath,
    DateTime? lastAccessed,
  }) {
    return FileItem(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      displayPath: displayPath ?? this.displayPath,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  // Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
      'isDirectory': isDirectory,
      'displayPath': displayPath,
      'lastAccessed': lastAccessed?.millisecondsSinceEpoch,
    };
  }

  // Create from JSON
  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      uri: json['uri'] ?? '',
      name: json['name'] ?? '',
      isDirectory: json['isDirectory'] ?? false,
      displayPath: json['displayPath'] ?? '',
      lastAccessed: json['lastAccessed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastAccessed'])
          : null,
    );
  }

  // Helper method to check if this is a markdown file
  bool get isMarkdownFile => !isDirectory && name.toLowerCase().endsWith('.md');

  // Helper method to get relative path for display
  String get relativePath {
    if (displayPath.startsWith('/')) {
      return displayPath.substring(1);
    }
    return displayPath;
  }

  @override
  String toString() {
    return 'FileItem(name: $name, isDirectory: $isDirectory, lastAccessed: $lastAccessed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileItem &&
        other.uri == uri &&
        other.name == name &&
        other.isDirectory == isDirectory &&
        other.displayPath == displayPath &&
        other.lastAccessed == lastAccessed;
  }

  @override
  int get hashCode {
    return Object.hash(uri, name, isDirectory, displayPath, lastAccessed);
  }
}
