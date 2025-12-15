import 'dart:math';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:epub_view/src/data/epub_parser.dart' as epub_parser;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:html/dom.dart' as dom;

import '../epub_reader_controller.dart';
import '../models/bookmark.dart';
import '../models/epub_source.dart';
import '../models/reader_settings.dart';
import '../providers/settings_provider.dart';
import '../utils/epub_loader.dart';
import '../utils/settings_storage.dart';
import 'settings_panel.dart';

/// Callback when page changes.
typedef OnPageChanged = void Function(int currentPage, int totalPages);

/// Callback when loading progress changes.
typedef OnLoadingProgress = void Function(double progress);

/// Callback when an error occurs.
typedef OnError = void Function(String error);

/// Callback when book is loaded.
typedef OnBookLoaded = void Function(String? title, String? author);

/// Callback when max readable page limit is reached.
typedef OnMaxPageReached = void Function(int maxPage, int totalPages);

class _ParagraphData {
  _ParagraphData({
    required this.index,
    required this.chapterIndex,
    required dom.Element element,
  })  : _element = element,
        html = element.outerHtml,
        plainText = element.text.trim(),
        requiresRichContent = element.outerHtml != element.text;

  final int index;
  final int chapterIndex;
  final String html;
  final String plainText;
  final bool requiresRichContent;
  final dom.Element _element;

  String get measurementText => plainText.isEmpty ? ' ' : plainText;

  bool get isWhitespaceOnly => plainText.isEmpty && !requiresRichContent;

  dom.Element cloneElement() => _element.clone(true);
}

List<dom.Element> _splitIntoBlockElements(dom.Element element) {
  final result = <dom.Element>[];

  const blockTags = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'section',
    'article',
    'aside',
    'header',
    'footer',
    'blockquote',
    'pre',
    'ul',
    'ol',
    'li',
    'dl',
    'dt',
    'dd',
    'figure',
    'figcaption',
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'br',
  };

  const containerTags = {'section', 'div', 'article', 'aside', 'body'};

  final tagName = element.localName?.toLowerCase() ?? '';
  final isContainer = containerTags.contains(tagName);

  if (isContainer) {
    final children = element.children.toList();
    final blockChildren = <dom.Element>[];

    for (var child in children) {
      final childTag = child.localName?.toLowerCase() ?? '';

      if (blockTags.contains(childTag) && childTag != 'br') {
        final cloned = child.clone(true);
        blockChildren.add(cloned);
      } else if (isContainer && child.children.isNotEmpty) {
        final nestedBlocks = _splitIntoBlockElements(child);
        blockChildren.addAll(nestedBlocks);
      }
    }

    if (blockChildren.isNotEmpty) {
      result.addAll(blockChildren);
    } else {
      result.add(element);
    }
  } else {
    result.add(element);
  }

  return result;
}

class _PageContent {
  _PageContent(this.paragraphs);

  final List<_ParagraphData> paragraphs;

  bool get isEmpty => paragraphs.isEmpty;

  int get firstParagraphIndex => isEmpty ? 0 : paragraphs.first.index;

  String get htmlFragment =>
      paragraphs.map((paragraph) => paragraph.html).join();

  String get plainText => paragraphs
      .map((paragraph) => paragraph.plainText)
      .where((text) => text.isNotEmpty)
      .join('\n\n');
}

/// A customizable EPUB reader widget.
///
/// Control bookmarks and settings via [EpubReaderController].
///
/// Example:
/// ```dart
/// final controller = EpubReaderController(
///   initialProgress: 0.5,
///   initialBookmarks: savedBookmarks,
///   onPositionChanged: (pos) => saveProgress(pos.progress),
///   onBookmarkAdded: (b) => saveBookmark(b),
/// );
///
/// EpubReaderWidget(
///   source: EpubSourceAsset('assets/book.epub'),
///   controller: controller,
///   onPageChanged: (current, total) => print('Page $current of $total'),
/// )
/// ```
class EpubReaderWidget extends StatelessWidget {
  /// Creates an EPUB reader widget.
  const EpubReaderWidget({
    super.key,
    required this.source,
    this.controller,
    this.initialSettings,
    this.onPageChanged,
    this.onLoadingProgress,
    this.onError,
    this.onBookLoaded,
    this.onMaxPageReached,
    this.showTopBar = true,
    this.showBottomBar = true,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.title,
    this.watermark,
    this.maxReadablePages,
    this.settingsStorageKey = 'epub_reader_settings',
  });

  /// The source of the EPUB file.
  final EpubSource source;

  /// Optional controller for programmatic control.
  /// Use this to control bookmarks, settings, and navigation.
  final EpubReaderController? controller;

