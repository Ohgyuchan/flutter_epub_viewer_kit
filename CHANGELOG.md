## 0.3.0

### Breaking Changes
- Theme presets reduced to three: White, Dark, Black. The `Warm`, `Gray`, `Green`, and `Blue Gray` presets are removed — code that looks up removed preset names in `colorThemes` must be updated
- Default reader colors changed from `#FFFBF0`/black to the White preset (`#FFFFFF` background, `#212529` text). Saved user settings are unaffected
- Dark and Black preset text colors toned down for comfortable night reading (`#C8C8C8` / `#B8B8B8` instead of pure white)

### New Features
- `ColorTheme` gains an optional `accent` color; `ReaderSettings` exposes derived chrome tokens: `accentColor`, `mutedColor`, `dividerColor`, `surfaceColor`
- Default bottom bar with a page slider and `current / total` indicator — drag to jump to a page; a custom `bottomBarBuilder` still replaces it
- Reading progress bar (shown when bars are hidden) now defaults to the accent color; `progressBarColor` still overrides

### Improvements
- Settings panel redesigned: drag handle, accent selection rings on theme swatches, font chips rendered in their own typeface, pill-style steppers, custom segmented view-mode toggle (hardcoded blue selection color removed)
- Top bar restyled with surface color and hairline divider; loading and error states follow the theme tokens
- Page slider announces "page / total" to screen readers

### Example
- Example app aligned with the new tokens; bookmark list redesigned to match the reader's design language
- Sample EPUBs consolidated to a single `example.epub`

## 0.2.0

### Breaking Changes
- `EpubReaderWidget` no longer wraps itself in a `Scaffold` — it is now an embeddable widget. Wrap it in your own `Scaffold` (or any layout); `SafeArea` is still applied internally
- `topBarBuilder`/`bottomBarBuilder` now receive a third `ReadingPosition` parameter and both return `Widget` — the `PreferredSizeWidget` requirement on the top bar is dropped (its `preferredSize` was never used)
- `showTopBar`/`showBottomBar: false` now disables that bar entirely — the center tap toggle no longer resurrects explicitly disabled bars, and prop changes apply on rebuild
- `SettingsPanel` removed from public exports — it was unusable (its constructor requires `SettingsNotifier`, which was never exported)

### Bug Fixes
- Fix custom `fontFamily` being silently ignored — unknown font names are now applied as-is, enabling app-bundled fonts
- Add missing `==`/`hashCode` to `EpubSourceBytes` — passing a new instance with identical bytes on rebuild no longer reloads the entire book
- Fix race condition when swapping the EPUB source while a previous load is in flight — a stale load can no longer overwrite the newly requested book
- Fix unnecessary full repagination when toggling page/scroll view mode — layout metrics are unchanged, so the pagination cache is kept

### Documentation & Example
- Document `progressBarColor`, `title`, `onLoadingProgress`, tap zones, bar builder contract, and the persistence-over-`initialSettings` precedence in README
- Example app now demonstrates localization presets, `progressBarColor`, asset book selection, in-reader dynamic source swap, and the new bar builder signature
- Replace the example's stale counter template test with a real smoke test

## 0.1.3

### Bug Fixes
- Fix content failing to load for EPUBs with a sparse or incomplete `toc.ncx` (common with Calibre-generated files) — reader now falls back to the spine, which is the authoritative reading order per the EPUB spec, so books where NCX only references the title page now render all content

### New Features
- Skip the cover/title page from the reading flow — detects cover via `<guide type="cover">`, EPUB 3 `properties="cover-image"`, and EPUB 2 `<meta name="cover">` so the reader opens on actual content instead of the cover image

## 0.1.2

### New Features
- Add `progressBarColor` parameter to customize the reading progress bar color

## 0.1.1

### Bug Fixes
- Fix page content changing when toggling top/bottom bars — reader now uses stable viewport constraints regardless of bar visibility, preventing unnecessary repagination

### New Features
- Add reading progress bar at the top of the screen when bars are hidden (2px thin indicator)
- Top/bottom bars now render as overlays instead of resizing the reader content area (iBooks/Kindle-style UX)

## 0.1.0

### Bug Fixes
- Fix pagination freeze — `_isPaginating` flag now resets on cancelled pagination runs, preventing permanent loading screen
- Fix paragraph index gaps in EPUBs with multi-row tables, which caused scroll-mode page tracking errors
- Fix settings panel overflow on small screens — Color Theme, Font Family, View Mode selectors now use `Wrap`/`Column` layout
- Fix `_buildControlRow` label overflow with long localized strings — label now uses `Flexible` with ellipsis
- Fix `onSettingsChanged` callback firing on every scroll/page turn — now only fires on actual settings changes
- Fix content area wasting 56px when bottom bar is hidden — layout now adapts dynamically to bar visibility
- Fix `Bookmark.copyWith` unable to clear nullable `title`/`excerpt` fields — uses sentinel pattern

### New Features
- Support swapping EPUB source without recreating the widget (`didUpdateWidget`)
- Add `==`/`hashCode` to `ReaderSettings`, `EpubSource` subclasses, and `Bookmark.copyWith` sentinel support

### Performance
- Parallelize settings storage load and EPUB parsing on startup (previously sequential)
- Eliminate redundant `setSettings` calls on every scroll tick

### Internal
- Extract `_buildSection` helper in settings panel to reduce layout duplication
- Unify duplicated table-splitting logic into single loop in `_loadBookContent`

## 0.0.9

- Add multi-language localization support with `EpubReaderLocalization`
- Built-in translations for 11 languages: Korean (default), English, Chinese (Simplified), Hindi, Spanish, Arabic, French, Portuguese, Russian, Japanese, German
- All UI strings (settings panel labels, error messages) are fully localizable
- Custom translations supported via constructor with Korean defaults for backwards compatibility
- Fix `fontSansSerif` English value from `'Gothic'` to `'Sans-serif'`
- Fix non-`EpubLoadException` errors displaying raw `e.toString()` instead of localized unknown error message
- Localize Noto Sans font button label via `fontNotoSans` field for consistency
- Change `ColorTheme.name` values from Korean to English

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
