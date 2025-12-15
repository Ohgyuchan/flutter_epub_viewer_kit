import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer_kit/flutter_epub_viewer_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EPUB Reader Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final EpubReaderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController(
      // Resume reading position (0.0 ~ 1.0)
      // You can load this from your own storage (e.g., database)
      initialProgress: 0.0,

      // Initial bookmarks (load from your storage if needed)
      initialBookmarks: [],

      // Called when reading position changes
      onPositionChanged: (position) {
        debugPrint(
          'Position: page ${position.pageIndex + 1}/${position.totalPages}, '
          'progress: ${(position.progress * 100).toStringAsFixed(1)}%',
        );
        // You can save position.progress to your database here
      },

      // Called when settings change (settings are auto-saved to device)
      onSettingsChanged: (settings) {
        debugPrint(
          'Settings changed: fontSize=${settings.fontSize}, '
          'isPageMode=${settings.isPageMode}',
        );
      },

      // Called when bookmark is added
      onBookmarkAdded: (bookmark) {
        debugPrint('Bookmark added: page ${bookmark.pageIndex + 1}');
        setState(() {});
        // Save bookmark to your database here
      },

      // Called when bookmark is removed
      onBookmarkRemoved: (bookmark) {
        debugPrint('Bookmark removed: page ${bookmark.pageIndex + 1}');
        setState(() {});
        // Remove bookmark from your database here
      },
    );
    _controller.addListener(_onControllerChanged);
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
    return EpubReaderWidget(
      source: const EpubSourceAsset('assets/sample.epub'),
      controller: _controller,
      // Settings are automatically saved to device storage with this key
      // Set to null to disable auto-save
      settingsStorageKey: 'epub_reader_settings',
      // Custom top/bottom bars
      showTopBar: true,
      showBottomBar: true,
      topBarBuilder: (context, settings) => _buildTopBar(settings),
      bottomBarBuilder: (context, settings) => _buildBottomBar(settings),
      watermark: _buildWatermark(),
      onPageChanged: (current, total) {
        debugPrint('Page: $current / $total');
      },
      onBookLoaded: (title, author) {
        debugPrint('Book loaded: $title by $author');
      },
      onError: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      },
    );
  }

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
                // Bookmark toggle
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: isBookmarked ? Colors.amber : settings.textColor,
                  ),
                  onPressed: () => _controller.toggleBookmark(),
                ),
                // Bookmarks list
                IconButton(
                  icon: Icon(Icons.list, color: settings.textColor),
                  onPressed: _showBookmarksList,
                ),
                // Settings (uses built-in panel)
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

  Widget _buildBottomBar(ReaderSettings settings) {
    final currentPage = _controller.currentPage + 1;
    final totalPages = _controller.totalPages;
    final progress = _controller.progress;

    return Material(
      color: settings.backgroundColor.withValues(alpha: 0.95),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: settings.textColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                settings.textColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            // Page info and navigation
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
                      icon: Icon(Icons.chevron_left, color: settings.textColor),
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
    );
  }

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
              title: Text('Page ${bookmark.pageIndex + 1}'),
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
}