  /// Initial reader settings.
  final ReaderSettings? initialSettings;

  /// Called when the current page changes.
  final OnPageChanged? onPageChanged;

  /// Called when loading progress changes.
  final OnLoadingProgress? onLoadingProgress;

  /// Called when an error occurs.
  final OnError? onError;

  /// Called when the book is loaded.
  final OnBookLoaded? onBookLoaded;

  /// Called when max readable page limit is reached.
  final OnMaxPageReached? onMaxPageReached;

  /// Whether to show the default top bar.
  final bool showTopBar;

  /// Whether to show the default bottom bar.
  final bool showBottomBar;

  /// Custom top bar builder. If provided, replaces the default top bar.
  final PreferredSizeWidget Function(
      BuildContext context, ReaderSettings settings)? topBarBuilder;

  /// Custom bottom bar builder. If provided, replaces the default bottom bar.
  final Widget Function(BuildContext context, ReaderSettings settings)?
      bottomBarBuilder;

  /// Title displayed in the top bar.
  final String? title;

  /// Optional watermark widget rendered behind the reader content.
  ///
  /// Provide any widget (e.g., `Opacity(child: Image.asset(...))` or an SVG)
  /// to display it centered beneath the text without blocking interactions.
  final Widget? watermark;

  /// Maximum number of pages the user can read.
  ///
  /// If set, the reader will prevent navigation beyond this page limit.
  /// Useful for preview/trial mode or restricting access to paid content.
  /// When null, all pages are accessible.
  final int? maxReadablePages;

  /// Storage key for persisting reader settings.
  ///
  /// Settings are automatically saved to and loaded from device storage
  /// using this key. Defaults to 'epub_reader_settings'.
  /// Set to null to disable automatic persistence.
  final String? settingsStorageKey;

  @override
  Widget build(BuildContext context) {
    // Use widget's initialSettings, or fall back to controller's initialSettings
    final effectiveSettings = initialSettings ?? controller?.initialSettings;
    final storage = settingsStorageKey != null
        ? SettingsStorage(storageKey: settingsStorageKey)
        : null;

    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() {
          final settingsNotifier = SettingsNotifier();
          if (effectiveSettings != null) {
            settingsNotifier.setInitialSettings(effectiveSettings);
          }
          if (storage != null) {
            settingsNotifier.setStorage(storage);
          }
          return settingsNotifier;
        }),
      ],
      child: _EpubReaderContent(
        source: source,
        controller: controller,
        onPageChanged: onPageChanged,
        onLoadingProgress: onLoadingProgress,
        onError: onError,
        onBookLoaded: onBookLoaded,
        onMaxPageReached: onMaxPageReached,
        showTopBar: showTopBar,
        showBottomBar: showBottomBar,
        topBarBuilder: topBarBuilder,
        bottomBarBuilder: bottomBarBuilder,
        title: title,
        watermark: watermark,
        maxReadablePages: maxReadablePages,
      ),
    );
  }
}

class _EpubReaderContent extends ConsumerStatefulWidget {
  const _EpubReaderContent({
    required this.source,
    this.controller,
    this.onPageChanged,
    this.onLoadingProgress,
    this.onError,
    this.onBookLoaded,
    this.onMaxPageReached,
    this.showTopBar = true,
    this.showBottomBar = true,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.title,
    this.watermark,
    this.maxReadablePages,
  });

  final EpubSource source;
  final EpubReaderController? controller;
  final OnPageChanged? onPageChanged;
  final OnLoadingProgress? onLoadingProgress;
  final OnError? onError;
  final OnBookLoaded? onBookLoaded;
  final OnMaxPageReached? onMaxPageReached;
  final bool showTopBar;
  final bool showBottomBar;
  final PreferredSizeWidget Function(
      BuildContext context, ReaderSettings settings)? topBarBuilder;
  final Widget Function(BuildContext context, ReaderSettings settings)?
      bottomBarBuilder;
  final String? title;
  final Widget? watermark;
  final int? maxReadablePages;

  @override
  ConsumerState<_EpubReaderContent> createState() => _EpubReaderContentState();
}

class _EpubReaderContentState extends ConsumerState<_EpubReaderContent> {
  final PageController _pageController = PageController();
  final ItemScrollController _scrollItemController = ItemScrollController();
  final ItemPositionsListener _scrollPositions = ItemPositionsListener.create();

  bool _showTopBar = true;
  bool _showBottomBar = true;

  List<_ParagraphData> _paragraphs = [];
  List<_PageContent> _pages = [];

  epubx.EpubBook? _loadedBook;
  String? _loadError;

  int _currentPageIndex = 0;
  int _currentScrollPage = 1;
  double _lastProgress = 0.0;

