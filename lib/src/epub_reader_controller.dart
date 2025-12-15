import 'package:flutter/foundation.dart';

import 'models/bookmark.dart';
import 'models/reader_settings.dart';
import 'models/reading_position.dart';

/// Callback type definitions
typedef PageChangedCallback = void Function(int currentPage, int totalPages);
typedef ProgressChangedCallback = void Function(double progress);
typedef SettingsChangedCallback = void Function(ReaderSettings settings);
typedef PositionChangedCallback = void Function(ReadingPosition position);
typedef BookmarkCallback = void Function(Bookmark bookmark);

/// Controller for programmatically controlling the EPUB reader.
///
/// You can set initial values and callbacks directly on the controller,
/// which is useful when you want to manage state outside the widget.
///
/// Example:
/// ```dart
/// final controller = EpubReaderController(
///   initialProgress: 0.5,  // Start at 50%
///   initialSettings: savedSettings,
///   initialBookmarks: savedBookmarks,
///   onPositionChanged: (pos) => saveProgress(pos.progress),
///   onSettingsChanged: (settings) => saveSettings(settings),
///   onBookmarkAdded: (b) => saveBookmark(b),
///   onBookmarkRemoved: (b) => deleteBookmark(b),
/// );
///
/// EpubReaderWidget(
///   source: EpubSourceAsset('assets/book.epub'),
///   controller: controller,
/// )
///
/// // Control the reader
/// controller.nextPage();
/// controller.goToProgress(0.5);
/// controller.addBookmark();
/// ```
class EpubReaderController extends ChangeNotifier {
  /// Creates an EPUB reader controller.
  ///
  /// [initialProgress] sets the starting position (0.0 to 1.0).
  /// [initialSettings] sets the initial reader settings.
  /// [initialBookmarks] sets the initial list of bookmarks.
  /// [onPositionChanged] is called when reading position changes.
  /// [onSettingsChanged] is called when settings are changed.
  /// [onBookmarkAdded] is called when a bookmark is added.
  /// [onBookmarkRemoved] is called when a bookmark is removed.
  EpubReaderController({
    double? initialProgress,
    ReaderSettings? initialSettings,
    List<Bookmark>? initialBookmarks,
    this.onPositionChanged,
    this.onSettingsChanged,
    this.onBookmarkAdded,
    this.onBookmarkRemoved,
  }) : _initialProgress = initialProgress?.clamp(0.0, 1.0),
       _initialSettings = initialSettings,
       _settings = initialSettings ?? const ReaderSettings(),
       _bookmarks = initialBookmarks != null ? List.from(initialBookmarks) : [];

  int _currentPage = 0;
  int _totalPages = 0;
  double _progress = 0.0;
  final double? _initialProgress;
  final ReaderSettings? _initialSettings;
  ReaderSettings _settings;
  List<Bookmark> _bookmarks;
  bool _isLoading = true;
  String? _error;
  String? _currentExcerpt;

  /// Called when reading position changes.
  PositionChangedCallback? onPositionChanged;

  /// Called when settings are changed.
  SettingsChangedCallback? onSettingsChanged;

  /// Called when a bookmark is added.
  BookmarkCallback? onBookmarkAdded;

  /// Called when a bookmark is removed.
  BookmarkCallback? onBookmarkRemoved;

  // Internal callbacks for widget communication
  VoidCallback? _onNextPage;
  VoidCallback? _onPreviousPage;
  void Function(int)? _onGoToPage;
  void Function(double)? _onGoToProgress;
  void Function(ReaderSettings)? _onUpdateSettings;
  VoidCallback? _onAddBookmark;
  void Function(Bookmark)? _onRemoveBookmark;
  VoidCallback? _onShowSettings;

  /// Initial progress set in constructor (0.0 to 1.0).
  double? get initialProgress => _initialProgress;

  /// Initial settings set in constructor.
  ReaderSettings? get initialSettings => _initialSettings;

  /// Current page index (0-based).
  int get currentPage => _currentPage;

  /// Total number of pages.
  int get totalPages => _totalPages;

  /// Current reading progress (0.0 to 1.0).
  double get progress => _progress;

  /// Current reader settings.
  ReaderSettings get currentSettings => _settings;

