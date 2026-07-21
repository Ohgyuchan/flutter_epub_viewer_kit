# flutter_epub_viewer_kit

A customizable EPUB reader widget for Flutter. Supports iOS, Android, and Web platforms with features like pagination, bookmarks, and customizable themes.

![example.git](example.gif)

## Features

- EPUB file loading from assets, files, URLs, or bytes
- Page mode and scroll mode
- Customizable themes (background color, text color)
- Font family and size settings
- Line spacing and margin controls
- Bookmark management
- Resume reading from last position
- Custom top/bottom bar support
- Tap zones: left/right third to turn pages, center to toggle bars
- Thin reading progress bar when bars are hidden (customizable color)
- Optional watermark overlay via custom widget
- **Automatic settings persistence** - Reader settings are automatically saved to device storage
- Max readable pages limit (for preview/trial mode)
- **Multi-language localization** - Built-in support for 11 languages
- **Dynamic EPUB source swap** - Change the book without recreating the widget

```bash
flutter pub add flutter_epub_viewer_kit
```

## Basic Usage

```dart
import 'package:flutter_epub_viewer_kit/flutter_epub_viewer_kit.dart';

class ReaderPage extends StatefulWidget {
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final EpubReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The reader is an embeddable widget — it does not create its own
    // Scaffold, so place it inside your layout (SafeArea is built in).
    return Scaffold(
      body: EpubReaderWidget(
        source: const EpubSourceAsset('assets/book.epub'),
        controller: _controller,
        // Settings (theme, font, etc.) are automatically saved to device
        // Use a unique key per book if needed
        settingsStorageKey: 'epub_reader_settings',
        watermark: Opacity(
          opacity: 0.08,
          child: Image.asset('assets/watermark.png', width: 200),
        ),
      ),
    );
  }
}
```

## EPUB Sources

```dart
// From assets
EpubSourceAsset('assets/book.epub')

// From file path
EpubSourceFile('/path/to/book.epub')

// From URL
EpubSourceUrl('https://example.com/book.epub')

// From bytes
EpubSourceBytes(Uint8List bytes)
```

## Switching Books

You can swap the EPUB source dynamically without recreating the widget:

```dart
// The widget detects source changes and reloads automatically
EpubReaderWidget(
  source: _currentSource,  // Change this to load a different book
  controller: _controller,
);

// Example: switch book on button tap
void _switchBook() {
  setState(() {
    _currentSource = const EpubSourceAsset('assets/other_book.epub');
  });
}
```

## Controller

The `EpubReaderController` provides programmatic control and callbacks:

```dart
final controller = EpubReaderController(
  // Resume reading position (0.0 ~ 1.0)
  initialProgress: 0.5,

  // Initial bookmarks (load from your database)
  initialBookmarks: savedBookmarks,

  // Callbacks
  onPositionChanged: (position) {
    // Save position.progress to your database
  },
  onSettingsChanged: (settings) {
    // Settings are auto-saved, but you can also react to changes
  },
  onBookmarkAdded: (bookmark) {
    // Save bookmark to your database
  },
  onBookmarkRemoved: (bookmark) {
    // Remove bookmark from your database
  },
);
```

### Controller Methods

```dart
// Navigation
controller.nextPage();
controller.previousPage();
controller.goToPage(10);
controller.goToProgress(0.5);

// Bookmarks
controller.addBookmark();
controller.removeBookmark(bookmark);
controller.toggleBookmark();
controller.goToBookmark(bookmark);

// Settings
controller.showSettings();  // Shows built-in settings modal
controller.updateSettings(newSettings);

// Properties
controller.currentPage;      // Current page index (0-based)
controller.totalPages;       // Total number of pages
controller.progress;         // Reading progress (0.0 ~ 1.0)
controller.bookmarks;        // List of bookmarks
controller.currentSettings;  // Current ReaderSettings
controller.isCurrentPageBookmarked;
```

## Localization

All UI strings default to Korean for backwards compatibility. Use built-in presets or provide custom translations:

