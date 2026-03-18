import 'dart:math';
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:epub_view/src/data/epub_parser.dart' as epub_parser;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
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
import '../models/epub_reader_localization.dart';
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

enum _ParagraphType { plainText, dialogue, richContent, spacing }

class _ParagraphData {
  _ParagraphData({
    required this.index,
    required this.chapterIndex,
    required dom.Element element,
  })  : _element = element,
        html = element.outerHtml,
        plainText = element.text.trim(),
        dialogueName = null,
        dialogueText = null {
    final tag = element.localName?.toLowerCase() ?? '';
    final hasImage = tag == 'img' ||
        tag == 'image' ||
        tag == 'svg' ||
        element.getElementsByTagName('img').isNotEmpty ||
        element.getElementsByTagName('image').isNotEmpty ||
        element.getElementsByTagName('svg').isNotEmpty;
    final text = element.text.trim();
    if (hasImage) {
      type = _ParagraphType.richContent;
    } else if (text.isEmpty || text == '\u00A0') {
      type = _ParagraphType.spacing;
    } else if (_isDialogueTable(element)) {
      type = _ParagraphType.dialogue;
      final tds = element.getElementsByTagName('td');
      dialogueName = tds.isNotEmpty ? tds.first.text.trim() : null;
      dialogueText = tds.length >= 2 ? tds[1].text.trim() : null;
    } else {
      type = _ParagraphType.plainText;
    }
  }

  /// 긴 문단 분할용 생성자
  _ParagraphData.split({
    required this.index,
    required this.chapterIndex,
    required this.html,
    required this.plainText,
    dom.Element? element,
  })  : _element = element,
        type = _ParagraphType.plainText,
        dialogueName = null,
        dialogueText = null;

  /// 대화 테이블 행 분할용 생성자
  _ParagraphData.dialogue({
    required this.index,
    required this.chapterIndex,
    required this.dialogueName,
    required this.dialogueText,
  })  : _element = null,
        type = _ParagraphType.dialogue,
        html = '<p>${dialogueName ?? ''} ${dialogueText ?? ''}</p>',
        plainText = '${dialogueName ?? ''} ${dialogueText ?? ''}';

  final int index;
  final int chapterIndex;
  final String html;
  final String plainText;
  late final _ParagraphType type;
  String? dialogueName;
  String? dialogueText;
  final dom.Element? _element;

  String get measurementText => plainText.isEmpty ? ' ' : plainText;

  bool get isWhitespaceOnly => type == _ParagraphType.spacing;

  dom.Element? cloneElement() => _element?.clone(true);

  static bool _isDialogueTable(dom.Element element) {
    final tag = element.localName?.toLowerCase();
    if (tag == 'table') {
      final rows = element.getElementsByTagName('tr');
      return rows.length == 1 && element.getElementsByTagName('td').length >= 2;
    }
    return false;
  }
}

void _stripFontStyles(dom.Element element) {
  final style = element.attributes['style'];
  if (style != null) {
    final declarations = style
        .split(';')
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .where((d) {
          final prop = d.split(':').first.trim().toLowerCase();
          return prop != 'font-size' && prop != 'font-family';
        })
        .join('; ');
    if (declarations.isEmpty) {
      element.attributes.remove('style');
    } else {
      element.attributes['style'] = declarations;
    }
  }
  for (final child in element.children) {
    _stripFontStyles(child);
  }
}

/// 텍스트를 문장 단위로 분리
List<String> _splitIntoSentences(String text) {
  if (text.isEmpty) return [];

  final sentences = <String>[];
  final buffer = StringBuffer();

  // 문장 끝 문자들
  const sentenceEnds = {'.', '!', '?', '。', '？', '！'};

  for (int i = 0; i < text.length; i++) {
    final char = text[i];
    buffer.write(char);

    // 문장 끝 문자 발견
    if (sentenceEnds.contains(char)) {
      // 다음 문자가 공백, 줄바꿈, 또는 끝이면 문장 완료
      if (i + 1 >= text.length ||
          text[i + 1] == ' ' ||
          text[i + 1] == '\n' ||
          text[i + 1] == '"' ||
          text[i + 1] == '"' ||
          text[i + 1] == ')') {
        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
        // 뒤따르는 공백/따옴표 스킵
        while (i + 1 < text.length &&
               (text[i + 1] == ' ' || text[i + 1] == '"' || text[i + 1] == '"')) {
          i++;
        }
      }
    }
  }

  // 남은 텍스트 처리
  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    sentences.add(remaining);
  }

  return sentences;
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
    'img',
    'image',
    'svg',
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
class EpubReaderWidget extends StatefulWidget {
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
    this.localization = const EpubReaderLocalization(),
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

  /// Localization strings for the reader UI.
  ///
  /// Defaults to Korean. Use [EpubReaderLocalization.english] for English,
  /// or provide custom translations via the constructor.
  final EpubReaderLocalization localization;