  /// List of bookmarks.
  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);

  /// Whether the EPUB is currently loading.
  bool get isLoading => _isLoading;

  /// Error message if loading failed.
  String? get error => _error;

  /// Current reading position.
  ReadingPosition get currentPosition => ReadingPosition(
    pageIndex: _currentPage,
    totalPages: _totalPages,
    progress: _progress,
    updatedAt: DateTime.now(),
  );

  /// Whether the current page is bookmarked.
  bool get isCurrentPageBookmarked =>
      _bookmarks.any((b) => b.pageIndex == _currentPage);

  /// Check if a specific page is bookmarked.
  bool isPageBookmarked(int pageIndex) =>
      _bookmarks.any((b) => b.pageIndex == pageIndex);

  /// Get bookmark for a specific page, if exists.
  Bookmark? getBookmarkForPage(int pageIndex) {
    try {
      return _bookmarks.firstWhere((b) => b.pageIndex == pageIndex);
    } catch (_) {
      return null;
    }
  }

  /// Navigate to the next page.
  void nextPage() {
    _onNextPage?.call();
  }

  /// Navigate to the previous page.
  void previousPage() {
    _onPreviousPage?.call();
  }

  /// Navigate to a specific page.
  ///
  /// [pageIndex] is 0-based.
  void goToPage(int pageIndex) {
    _onGoToPage?.call(pageIndex);
  }

  /// Navigate to a specific progress position.
  ///
  /// [progress] should be between 0.0 and 1.0.
  void goToProgress(double progress) {
    _onGoToProgress?.call(progress.clamp(0.0, 1.0));
  }

  /// Update reader settings.
  void updateSettings(ReaderSettings settings) {
    _onUpdateSettings?.call(settings);
  }

  /// Show the settings modal panel.
  void showSettings() {
    _onShowSettings?.call();
  }

  /// Add a bookmark at the current position.
  void addBookmark() {
    _onAddBookmark?.call();
  }

  /// Remove a bookmark.
  void removeBookmark(Bookmark bookmark) {
    _onRemoveBookmark?.call(bookmark);
  }

  /// Toggle bookmark at the current position.
  /// Returns true if bookmark was added, false if removed.
  bool toggleBookmark() {
    final existing = _bookmarks.where((b) => b.pageIndex == _currentPage).toList();
    if (existing.isNotEmpty) {
      removeBookmark(existing.first);
      return false;
    } else {
      addBookmark();
      return true;
    }
  }

  /// Navigate to a bookmarked page.
  void goToBookmark(Bookmark bookmark) {
    goToPage(bookmark.pageIndex);
  }

  // Internal methods for widget to update controller state
  @internal
  void setPageInfo(int current, int total) {
    if (_currentPage != current || _totalPages != total) {
      _currentPage = current;
      _totalPages = total;
      _progress = total > 1 ? current / (total - 1) : 0.0;
      notifyListeners();
    }
  }

  @internal
  void setSettings(ReaderSettings settings) {
    if (_settings != settings) {
      _settings = settings;
      onSettingsChanged?.call(settings);
      notifyListeners();
    }
  }

  @internal
  void setBookmarks(List<Bookmark> bookmarks) {
    _bookmarks = List.from(bookmarks);
    notifyListeners();
  }

  @internal
  void addBookmarkInternal(Bookmark bookmark) {
    // Prevent duplicates
    if (_bookmarks.any((b) => b.pageIndex == bookmark.pageIndex)) {
      return;
    }
    _bookmarks.add(bookmark);
    onBookmarkAdded?.call(bookmark);
    notifyListeners();
  }

  @internal
  void removeBookmarkInternal(Bookmark bookmark) {
    final removed = _bookmarks.where((b) => b.pageIndex == bookmark.pageIndex).toList();
    _bookmarks.removeWhere((b) => b.pageIndex == bookmark.pageIndex);
    for (final b in removed) {
      onBookmarkRemoved?.call(b);
    }
    notifyListeners();
  }

  @internal
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  @internal
  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  @internal
  void setCurrentExcerpt(String? excerpt) {
    _currentExcerpt = excerpt;
  }

  @internal
  void notifyPositionChanged() {
    if (_totalPages > 0) {
      onPositionChanged?.call(currentPosition);
    }
  }

  String? get currentExcerpt => _currentExcerpt;

  @internal
  void bindCallbacks({
    VoidCallback? onNextPage,
    VoidCallback? onPreviousPage,
    void Function(int)? onGoToPage,
    void Function(double)? onGoToProgress,
    void Function(ReaderSettings)? onUpdateSettings,
    VoidCallback? onAddBookmark,
    void Function(Bookmark)? onRemoveBookmark,
    VoidCallback? onShowSettings,
  }) {
    _onNextPage = onNextPage;
    _onPreviousPage = onPreviousPage;
    _onGoToPage = onGoToPage;
    _onGoToProgress = onGoToProgress;
    _onUpdateSettings = onUpdateSettings;
    _onAddBookmark = onAddBookmark;
    _onRemoveBookmark = onRemoveBookmark;
    _onShowSettings = onShowSettings;
  }

  @internal
  void unbindCallbacks() {
    _onNextPage = null;
    _onPreviousPage = null;
    _onGoToPage = null;
    _onGoToProgress = null;
    _onUpdateSettings = null;
    _onAddBookmark = null;
    _onRemoveBookmark = null;
    _onShowSettings = null;
  }
}