```dart
// English
EpubReaderWidget(
  source: source,
  localization: EpubReaderLocalization.english,
);

// Japanese
EpubReaderWidget(
  source: source,
  localization: EpubReaderLocalization.japanese,
);

// Custom language
EpubReaderWidget(
  source: source,
  localization: EpubReaderLocalization(
    theme: 'Tema',
    font: 'Fuente',
    fontSize: 'Tamaño',
    // ... all fields have Korean defaults, so you only need to override what you want
  ),
);
```

### Built-in Languages

| Language | Constant | Speakers |
| --- | --- | --- |
| Korean | `korean` (default) | 80M |
| English | `english` | 1.5B |
| Chinese (Simplified) | `chinese` | 1.1B |
| Hindi | `hindi` | 600M |
| Spanish | `spanish` | 550M |
| Arabic | `arabic` | 400M |
| French | `french` | 300M |
| Portuguese | `portuguese` | 260M |
| Russian | `russian` | 250M |
| Japanese | `japanese` | 125M |
| German | `german` | 100M |

### Localized Strings

All localizations cover the following UI elements:

| Category | Fields |
| --- | --- |
| Settings labels | `theme`, `font`, `fontSize`, `lineSpacing`, `margin`, `viewMode` |
| Mode labels | `pageMode`, `scrollMode`, `resetSettings` |
| Font names | `fontNotoSans`, `fontSerif`, `fontSansSerif` |
| Error messages | `loadFailed`, `unknownError`, `cannotLoadContent`, `checkFileFormat` |
| Misc | `themeSampleChar` (character shown in theme color swatches) |

Color theme names (`ColorTheme.name`) use English globally and are not part of localization.

## Reading UI

In page mode the screen is split into three tap zones: the left third goes to
the previous page, the right third goes to the next page, and the center
toggles the top/bottom bars. In scroll mode, tapping anywhere toggles the bars.

When the bars are hidden, a thin (2px) reading progress bar is shown at the
top. Customize its color with `progressBarColor`:

```dart
EpubReaderWidget(
  source: const EpubSourceAsset('assets/book.epub'),
  title: 'My Book',            // Shown in the default top bar
  progressBarColor: Colors.indigo,  // Default: text color at 30% opacity
);
```

## Custom Top/Bottom Bars

Both builders have the signature
`Widget Function(BuildContext context, ReaderSettings settings, ReadingPosition position)`
and are re-invoked whenever the page, progress, or settings change — read
current state from `position` (or from your controller):

```dart
EpubReaderWidget(
  source: const EpubSourceAsset('assets/book.epub'),
  controller: _controller,
  topBarBuilder: (context, settings, position) {
    return AppBar(
      backgroundColor: settings.backgroundColor,
      title: Text('My Reader', style: TextStyle(color: settings.textColor)),
      actions: [
        IconButton(
          icon: Icon(
            _controller.isCurrentPageBookmarked
                ? Icons.bookmark
                : Icons.bookmark_border,
          ),
          onPressed: () => _controller.toggleBookmark(),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _controller.showSettings(),
        ),
      ],
    );
  },
  bottomBarBuilder: (context, settings, position) {
    return Container(
      color: settings.backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${position.pageIndex + 1} / ${position.totalPages}',
            style: TextStyle(color: settings.textColor),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: settings.textColor),
                onPressed: () => _controller.previousPage(),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: settings.textColor),
                onPressed: () => _controller.nextPage(),
              ),
            ],
          ),
        ],
      ),
    );
  },
);
```

`showTopBar` / `showBottomBar` (default `true`) enable each bar. Setting one
to `false` disables that bar entirely — the center tap toggle only affects
enabled bars.

## ReaderSettings

```dart
const ReaderSettings({
  Color backgroundColor,    // Default: Color(0xFFFFFFFF)
  Color textColor,          // Default: Color(0xFF212529)
  String fontFamily,        // Default: 'Noto Sans'
  int fontSize,             // 1~9, Default: 4
  int lineSpacing,          // 1~5, Default: 2
  int margin,               // 1~5, Default: 1
  bool isPageMode,          // Default: true
});

// Computed values
settings.actualFontSize;        // 12~28px
settings.actualLineHeight;      // 1.2~2.0
settings.actualMargin;          // EdgeInsets (8~40px)
settings.actualParagraphSpacing;

// JSON serialization
final json = settings.toJson();
final restored = ReaderSettings.fromJson(json);
```