  @override
  State<EpubReaderWidget> createState() => _EpubReaderWidgetState();
}

class _EpubReaderWidgetState extends State<EpubReaderWidget> {
  final PageController _pageController = PageController();
  final ItemScrollController _scrollItemController = ItemScrollController();
  final ItemPositionsListener _scrollPositions = ItemPositionsListener.create();

  late final SettingsNotifier _settingsNotifier;
  bool? _previousIsPageMode;

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

    // Initialize settings notifier
    final effectiveSettings = widget.initialSettings ?? widget.controller?.initialSettings;
    final storage = widget.settingsStorageKey != null
        ? SettingsStorage(storageKey: widget.settingsStorageKey)
        : null;
    _settingsNotifier = SettingsNotifier(
      initialSettings: effectiveSettings,
      storage: storage,
    );
    _settingsNotifier.addListener(_onSettingsNotifierChanged);
    _previousIsPageMode = _settingsNotifier.settings.isPageMode;

    // Initialize from controller
    final initialProgress = widget.controller?.initialProgress;
    if (initialProgress != null) {
      _lastProgress = initialProgress.clamp(0.0, 1.0);
    }
    _bindController();

    // Load saved settings from storage, then load book content
    _initializeAndLoad();
  }

  void _initializeAndLoad() {
    // Run in parallel: settings load notifies via listener when done,
    // and pagination (triggered by LayoutBuilder) uses whatever settings
    // are current at that point. If settings load finishes after pagination
    // starts, the generation counter handles re-pagination.
    _settingsNotifier.loadFromStorage();
    _loadBookContent();
  }

  void _onSettingsNotifierChanged() {
    final currentIsPageMode = _settingsNotifier.settings.isPageMode;
    if (_previousIsPageMode != currentIsPageMode && _pages.isNotEmpty) {
      _previousIsPageMode = currentIsPageMode;
      if (currentIsPageMode) {
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
    }
    _previousIsPageMode = currentIsPageMode;
    // Sync settings to controller
    widget.controller?.setSettings(_settingsNotifier.settings);
    // Trigger rebuild when settings change
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant EpubReaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) {
      final initialProgress = widget.controller?.initialProgress?.clamp(0.0, 1.0) ?? 0.0;
      _lastProgress = initialProgress;
      setState(() {
        _loadedBook = null;
        _paragraphs = [];
        _pages = [];
        _paginateCacheKey = null;
        _loadError = null;
        _isPaginating = false;
      });
      _loadBookContent();
    }
    if (widget.controller != oldWidget.controller) {
      _unbindController();
      _bindController();
    }
  }

  @override
  void dispose() {
    _unbindController();
    _scrollPositions.itemPositions.removeListener(_handleScrollPositions);
    _settingsNotifier.removeListener(_onSettingsNotifierChanged);
    _settingsNotifier.dispose();
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
        _settingsNotifier.setSettings(settings);
      },
      onAddBookmark: _addBookmark,
      onRemoveBookmark: _removeBookmark,
      onShowSettings: _showSettingsModal,
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (modalContext) => SettingsPanel(
        settingsNotifier: _settingsNotifier,
        onSettingsChanged: _onSettingsChanged,
        localization: widget.localization,
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

          for (final blockElement in blockElements) {
            // 다중 행 테이블을 개별 dialogue로 분할 (globalIndex 증가 전에 체크)
            final tableTag = blockElement.localName?.toLowerCase();
            if (tableTag == 'table') {
              final rows = blockElement.getElementsByTagName('tr');
              if (rows.length > 1) {
                for (final row in rows) {
                  final tds = row.getElementsByTagName('td');
                  if (tds.length >= 2) {
                    paragraphData.add(_ParagraphData.dialogue(
                      index: globalIndex++,
                      chapterIndex: paragraph.chapterIndex,
                      dialogueName: tds[0].text.trim(),
                      dialogueText: tds[1].text.trim(),
                    ));
                  }
                }
                continue;
              }
            }

            final paragraphDataItem = _ParagraphData(
              index: globalIndex++,
              chapterIndex: paragraph.chapterIndex,
              element: blockElement,
            );

            if (paragraphDataItem.type == _ParagraphType.spacing ||
                paragraphDataItem.type == _ParagraphType.richContent ||
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

      final displayError = e is EpubLoadException
          ? e.message
          : widget.localization.unknownError;

      if (mounted) {
        setState(() {
          _loadError = displayError;
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

    final settings = _settingsNotifier.settings;

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

    final totalParagraphs = paragraphs.length;
    final sw = Stopwatch()..start();

    final fontSize = style.fontSize ?? 16.0;
    final lineHeight = fontSize * (style.height ?? 1.5);
    // 문단 사이 간격
    final paragraphSpacing = fontSize * 0.8;
    // 안전 마진 (1줄 높이)
    final safeMaxHeight = maxHeight - lineHeight;

    for (var index = 0; index < totalParagraphs; index++) {
      if (generation != _paginationGeneration) {
        _isPaginating = false;
        return;
      }

      final paragraph = paragraphs[index];

      // 타입별 높이 측정
      double paragraphHeight;
      switch (paragraph.type) {
        case _ParagraphType.spacing:
          paragraphHeight = paragraphSpacing;

        case _ParagraphType.plainText:
          painter.text = TextSpan(text: paragraph.measurementText, style: style);
          painter.layout(maxWidth: maxWidth);
          paragraphHeight = painter.height;

        case _ParagraphType.dialogue:
          final nameColWidth = _parseNameColumnWidth(paragraph, fontSize);
          final dialogueWidth = (maxWidth - nameColWidth).clamp(0.0, maxWidth);
          painter.text = TextSpan(text: paragraph.dialogueText ?? '', style: style);
          painter.layout(maxWidth: dialogueWidth);
          final textH = painter.height;
          painter.text = TextSpan(text: paragraph.dialogueName ?? '', style: style);
          painter.layout(maxWidth: nameColWidth);
          paragraphHeight = max(textH, painter.height);

        case _ParagraphType.richContent:
          final hasImg = paragraph.html.contains('<img') ||
              paragraph.html.contains('<image') ||
              paragraph.html.contains('<svg');
          if (hasImg) {
            // 이미지가 포함된 경우 페이지 전체 높이를 차지하도록 설정
            // (이미지 하나당 한 페이지)
            paragraphHeight = safeMaxHeight + 1;
          } else {
            painter.text =
                TextSpan(text: paragraph.measurementText, style: style);
            painter.layout(maxWidth: maxWidth);
            paragraphHeight = painter.height * 1.2;
          }
      }

      // 문단 사이 간격 추가
      final spacing = currentPage.isEmpty ? 0.0 : paragraphSpacing;
      final nextHeight = currentHeight + paragraphHeight + spacing;

      // 페이지에 들어가는지 확인
      if (nextHeight > safeMaxHeight) {
        if (currentPage.isNotEmpty) {
          // 현재 페이지 완료
          pages.add(_PageContent(List<_ParagraphData>.from(currentPage)));
          currentPage.clear();
          currentHeight = 0;
        }

        // 문단이 너무 길면 문장 단위로 분할
        if (paragraphHeight > safeMaxHeight && !paragraph.isWhitespaceOnly) {
          if (paragraph.type != _ParagraphType.plainText) {
            // dialogue/richContent: 별도 페이지에 배치 (진짜 긴 콘텐츠만)
            pages.add(_PageContent([paragraph]));
            continue;
          }
          final sentences = _splitIntoSentences(paragraph.plainText);
          final sentenceBuffer = <String>[];
          double bufferHeight = 0;

          for (final sentence in sentences) {
            // 문장 높이 측정
            painter.text = TextSpan(text: sentence, style: style);
            painter.layout(maxWidth: maxWidth);
            final sentenceHeight = painter.height;

            if (bufferHeight + sentenceHeight > safeMaxHeight && sentenceBuffer.isNotEmpty) {
              // 현재 버퍼를 페이지로
              final text = sentenceBuffer.join(' ');
              pages.add(_PageContent([
                _ParagraphData.split(
                  index: paragraph.index,
                  chapterIndex: paragraph.chapterIndex,
                  html: '<p>$text</p>',
                  plainText: text,
                ),
              ]));
              sentenceBuffer.clear();
              bufferHeight = 0;
            }

            sentenceBuffer.add(sentence);
            bufferHeight += sentenceHeight;
          }

          // 남은 문장들은 현재 페이지에 추가
          if (sentenceBuffer.isNotEmpty) {
            final text = sentenceBuffer.join(' ');
            painter.text = TextSpan(text: text, style: style);
            painter.layout(maxWidth: maxWidth);
            currentPage.add(_ParagraphData.split(
              index: paragraph.index,
              chapterIndex: paragraph.chapterIndex,
              html: '<p>$text</p>',
              plainText: text,
            ));
            currentHeight = painter.height;
          }
        } else {
          // 문단 통째로 새 페이지에 추가
          currentPage.add(paragraph);
          currentHeight = paragraphHeight;
        }
      } else {
        // 현재 페이지에 문단 추가
        currentPage.add(paragraph);
        currentHeight = nextHeight;
      }

      final progress = totalParagraphs == 0 ? 1.0 : (index + 1) / totalParagraphs;
      if (progress - _paginationProgress >= 0.05 || sw.elapsedMilliseconds > 50) {
        _paginationProgress = progress.clamp(0.0, 1.0);
        widget.onLoadingProgress?.call(0.5 + progress * 0.5);
        if (mounted) setState(() {});
        await Future.delayed(Duration.zero);
        sw.reset();
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(_PageContent(List<_ParagraphData>.from(currentPage)));
    }

    if (!mounted || generation != _paginationGeneration) {
      _isPaginating = false;
      return;
    }

    final totalPages = pages.isEmpty ? 0 : pages.length;
    final targetIndex = totalPages <= 1
        ? 0
        : (_lastProgress * (totalPages - 1)).round().clamp(0, totalPages - 1);

    final isPageMode = _settingsNotifier.settings.isPageMode;

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
              widget.localization.loadFailed,
              style: TextStyle(
                color: settings.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? widget.localization.unknownError,
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
            widget.localization.cannotLoadContent,
            style: TextStyle(color: settings.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.localization.checkFileFormat,
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

    Widget content;
    switch (paragraph.type) {
      case _ParagraphType.spacing:
        final h = _paragraphSpacingForSettings(settings);
        return SizedBox(height: h > 0 ? h : 8.0);

      case _ParagraphType.plainText:
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

      case _ParagraphType.dialogue:
        final nameColWidth = 4.58 * settings.actualFontSize;
        content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: nameColWidth,
              child: Text(paragraph.dialogueName ?? '', style: settings.textStyle),
            ),
            Expanded(
              child: Text(paragraph.dialogueText ?? '', style: settings.textStyle),
            ),
          ],
        );

      case _ParagraphType.richContent:
        if (paragraph.html.isEmpty || paragraph.html.trim().isEmpty) {
          content = const SizedBox.shrink();
        } else {
          try {
            var element = paragraph.cloneElement();
            if (element != null) {
              _stripFontStyles(element);
              // img/image/svg 단독 요소는 div로 감싸서 flutter_html이 올바르게 처리하도록 함
              final elTag = element.localName?.toLowerCase() ?? '';
              if (elTag == 'img' || elTag == 'image' || elTag == 'svg') {
                final wrapper = dom.Element.tag('div');
                wrapper.append(element);
                element = wrapper;
              }
              element.classes.add('paragraph-root');
              content = RepaintBoundary(
                child: ClipRect(
                  child: Html.fromElement(
                    documentElement: element,
                    style: {
                      '*': Style(
                        fontSize: FontSize(settings.actualFontSize),
                        fontFamily: settings.fontFamily,
                        lineHeight: LineHeight(settings.actualLineHeight),
                        color: settings.textColor,
                      ),
                      '.paragraph-root': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                      ),
                    },
                    extensions: _buildHtmlExtensions(_loadedBook),
                  ),
                ),
              );
            } else {
              content = paragraph.plainText.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      paragraph.plainText,
                      style: settings.textStyle,
                      textAlign: TextAlign.start,
                      softWrap: true,
                    );
            }
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
      padding: EdgeInsets.only(bottom: spacing),
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
          final bytes = _resolveImageBytes(rawSrc, images);
          if (bytes == null) return const SizedBox();
          return Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.contain,
          );
        },
      ),
    ];
  }

  /// EPUB 이미지 경로를 다양한 방식으로 매칭하여 바이트 데이터를 반환
  List<int>? _resolveImageBytes(
    String rawSrc,
    Map<String, epubx.EpubByteContentFile> images,
  ) {
    // 직접 매칭
    final direct = images[rawSrc];
    if (direct?.Content != null) return direct!.Content;

    // ../ 제거 후 매칭
    final normalized = rawSrc.replaceAll('../', '').replaceAll('./', '');
    final normed = images[normalized];
    if (normed?.Content != null) return normed!.Content;

    // 파일명만으로 매칭 (경로 구조가 다를 수 있음)
    final fileName = rawSrc.split('/').last;
    for (final entry in images.entries) {
      if (entry.key.endsWith(fileName) || entry.key.split('/').last == fileName) {
        if (entry.value.Content != null) return entry.value.Content;
      }
    }

    // 대소문자 무시 매칭
    final lowerNormalized = normalized.toLowerCase();
    for (final entry in images.entries) {
      if (entry.key.toLowerCase() == lowerNormalized ||
          entry.key.toLowerCase().endsWith(lowerNormalized)) {
        if (entry.value.Content != null) return entry.value.Content;
      }
    }

    return null;
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

    final isPageMode = _settingsNotifier.settings.isPageMode;
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
    final settings = _settingsNotifier.settings;

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
            top: _showTopBar ? kToolbarHeight : 0,
            bottom: (_showBottomBar && widget.bottomBarBuilder != null) ? kToolbarHeight : 0,
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

  double _parseNameColumnWidth(_ParagraphData paragraph, double fontSize) {
    return 4.58 * fontSize;
  }

  void _previousPage() {
    final settings = _settingsNotifier.settings;
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
    final settings = _settingsNotifier.settings;
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
