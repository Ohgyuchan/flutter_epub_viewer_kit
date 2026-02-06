import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer_kit/flutter_epub_viewer_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Viewer Kit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// --- Source type enum ---

enum SourceType { asset, url, bytes }

// --- Configuration data class ---

class ReaderConfig {
  final SourceType sourceType;
  final bool showWatermark;
  final bool useCustomBars;
  final bool enablePersistence;
  final bool enableMaxPages;
  final int maxPages;
  final bool isPageMode;
  final double resumeProgress;
  final bool loadInitialBookmarks;

  const ReaderConfig({
    required this.sourceType,
    required this.showWatermark,
    required this.useCustomBars,
    required this.enablePersistence,
    required this.enableMaxPages,
    required this.maxPages,
    required this.isPageMode,
    required this.resumeProgress,
    required this.loadInitialBookmarks,
  });
}

// ============================================================
// Screen 1: Feature Configuration Home
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SourceType _sourceType = SourceType.asset;
  bool _showWatermark = false;
  bool _useCustomBars = true;
  bool _enablePersistence = true;
  bool _enableMaxPages = false;
  final TextEditingController _maxPagesController =
      TextEditingController(text: '5');
  bool _isPageMode = true;
  double _resumeProgress = 0.0;
  bool _loadInitialBookmarks = false;

  @override
  void dispose() {
    _maxPagesController.dispose();
    super.dispose();
  }

  void _openReader() {
    final maxPages =
        int.tryParse(_maxPagesController.text) ?? 5;

    final config = ReaderConfig(
      sourceType: _sourceType,
      showWatermark: _showWatermark,
      useCustomBars: _useCustomBars,
      enablePersistence: _enablePersistence,
      enableMaxPages: _enableMaxPages,
      maxPages: maxPages.clamp(1, 9999),
      isPageMode: _isPageMode,
      resumeProgress: _resumeProgress,
      loadInitialBookmarks: _loadInitialBookmarks,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderPage(config: config)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EPUB Viewer Kit Demo'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Source ---
          _SectionCard(
            title: 'Source',
            child: SegmentedButton<SourceType>(
              segments: const [
                ButtonSegment(value: SourceType.asset, label: Text('Asset')),
                ButtonSegment(value: SourceType.url, label: Text('URL')),
                ButtonSegment(value: SourceType.bytes, label: Text('Bytes')),
              ],
              selected: {_sourceType},
              onSelectionChanged: (v) =>
                  setState(() => _sourceType = v.first),
            ),
          ),

          // --- Reading Mode ---
          _SectionCard(
            title: 'Reading Mode',
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Page')),
                ButtonSegment(value: false, label: Text('Scroll')),
              ],
              selected: {_isPageMode},
              onSelectionChanged: (v) =>
                  setState(() => _isPageMode = v.first),
            ),
          ),

          // --- Watermark ---
          _SectionCard(
            title: 'Watermark',
            child: SwitchListTile(
              title: const Text('Show watermark overlay'),
              value: _showWatermark,
              onChanged: (v) => setState(() => _showWatermark = v),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // --- Custom Bars ---
          _SectionCard(
            title: 'Custom Top/Bottom Bars',
            child: SwitchListTile(
              title: const Text('Use custom bars'),
              subtitle: const Text(
                'Off = use default built-in bars',
              ),
              value: _useCustomBars,
              onChanged: (v) => setState(() => _useCustomBars = v),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // --- Settings Persistence ---
          _SectionCard(
            title: 'Settings Persistence',
            child: SwitchListTile(
              title: const Text('Persist settings to device'),
              subtitle: const Text(
                'Uses SharedPreferences when enabled',
              ),
              value: _enablePersistence,
              onChanged: (v) => setState(() => _enablePersistence = v),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // --- Max Readable Pages ---
          _SectionCard(
            title: 'Max Readable Pages',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Limit readable pages'),
                  subtitle: const Text(
                    'Simulates preview/trial mode',
                  ),
                  value: _enableMaxPages,
                  onChanged: (v) => setState(() => _enableMaxPages = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_enableMaxPages)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextField(
                      controller: _maxPagesController,
                      decoration: const InputDecoration(
                        labelText: 'Max pages',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
              ],
            ),
          ),

          // --- Resume Position ---
          _SectionCard(
            title: 'Resume Position',
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start reading from'),
                    Text(
                      '${(_resumeProgress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                Slider(
                  value: _resumeProgress,
                  onChanged: (v) => setState(() => _resumeProgress = v),
                  divisions: 20,
                  label: '${(_resumeProgress * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),

          // --- Initial Bookmarks ---
          _SectionCard(
            title: 'Initial Bookmarks',
            child: SwitchListTile(
              title: const Text('Pre-load sample bookmarks'),
              subtitle: const Text(
                'Adds bookmarks at pages 1, 3, 5',
              ),
              value: _loadInitialBookmarks,
              onChanged: (v) => setState(() => _loadInitialBookmarks = v),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: 24),

          // --- Open Reader ---
          FilledButton.icon(
            onPressed: _openReader,
            icon: const Icon(Icons.menu_book),
            label: const Text('Open Reader'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// --- Section card helper ---

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Screen 2: EPUB Reader
// ============================================================

class ReaderPage extends StatefulWidget {
  final ReaderConfig config;

  const ReaderPage({super.key, required this.config});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final EpubReaderController _controller;
  EpubSource? _source;
  bool _loadingSource = false;

  @override
  void initState() {
    super.initState();

    final initialBookmarks = widget.config.loadInitialBookmarks
        ? [
            Bookmark(
              pageIndex: 0,
              progress: 0.0,
              title: 'Sample Bookmark 1',
              excerpt: 'Beginning of the book',
              createdAt: DateTime.now(),
            ),
            Bookmark(
              pageIndex: 2,
              progress: 0.0,
              title: 'Sample Bookmark 2',
              excerpt: 'A few pages in',
              createdAt: DateTime.now(),
            ),
            Bookmark(
              pageIndex: 4,
              progress: 0.0,
              title: 'Sample Bookmark 3',
              excerpt: 'Further along',
              createdAt: DateTime.now(),
            ),
          ]
        : <Bookmark>[];

    _controller = EpubReaderController(
      initialProgress: widget.config.resumeProgress,
      initialBookmarks: initialBookmarks,
      onPositionChanged: (position) {
        debugPrint(
          'Position: page ${position.pageIndex + 1}/${position.totalPages}, '
          'progress: ${(position.progress * 100).toStringAsFixed(1)}%',
        );
      },
      onSettingsChanged: (settings) {
        debugPrint(
          'Settings changed: fontSize=${settings.fontSize}, '
          'isPageMode=${settings.isPageMode}',
        );
      },
      onBookmarkAdded: (bookmark) {
        debugPrint('Bookmark added: page ${bookmark.pageIndex + 1}');
        setState(() {});
      },
      onBookmarkRemoved: (bookmark) {
        debugPrint('Bookmark removed: page ${bookmark.pageIndex + 1}');
        setState(() {});
      },
    );
    _controller.addListener(_onControllerChanged);

    _prepareSource();
  }

  Future<void> _prepareSource() async {
    switch (widget.config.sourceType) {
      case SourceType.asset:
        setState(() {
          _source = const EpubSourceAsset('assets/example.epub');
        });
      case SourceType.url:
        setState(() {
          _source = const EpubSourceUrl(
            'https://www.gutenberg.org/ebooks/11.epub.images',
          );
        });
      case SourceType.bytes:
        setState(() => _loadingSource = true);
        try {
          final data = await rootBundle.load('assets/example.epub');
          if (mounted) {
            setState(() {
              _source = EpubSourceBytes(data.buffer.asUint8List());
              _loadingSource = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _loadingSource = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load bytes: $e')),
            );
          }
        }
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSource || _source == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final config = widget.config;

    return EpubReaderWidget(
      source: _source!,
      controller: _controller,
      settingsStorageKey:
          config.enablePersistence ? 'epub_reader_settings' : null,
      initialSettings: ReaderSettings(isPageMode: config.isPageMode),
      showTopBar: true,
      showBottomBar: true,
      topBarBuilder: config.useCustomBars
          ? (context, settings) => _buildTopBar(settings)
          : null,
      bottomBarBuilder: config.useCustomBars
          ? (context, settings) => _buildBottomBar(settings)
          : null,
      watermark: config.showWatermark ? _buildWatermark() : null,
      maxReadablePages: config.enableMaxPages ? config.maxPages : null,
      onMaxPageReached: (maxPage, totalPages) {
        _showMaxPageDialog(maxPage, totalPages);
      },
      onPageChanged: (current, total) {
        debugPrint('Page: $current / $total');
      },
      onBookLoaded: (title, author) {
        debugPrint('Book loaded: $title by $author');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded: ${title ?? "Unknown"} by ${author ?? "Unknown"}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      onError: (error) {
        debugPrint('Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        }
      },
    );
  }

  // --- Custom top bar ---

  PreferredSizeWidget _buildTopBar(ReaderSettings settings) {
    final isBookmarked = _controller.isCurrentPageBookmarked;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Material(
        color: settings.backgroundColor.withValues(alpha: 0.95),
        elevation: 4,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: kToolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: settings.textColor),
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Text(
                    'EPUB Reader',
                    style: TextStyle(
                      color: settings.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.amber : settings.textColor,
                  ),
                  onPressed: () => _controller.toggleBookmark(),
                ),
                IconButton(
                  icon: Icon(Icons.list, color: settings.textColor),
                  onPressed: _showBookmarksList,
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: settings.textColor),
                  onPressed: () => _controller.showSettings(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Custom bottom bar ---

  Widget _buildBottomBar(ReaderSettings settings) {
    final currentPage = _controller.currentPage + 1;
    final totalPages = _controller.totalPages;
    final progress = _controller.progress;

    return Material(
      color: settings.backgroundColor.withValues(alpha: 0.95),
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                backgroundColor: settings.textColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  settings.textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$currentPage / $totalPages (${(progress * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: settings.textColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left,
                          color: settings.textColor,
                        ),
                        onPressed: () => _controller.previousPage(),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right,
                          color: settings.textColor,
                        ),
                        onPressed: () => _controller.nextPage(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bookmarks list ---

  void _showBookmarksList() {
    final bookmarks = _controller.bookmarks;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (bookmarks.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No bookmarks yet')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = bookmarks[index];
            return ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text(
                bookmark.title ?? 'Page ${bookmark.pageIndex + 1}',
              ),
              subtitle: bookmark.excerpt != null
                  ? Text(
                      bookmark.excerpt!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _controller.removeBookmark(bookmark);
                  Navigator.pop(context);
                  _showBookmarksList();
                },
              ),
              onTap: () {
                _controller.goToBookmark(bookmark);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  // --- Watermark ---

  Widget _buildWatermark() {
    return Opacity(
      opacity: 0.08,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 160,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            'Flutter EPUB Viewer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // --- Max page reached dialog ---

  void _showMaxPageDialog(int maxPage, int totalPages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Limit Reached'),
        content: Text(
          'You have reached the preview limit of $maxPage pages '
          '(out of $totalPages total). '
          'Purchase the full book to continue reading.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