## Settings Persistence

Reader settings (theme, font size, line spacing, etc.) are **automatically saved** to device storage using SharedPreferences.

```dart
EpubReaderWidget(
  source: const EpubSourceAsset('assets/book.epub'),
  controller: _controller,
  // Default key: 'epub_reader_settings'
  // Use a unique key per book if you want separate settings
  settingsStorageKey: 'my_book_settings',
  // Set to null to disable auto-save
  // settingsStorageKey: null,
);
```

Settings are automatically:

- Loaded when the widget initializes
- Saved whenever settings change (theme, font, margin, etc.)
- Restored on app restart

Note: when persistence is enabled and saved settings exist, they take
precedence over `initialSettings`. Pass `settingsStorageKey: null` if you want
`initialSettings` to always apply.

### Manual Persistence (Position & Bookmarks)

Reading position and bookmarks are **not** auto-saved. Use callbacks to save them to your own storage:

```dart
final controller = EpubReaderController(
  initialProgress: savedProgress,  // Load from your database
  initialBookmarks: savedBookmarks,  // Load from your database
  onPositionChanged: (position) {
    // Save to your database
    database.saveProgress(bookId, position.progress);
  },
  onBookmarkAdded: (bookmark) {
    database.saveBookmark(bookId, bookmark.toJson());
  },
  onBookmarkRemoved: (bookmark) {
    database.deleteBookmark(bookId, bookmark.pageIndex);
  },
);
```

## Max Readable Pages (Preview Mode)

Limit how many pages users can read (useful for trial/preview mode):

```dart
EpubReaderWidget(
  source: const EpubSourceAsset('assets/book.epub'),
  controller: _controller,
  maxReadablePages: 10,  // Only first 10 pages are accessible
  onMaxPageReached: (maxPage, totalPages) {
    // Called when user tries to go beyond the limit
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview Limit'),
        content: Text('Purchase to read all $totalPages pages.'),
      ),
    );
  },
);
```

## Callbacks

```dart
EpubReaderWidget(
  source: source,
  controller: controller,
  onPageChanged: (current, total) {
    print('Page: $current / $total');
  },
  onBookLoaded: (title, author) {
    print('Loaded: $title by $author');
  },
  onError: (error) {
    print('Error: $error');
  },
  onLoadingProgress: (progress) {
    // 0.0 ~ 1.0 — parsing is the first half, pagination the second
    print('Loading: ${(progress * 100).toStringAsFixed(0)}%');
  },
  onMaxPageReached: (maxPage, totalPages) {
    print('Reached limit: $maxPage / $totalPages');
  },
);
```

## Available Font Families

Built-in fonts (loaded via Google Fonts) selectable in the settings panel:

- `'Noto Sans'` (default)
- `'Nanum Myeongjo'`
- `'Nanum Gothic'`

Any other `fontFamily` string is applied as-is, so you can use fonts bundled
in your app:

```dart
controller.updateSettings(
  controller.currentSettings.copyWith(fontFamily: 'MyBundledFont'),
);
```

## Color Themes

Built-in themes available via `colorThemes`:

| Name | Background | Text | Accent |
| --- | --- | --- | --- |
| White | #FFFFFF | #212529 | #2E7CE0 |
| Dark | #222326 | #C8C8C8 | #6AA5E8 |
| Black | #000000 | #B8B8B8 | #6AA5E8 |

Each `ColorTheme` also carries an optional `accent` (`Color?`) used for chrome
like selection rings and sliders. When `accent` is `null`, it falls back to a
brightness-based default. `ReaderSettings` exposes the resolved chrome tokens
as getters: `accentColor`, `mutedColor`, `dividerColor`, and `surfaceColor`.

## License

MIT