  String? _paginateCacheKey;
  bool _isPaginating = false;
  double _paginationProgress = 0.0;
  int _paginationGeneration = 0;

  int? _pendingScrollParagraphIndex;

  /// Returns the effective maximum readable page count.
  /// If maxReadablePages is null, returns total pages.
  int get _effectiveMaxPages {
    final total = _pages.length;
    final maxPages = widget.maxReadablePages;
    if (maxPages == null || maxPages <= 0) return total;
    return min(maxPages, total);
  }

  /// Checks if the given page index exceeds the max readable limit.
  bool _isPageLimited(int pageIndex) {
    final maxPages = widget.maxReadablePages;
    if (maxPages == null || maxPages <= 0) return false;
    return pageIndex >= maxPages;
  }

  @override
  void initState() {
    super.initState();
    _showTopBar = widget.showTopBar;
    _showBottomBar = widget.showBottomBar;
    _scrollPositions.itemPositions.addListener(_handleScrollPositions);
    // Initialize from controller
    final initialProgress = widget.controller?.initialProgress;
    if (initialProgress != null) {
      _lastProgress = initialProgress.clamp(0.0, 1.0);
    }
    _bindController();
    // Load saved settings from storage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).loadFromStorage();
    });
    _loadBookContent();
  }

  @override
  void dispose() {
    _unbindController();
    _scrollPositions.itemPositions.removeListener(_handleScrollPositions);
    _pageController.dispose();
    super.dispose();
  }

  void _bindController() {
    widget.controller?.bindCallbacks(
      onNextPage: _nextPage,
      onPreviousPage: _previousPage,
      onGoToPage: (page) => _goToPage(page),
      onGoToProgress: (progress) => _goToProgress(progress),
      onUpdateSettings: (settings) {
        ref.read(settingsProvider.notifier).setSettings(settings);
      },
      onAddBookmark: _addBookmark,
      onRemoveBookmark: _removeBookmark,
      onShowSettings: _showSettingsModal,
    );
  }

  void _showSettingsModal() {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (modalContext) => UncontrolledProviderScope(
        container: container,
        child: SettingsPanel(onSettingsChanged: _onSettingsChanged),
      ),
    );
  }

  void _onSettingsChanged() {
    setState(() {
      _paginateCacheKey = null;
      _pages = [];
      _paginationProgress = 0.0;
    });
  }

  void _addBookmark() {
    if (_pages.isEmpty) return;

    // Get current page excerpt
    String? excerpt;
    if (_currentPageIndex < _pages.length) {
      final page = _pages[_currentPageIndex];
      if (page.paragraphs.isNotEmpty) {
        excerpt = page.plainText;
        if (excerpt.length > 100) {
          excerpt = '${excerpt.substring(0, 100)}...';
        }
      }
    }

    final bookmark = Bookmark(
      pageIndex: _currentPageIndex,
      progress: _lastProgress,
      title: widget.title ?? _loadedBook?.Title,
      excerpt: excerpt,
      createdAt: DateTime.now(),
    );

    // addBookmarkInternal calls controller's onBookmarkAdded callback
    widget.controller?.addBookmarkInternal(bookmark);
  }

  void _removeBookmark(Bookmark bookmark) {
    // removeBookmarkInternal calls controller's onBookmarkRemoved callback
    widget.controller?.removeBookmarkInternal(bookmark);
  }

  void _unbindController() {
    widget.controller?.unbindCallbacks();
  }

  void _updateControllerState() {
    widget.controller?.setPageInfo(_currentPageIndex, _pages.length);
    widget.controller?.setSettings(ref.read(settingsProvider));
    widget.controller?.setLoading(_loadedBook == null && _loadError == null);

    // Notify position change via controller callback
    if (_pages.isNotEmpty) {
      widget.controller?.notifyPositionChanged();
    }
  }

  Future<void> _loadBookContent() async {
    try {
      widget.controller?.setLoading(true);
      debugPrint('EPUB 파일 로딩 시작...');

      final bytes = await EpubLoader.load(widget.source);
      debugPrint('EPUB 파일 크기: ${bytes.length} bytes');

      final book = await epubx.EpubReader.readBook(bytes);
      debugPrint('EPUB 파싱 완료. 책 제목: ${book.Title}');

      widget.onBookLoaded?.call(book.Title, book.Author);

      final flattenedChapters = epub_parser.parseChapters(book);
      debugPrint('챕터 개수: ${flattenedChapters.length}');

      if (flattenedChapters.isEmpty) {
        debugPrint('경고: 파싱된 챕터가 없습니다!');
        if (mounted) {
          setState(() {
            _loadedBook = book;
            _paragraphs = [];
            _pages = [];
          });
          widget.controller?.setLoading(false);
        }
        return;
      }

      final parseResult = epub_parser.parseParagraphs(
        flattenedChapters,
        book.Content,
      );
      final sourceParagraphs = parseResult.flatParagraphs;
      debugPrint('파싱된 문단 개수: ${sourceParagraphs.length}');

      if (sourceParagraphs.isEmpty) {
        debugPrint('경고: 파싱된 문단이 없습니다!');
        if (mounted) {
          setState(() {
            _loadedBook = book;
            _paragraphs = [];
            _pages = [];
          });
          widget.controller?.setLoading(false);
        }
        return;
      }

      final paragraphData = <_ParagraphData>[];
      int globalIndex = 0;
      final totalParagraphs = sourceParagraphs.length;

      for (var i = 0; i < sourceParagraphs.length; i++) {
        final paragraph = sourceParagraphs[i];
        try {
          final clonedElement = paragraph.element.clone(true);
          final blockElements = _splitIntoBlockElements(clonedElement);

          if (blockElements.length > 1) {
            for (var j = 0; j < blockElements.length; j++) {
              final blockElement = blockElements[j];
              final testText = blockElement.text.trim();
              if (testText.isEmpty) continue;

              final paragraphDataItem = _ParagraphData(
                index: globalIndex++,
                chapterIndex: paragraph.chapterIndex,
                element: blockElement,
              );

              if (!paragraphDataItem.isWhitespaceOnly &&
                  paragraphDataItem.plainText.isNotEmpty) {
                paragraphData.add(paragraphDataItem);
              }
            }
          } else {
            final paragraphDataItem = _ParagraphData(
              index: globalIndex++,
              chapterIndex: paragraph.chapterIndex,
              element: clonedElement,
            );
            if (!paragraphDataItem.isWhitespaceOnly &&
                paragraphDataItem.plainText.isNotEmpty) {
              paragraphData.add(paragraphDataItem);
            }
          }
        } catch (e) {
          debugPrint('문단 $i 파싱 중 오류: $e');
        }

        // Report loading progress
        final progress = (i + 1) / totalParagraphs;
        widget.onLoadingProgress?.call(progress * 0.5); // First 50% for parsing
      }

      debugPrint('최종 문단 데이터 개수: ${paragraphData.length}');

      if (!mounted) return;

      setState(() {
        _loadedBook = book;
        _paragraphs = paragraphData;
        _pages = [];
        _paginateCacheKey = null;
        _currentPageIndex = 0;
        _currentScrollPage = 1;
        // _lastProgress는 initState에서 initialProgress로 설정되었으므로 덮어쓰지 않음
      });

      widget.controller?.setLoading(false);
      _updateControllerState();
    } catch (e, stackTrace) {
      debugPrint('EPUB 로드 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');

      final errorMessage = e is EpubLoadException ? e.message : e.toString();
      widget.onError?.call(errorMessage);
      widget.controller?.setError(errorMessage);

      if (mounted) {
        setState(() {
          _loadError = errorMessage;
          _paragraphs = [];
          _pages = [];
        });
      }
    }
  }

  void _goToPage(int pageIndex) {
    if (_pages.isEmpty) return;

    final maxAllowed = _effectiveMaxPages - 1;
    final upperBound = min(_pages.length - 1, maxAllowed);
    final targetIndex = pageIndex.clamp(0, upperBound);

    // Check if trying to go beyond limit
    if (_isPageLimited(pageIndex)) {
      widget.onMaxPageReached?.call(_effectiveMaxPages, _pages.length);
    }

    final settings = ref.read(settingsProvider);

    if (settings.isPageMode) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _animateToScrollPage(targetIndex);
    }

    final totalPages = max(1, _pages.length - 1);
    final progress = _pages.length <= 1 ? 0.0 : targetIndex / totalPages;

    setState(() {
      _currentPageIndex = targetIndex;
      _currentScrollPage = targetIndex + 1;
      _lastProgress = progress;
    });

    _updateControllerState();
  }

  void _goToProgress(double progress) {
    if (_pages.isEmpty) return;

    final targetPage =
        (_pages.length <= 1 ? 0 : (progress * (_pages.length - 1)).round())
            .clamp(0, _pages.length - 1);
    _goToPage(targetPage);
  }

  Future<void> _paginateParagraphs({
    required List<_ParagraphData> paragraphs,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required String cacheKey,
  }) async {
    final int generation = ++_paginationGeneration;
    _isPaginating = true;
    _paginationProgress = 0.0;
    _pages = [];

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: null,
    );

    final pages = <_PageContent>[];
    final currentPage = <_ParagraphData>[];
    double currentHeight = 0;

    final settings = ref.read(settingsProvider);
    final double paragraphSpacing = _paragraphSpacingFromStyle(style, settings);
    final totalParagraphs = paragraphs.length;
    final sw = Stopwatch()..start();

    for (var index = 0; index < totalParagraphs; index++) {
      if (generation != _paginationGeneration) return;

      final paragraph = paragraphs[index];
      final segment = paragraph.measurementText;
      painter.text = TextSpan(text: segment, style: style);
      painter.layout(maxWidth: maxWidth);
      final double paragraphHeight =
          paragraph.isWhitespaceOnly ? paragraphSpacing : painter.height;

      final additionalSpacing = currentPage.isEmpty ? 0.0 : paragraphSpacing;
      final nextHeight = currentHeight + paragraphHeight + additionalSpacing;
      final fits = nextHeight <= maxHeight || currentPage.isEmpty;
      if (fits) {
        currentHeight = nextHeight;
        currentPage.add(paragraph);
      } else {
        pages.add(_PageContent(List<_ParagraphData>.from(currentPage)));
        currentPage
          ..clear()
          ..add(paragraph);
        currentHeight = paragraphHeight;
      }

      final progress =
          totalParagraphs == 0 ? 1.0 : (index + 1) / totalParagraphs;
      if (progress - _paginationProgress >= 0.05 ||
          sw.elapsedMilliseconds > 50) {
        _paginationProgress = progress.clamp(0.0, 1.0);
        widget.onLoadingProgress
            ?.call(0.5 + progress * 0.5); // Second 50% for pagination
        if (mounted) setState(() {});
        await Future.delayed(Duration.zero);
        sw.reset();
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(_PageContent(List<_ParagraphData>.from(currentPage)));
    }

    if (!mounted || generation != _paginationGeneration) return;

    final totalPages = pages.isEmpty ? 0 : pages.length;
    final targetIndex = totalPages <= 1
        ? 0
        : (_lastProgress * (totalPages - 1)).round().clamp(0, totalPages - 1);

    final isPageMode = ref.read(settingsProvider).isPageMode;

    setState(() {
      _pages = pages;
      _paginateCacheKey = cacheKey;
      _isPaginating = false;
      _paginationProgress = 1.0;
      _currentPageIndex = targetIndex;
      _currentScrollPage = totalPages == 0 ? 1 : targetIndex + 1;
    });

    _updateControllerState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _paginationGeneration) return;
      if (_pageController.hasClients && targetIndex < _pages.length) {
        _pageController.jumpToPage(targetIndex);
      }
      if (!isPageMode) {
        _scheduleScrollToPage(_lastProgress);
      }
    });
  }

  double _paragraphSpacingFromStyle(TextStyle style, ReaderSettings settings) {
    return settings.actualParagraphSpacing;
  }

  List<Widget> _watermarkLayers() {
    final watermark = widget.watermark;
    if (watermark == null) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Center(
            // Wrap with Theme to prevent watermark color from being affected by settings changes
            child: Theme(
              data: ThemeData.light(),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.black,
                  inherit: false,
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.black),
                  child: watermark,
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildPagedReader(ReaderSettings settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = settings.actualMargin;
        final maxWidth = constraints.maxWidth - padding.horizontal;
        final maxHeight = constraints.maxHeight - padding.vertical;
        final textScaler = MediaQuery.textScalerOf(context);
        final key =
            '${maxWidth.toStringAsFixed(1)}x${maxHeight.toStringAsFixed(1)}'
            '|${settings.fontFamily}|${settings.fontSize}'
            '|${settings.lineSpacing}|${settings.margin}'
            '|${textScaler.scale(1.0).toStringAsFixed(2)}';

        if (_loadError != null) {
          return _buildErrorView(settings);
        }

        if (_loadedBook == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_paragraphs.isEmpty) {
          return _buildEmptyView(settings);
        }

        // Wait for valid layout constraints before pagination
        if (!maxWidth.isFinite ||
            !maxHeight.isFinite ||
            maxWidth <= 0 ||
            maxHeight <= 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final needsPagination = _paginateCacheKey != key || _pages.isEmpty;

        if (needsPagination) {
          if (!_isPaginating) {
            _isPaginating = true;
            Future.microtask(() {
              if (mounted) {
                _paginateParagraphs(
                  paragraphs: _paragraphs,
                  style: settings.textStyle,
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                  textScaler: textScaler,
                  cacheKey: key,
                );
              }
            });
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text('${(_paginationProgress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        }

        if (_pages.isEmpty) {
          return const SizedBox.shrink();
        }

        final readablePageCount = _effectiveMaxPages;

        return Stack(
          children: [
            Padding(
              padding: settings.actualMargin,
              child: PageView.builder(
                controller: _pageController,
                physics: const PageScrollPhysics(),
                itemCount: readablePageCount,
                onPageChanged: (index) {
                  final total = max(1, _pages.length - 1);
                  final progress = _pages.length <= 1 ? 0.0 : index / total;
                  setState(() {
                    _currentPageIndex = index;
                    _currentScrollPage = index + 1;
                    _lastProgress = progress;
                  });
                  widget.onPageChanged?.call(index + 1, _pages.length);
                  _updateControllerState();

                  // Notify when reaching last readable page
                  if (index == readablePageCount - 1 &&
                      readablePageCount < _pages.length) {
                    widget.onMaxPageReached
                        ?.call(readablePageCount, _pages.length);
                  }
                },
                itemBuilder: (context, index) =>
                    _buildPageView(settings, _pages[index], maxHeight),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPageIndex > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleBars,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPageIndex + 1 < readablePageCount) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        } else if (readablePageCount < _pages.length) {
                          // Trying to go beyond limit
                          widget.onMaxPageReached
                              ?.call(readablePageCount, _pages.length);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            ..._watermarkLayers(),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(ReaderSettings settings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '로드 실패',
              style: TextStyle(
                color: settings.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '알 수 없는 오류',
              style: TextStyle(
                color: settings.textColor.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ReaderSettings settings) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '콘텐츠를 불러올 수 없습니다',
            style: TextStyle(color: settings.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            'EPUB 파일 형식을 확인해주세요',
            style: TextStyle(
              color: settings.textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollReader(ReaderSettings settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = settings.actualMargin;
        final maxWidth = constraints.maxWidth - padding.horizontal;
        final maxHeight = constraints.maxHeight - padding.vertical;
        final textScaler = MediaQuery.textScalerOf(context);
        final key =
            '${maxWidth.toStringAsFixed(1)}x${maxHeight.toStringAsFixed(1)}'
            '|${settings.fontFamily}|${settings.fontSize}'
            '|${settings.lineSpacing}|${settings.margin}'
            '|${textScaler.scale(1.0).toStringAsFixed(2)}';

        if (_loadError != null) {
          return _buildErrorView(settings);
        }

        if (_loadedBook == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_paragraphs.isEmpty) {
          return _buildEmptyView(settings);
        }

        // Wait for valid layout constraints before pagination
        if (!maxWidth.isFinite ||
            !maxHeight.isFinite ||
            maxWidth <= 0 ||
            maxHeight <= 0) {
          return const Center(child: CircularProgressIndicator());
        }

        final needsPagination = _paginateCacheKey != key || _pages.isEmpty;

        if (needsPagination) {
          if (!_isPaginating) {
            _isPaginating = true;
            Future.microtask(() {
              if (mounted) {
                _paginateParagraphs(
                  paragraphs: _paragraphs,
                  style: settings.textStyle,
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                  textScaler: textScaler,
                  cacheKey: key,
                );
              }
            });
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text('${(_paginationProgress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        }

        // Calculate max paragraph index based on maxReadablePages
        final readablePageCount = _effectiveMaxPages;
        int effectiveParagraphCount = _paragraphs.length;
        if (readablePageCount > 0 &&
            readablePageCount < _pages.length &&
            _pages[readablePageCount - 1].paragraphs.isNotEmpty) {
          final maxParagraphIndex =
              _pages[readablePageCount - 1].paragraphs.last.index + 1;
          effectiveParagraphCount = min(maxParagraphIndex, _paragraphs.length);
        }

        return Stack(
          children: [
            GestureDetector(
              onTap: _toggleBars,
              child: Padding(
                padding: settings.actualMargin,
                child: ScrollablePositionedList.builder(
                  itemScrollController: _scrollItemController,
                  itemPositionsListener: _scrollPositions,
                  physics: const ClampingScrollPhysics(),
                  itemCount: effectiveParagraphCount,
                  itemBuilder: (context, index) {
                    final paragraph = _paragraphs[index];
                    final isLast = index == effectiveParagraphCount - 1;
                    return _buildParagraph(paragraph, settings, isLast: isLast);
                  },
                ),
              ),
            ),
            ..._watermarkLayers(),
          ],
        );
      },
    );
  }

  Widget _buildParagraph(
    _ParagraphData paragraph,
    ReaderSettings settings, {
    required bool isLast,
  }) {
    final spacing = isLast ? 0.0 : _paragraphSpacingForSettings(settings);

    if (paragraph.isWhitespaceOnly) {
      return spacing <= 0 ? const SizedBox.shrink() : SizedBox(height: spacing);
    }

    Widget content;
    if (!paragraph.requiresRichContent) {
      if (paragraph.plainText.isEmpty) {
        content = const SizedBox.shrink();
      } else {
        content = Text(
          paragraph.plainText,
          style: settings.textStyle,
          textAlign: TextAlign.start,
          softWrap: true,
        );
      }
    } else {
      if (paragraph.html.isEmpty || paragraph.html.trim().isEmpty) {
        content = const SizedBox.shrink();
      } else {
        try {
          final element = paragraph.cloneElement();
          element.classes.add('paragraph-root');
          content = RepaintBoundary(
            child: ClipRect(
              child: Html.fromElement(
                documentElement: element,
                style: {
                  '.paragraph-root': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ).merge(Style.fromTextStyle(settings.textStyle)),
                },
                extensions: _buildHtmlExtensions(_loadedBook),
              ),
            ),
          );
        } catch (e) {
          content = paragraph.plainText.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  paragraph.plainText,
                  style: settings.textStyle,
                  textAlign: TextAlign.start,
                  softWrap: true,
                );
        }
      }
    }

    if (spacing <= 0) return content;

    return Padding(
      padding: EdgeInsets.only(
        left: spacing,
        right: spacing,
        bottom: spacing,
      ),
      child: content,
    );
  }

  List<HtmlExtension> _buildHtmlExtensions(epubx.EpubBook? book) {
    final images = book?.Content?.Images;
    if (images == null || images.isEmpty) {
      return const [];
    }

    return [
      TagExtension(
        tagsToExtend: {'img'},
        builder: (context) {
          final rawSrc = context.attributes['src'];
          if (rawSrc == null) return const SizedBox();
          final normalized = rawSrc.replaceAll('../', '');
          final imageFile = images[normalized];
          final bytes = imageFile?.Content;
          if (bytes == null) return const SizedBox();
          return Image.memory(Uint8List.fromList(bytes));
        },
      ),
    ];
  }

  void _handleScrollPositions() {
    if (_pages.isEmpty) return;
    final positions = _scrollPositions.itemPositions.value;
    if (positions.isEmpty) return;

    final visible =
        positions.where((position) => position.itemTrailingEdge > 0).toList();
    if (visible.isEmpty) return;
    visible.sort((a, b) => a.index.compareTo(b.index));
    final first = visible.first;
    final paragraphIndex = first.index;
    final pageIndex = _pageIndexForParagraph(paragraphIndex);
    final totalPages = max(1, _pages.length);
    final ratio = totalPages <= 1 ? 0.0 : pageIndex / (totalPages - 1);

    final isPageMode = ref.read(settingsProvider).isPageMode;
    final readablePageCount = _effectiveMaxPages;

    if (pageIndex + 1 != _currentScrollPage ||
        (ratio - _lastProgress).abs() > 0.001) {
      setState(() {
        _currentScrollPage = pageIndex + 1;
        _lastProgress = ratio.clamp(0.0, 1.0);
        if (!isPageMode) {
          _currentPageIndex = pageIndex;
        }
      });
      widget.onPageChanged?.call(pageIndex + 1, _pages.length);
      _updateControllerState();

      // Notify when reaching last readable page in scroll mode
      if (pageIndex == readablePageCount - 1 &&
          readablePageCount < _pages.length) {
        widget.onMaxPageReached?.call(readablePageCount, _pages.length);
      }
    }
  }

  void _scheduleScrollToPage(double progress) {
    if (_pages.isEmpty) return;
    final targetPage =
        (_pages.length <= 1 ? 0 : (progress * (_pages.length - 1)).round())
            .clamp(0, _pages.length - 1);
    _pendingScrollParagraphIndex = _pages[targetPage].firstParagraphIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingScroll());
  }

  void _applyPendingScroll() {
    final target = _pendingScrollParagraphIndex;
    if (target == null) return;
    _pendingScrollParagraphIndex = null;
    _scrollToParagraph(target, animate: false, allowDeferred: true);
  }

  int _pageIndexForParagraph(int paragraphIndex) {
    if (_pages.isEmpty) return 0;
    for (var i = _pages.length - 1; i >= 0; i--) {
      final page = _pages[i];
      if (page.isEmpty) continue;
      if (paragraphIndex >= page.firstParagraphIndex) return i;
    }
    return 0;
  }

  void _scrollToParagraph(
    int paragraphIndex, {
    bool animate = true,
    bool allowDeferred = true,
  }) {
    if (_paragraphs.isEmpty) return;

    final targetIndex = paragraphIndex.clamp(0, _paragraphs.length - 1);
    final pageIndex = _pageIndexForParagraph(targetIndex);
    final totalPages = max(1, _pages.length - 1);
    final progress = _pages.length <= 1 ? 0.0 : pageIndex / totalPages;

    if (!_scrollItemController.isAttached) {
      if (allowDeferred) {
        _pendingScrollParagraphIndex = targetIndex;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _applyPendingScroll());
      }
      if (mounted) {
        setState(() {
          _currentPageIndex = pageIndex;
          _currentScrollPage = pageIndex + 1;
          _lastProgress = progress.clamp(0.0, 1.0);
        });
      }
      return;
    }

    if (animate) {
      _scrollItemController.scrollTo(
        index: targetIndex,
        alignment: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollItemController.jumpTo(index: targetIndex, alignment: 0);
    }

    if (mounted) {
      setState(() {
        _currentPageIndex = pageIndex;
        _currentScrollPage = pageIndex + 1;
        _lastProgress = progress.clamp(0.0, 1.0);
      });
    }
  }

  Widget _buildPageView(
    ReaderSettings settings,
    _PageContent page,
    double viewportHeight,
  ) {
    return SizedBox.expand(
      child: Align(
        alignment: Alignment.topLeft,
        child: ClipRect(
          child: SizedBox(
            height: viewportHeight,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < page.paragraphs.length; i++)
                    _buildParagraph(
                      page.paragraphs[i],
                      settings,
                      isLast: i == page.paragraphs.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    ref.listen<ReaderSettings>(settingsProvider, (previous, next) {
      if (previous?.isPageMode == next.isPageMode || _pages.isEmpty) return;

      if (next.isPageMode) {
        final targetPage = (_lastProgress * (_pages.length - 1)).round();
        final page = targetPage.clamp(0, _pages.length - 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(page);
          }
        });
        setState(() {
          _currentPageIndex = page;
          _currentScrollPage = page + 1;
        });
      } else {
        _scheduleScrollToPage(_lastProgress);
      }
    });

    final topBar = _showTopBar
        ? (widget.topBarBuilder?.call(context, settings) ??
            _buildTopOverlay(settings))
        : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: settings.backgroundColor,
      appBar: topBar,
      body: Stack(
        children: [
          // Background fill
          Positioned.fill(
            child: ColoredBox(color: settings.backgroundColor),
          ),
          // Reader content
          Positioned(
            top: kToolbarHeight,
            bottom: kToolbarHeight,
            left: 0,
            right: 0,
            child: settings.isPageMode
                ? _buildPagedReader(settings)
                : _buildScrollReader(settings),
          ),
          // Bottom bar
          if (_showBottomBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: widget.bottomBarBuilder != null
                  ? widget.bottomBarBuilder!(context, settings)
                  : _buildBottomOverlay(settings),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopOverlay(ReaderSettings settings) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Material(
        color: settings.backgroundColor.withValues(alpha: 0.95),
        elevation: 4,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title ?? _loadedBook?.Title ?? 'EPUB Reader',
                    style: TextStyle(
                      color: settings.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(ReaderSettings settings) {
    return const SizedBox.shrink();
  }

  void _animateToScrollPage(int pageIndex, {bool animate = true}) {
    if (_pages.isEmpty) return;
    final safeIndex = pageIndex.clamp(0, _pages.length - 1);
    final paragraphIndex = _pages[safeIndex].firstParagraphIndex;
    _scrollToParagraph(paragraphIndex, animate: animate);
  }

  double _paragraphSpacingForSettings(ReaderSettings settings) {
    return settings.actualParagraphSpacing;
  }

  void _previousPage() {
    final settings = ref.read(settingsProvider);
    if (settings.isPageMode) {
      if (_currentPageIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    } else {
      final target = (_currentPageIndex - 1).clamp(0, _pages.length - 1);
      _animateToScrollPage(target);
    }
  }

  void _nextPage() {
    final settings = ref.read(settingsProvider);
    final maxAllowed = _effectiveMaxPages;

    if (settings.isPageMode) {
      if (_currentPageIndex + 1 < maxAllowed) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else if (maxAllowed < _pages.length) {
        widget.onMaxPageReached?.call(maxAllowed, _pages.length);
      }
    } else {
      if (_currentPageIndex + 1 < maxAllowed) {
        final target = (_currentPageIndex + 1).clamp(0, maxAllowed - 1);
        _animateToScrollPage(target);
      } else if (maxAllowed < _pages.length) {
        widget.onMaxPageReached?.call(maxAllowed, _pages.length);
      }
    }
  }

  void _toggleBars() {
    setState(() {
      _showTopBar = !_showTopBar;
      _showBottomBar = !_showBottomBar;
    });
  }
}
