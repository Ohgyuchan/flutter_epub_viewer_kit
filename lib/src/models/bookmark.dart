/// Represents a bookmark in an EPUB book.
///
/// Bookmarks can be serialized to JSON for persistent storage.
class Bookmark {
  /// The page index where the bookmark is located (0-based).
  final int pageIndex;

  /// The reading progress at bookmark location (0.0 to 1.0).
  final double progress;

  /// Optional title or label for the bookmark.
  final String? title;

  /// Optional excerpt of text at the bookmark location.
  final String? excerpt;

  /// When this bookmark was created.
  final DateTime createdAt;

  const Bookmark({
    required this.pageIndex,
    required this.progress,
    this.title,
    this.excerpt,
    required this.createdAt,
  });

  /// Creates a [Bookmark] from a JSON map.
  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      pageIndex: json['pageIndex'] as int,
      progress: (json['progress'] as num).toDouble(),
      title: json['title'] as String?,
      excerpt: json['excerpt'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts this [Bookmark] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'pageIndex': pageIndex,
      'progress': progress,
      'title': title,
      'excerpt': excerpt,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy of this bookmark with the given fields replaced.
  Bookmark copyWith({
    int? pageIndex,
    double? progress,
    String? title,
    String? excerpt,
    DateTime? createdAt,
  }) {
    return Bookmark(
      pageIndex: pageIndex ?? this.pageIndex,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      excerpt: excerpt ?? this.excerpt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark &&
        other.pageIndex == pageIndex &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(pageIndex, progress);

  @override
  String toString() {
    return 'Bookmark(page: $pageIndex, progress: ${(progress * 100).toStringAsFixed(1)}%, title: $title)';
  }
}
