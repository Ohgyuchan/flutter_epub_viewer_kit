/// Represents the current reading position in an EPUB book.
///
/// This class is used to save and restore reading progress.
class ReadingPosition {
  /// The current page index (0-based).
  final int pageIndex;

  /// The total number of pages.
  final int totalPages;

  /// The reading progress (0.0 to 1.0).
  final double progress;

  /// When this position was recorded.
  final DateTime updatedAt;

  const ReadingPosition({
    required this.pageIndex,
    required this.totalPages,
    required this.progress,
    required this.updatedAt,
  });

  /// Creates a [ReadingPosition] from a JSON map.
  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    return ReadingPosition(
      pageIndex: json['pageIndex'] as int,
      totalPages: json['totalPages'] as int,
      progress: (json['progress'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Converts this [ReadingPosition] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'pageIndex': pageIndex,
      'totalPages': totalPages,
      'progress': progress,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingPosition &&
        other.pageIndex == pageIndex &&
        other.totalPages == totalPages &&
        other.progress == progress;
  }

  @override
  int get hashCode => Object.hash(pageIndex, totalPages, progress);

  @override
  String toString() {
    return 'ReadingPosition(page: $pageIndex/$totalPages, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}
