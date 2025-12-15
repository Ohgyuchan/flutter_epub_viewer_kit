// A customizable EPUB reader widget for Flutter.
// Supports iOS, Android, and Web platforms with features like
// pagination, scrolling, bookmarks, and customizable themes.

// Widgets
export 'src/widgets/epub_reader_widget.dart' show
    EpubReaderWidget,
    OnPageChanged,
    OnLoadingProgress,
    OnError,
    OnBookLoaded,
    OnMaxPageReached;
export 'src/widgets/settings_panel.dart' show SettingsPanel;

// Models
export 'src/models/reader_settings.dart' show ReaderSettings, ColorTheme, colorThemes;
export 'src/models/bookmark.dart' show Bookmark;
export 'src/models/reading_position.dart' show ReadingPosition;
export 'src/models/epub_source.dart'
    show EpubSource, EpubSourceFile, EpubSourceUrl, EpubSourceBytes, EpubSourceAsset;

// Controller
export 'src/epub_reader_controller.dart' show
    EpubReaderController,
    PositionChangedCallback,
    SettingsChangedCallback,
    BookmarkCallback;

// Utils (for advanced users)
export 'src/utils/epub_loader.dart' show EpubLoader, EpubLoadException;
