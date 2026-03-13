## 0.0.8

- Fix images not rendering in EPUB files — image-only elements (e.g. `<img>` directly in `<body>`) were misclassified as spacing and silently dropped
- Fix `getElementsByTagName` not matching when the element itself is the `<img>` tag — now also checks `element.localName`
- Fix image paragraphs being filtered out due to empty `plainText` — `richContent` type now bypasses text-based filtering
- Fix pagination for image-heavy EPUBs — each image paragraph is allocated a full page instead of near-zero height
- Add `blockTags` support for `img`, `image`, `svg` in `_splitIntoBlockElements`
- Wrap standalone `<img>` elements in `<div>` for correct `flutter_html` `TagExtension` handling
- Improve EPUB image path resolution with filename-based and case-insensitive fallback matching

## 0.0.7

- Fix pagination density: pages no longer show only 1-2 lines or half-empty content
- Add `_ParagraphType` classification (plainText, dialogue, richContent, spacing) for accurate per-type measurement and rendering
- Fix dialogue table rendering: measure and render with matching two-column layout (name + text)
- Fix `requiresRichContent` always being true — plain text paragraphs now use `Text` widget instead of `Html`
- Preserve spacing paragraphs (`&#160;`) for proper section gaps
- Split multi-row dialogue tables into individual paragraph items
- Reduce safe margin from 2x to 1x line height for better page utilization
- Remove unsupported platform files (linux, macos, windows) from example app

## 0.0.6

- Add comprehensive example app with feature configuration screen
- Add page/scroll mode toggle to settings panel
- Example app demonstrates all widget features: source types, watermark, max pages, persistence, resume position, custom bars, initial bookmarks

## 0.0.5

- Remove flutter_riverpod dependency to prevent version conflicts with user apps
- Replace Riverpod with Flutter's built-in ChangeNotifier for internal state management
- Remove unused bookmarks_provider.dart

## 0.0.3

- Remove unused platform runners (linux, macos, windows)
- Update README for pub.dev installation

## 0.0.2

- Initial release
- EPUB reader widget with pagination and scroll modes
- Customizable themes and fonts
- Bookmark management
- Settings persistence
- Support for iOS, Android, and Web platforms
