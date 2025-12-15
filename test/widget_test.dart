import 'package:flutter_epub_viewer_kit/flutter_epub_viewer_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubSource', () {
    test('EpubSourceAsset creates correctly', () {
      const source = EpubSourceAsset('assets/book.epub');
      expect(source.assetPath, 'assets/book.epub');
    });

    test('EpubSourceUrl creates correctly', () {
      const source = EpubSourceUrl(
        'https://example.com/book.epub',
        headers: {'Authorization': 'Bearer token'},
      );
      expect(source.url, 'https://example.com/book.epub');
      expect(source.headers, {'Authorization': 'Bearer token'});
    });

    test('EpubSourceFile creates correctly', () {
      const source = EpubSourceFile('/path/to/book.epub');
      expect(source.filePath, '/path/to/book.epub');
    });
  });

  group('ReaderSettings', () {
    test('default settings are correct', () {
      const settings = ReaderSettings();
      expect(settings.fontSize, 2);
      expect(settings.isPageMode, true);
      expect(settings.lineSpacing, 2);
    });

    test('copyWith works correctly', () {
      const settings = ReaderSettings();
      final newSettings = settings.copyWith(fontSize: 4);
      expect(newSettings.fontSize, 4);
      expect(newSettings.isPageMode, true); // unchanged
    });
  });

  group('EpubReaderController', () {
    test('initial state is correct', () {
      final controller = EpubReaderController();
      expect(controller.currentPage, 0);
      expect(controller.totalPages, 0);
      expect(controller.progress, 0.0);
      expect(controller.isLoading, true);
      controller.dispose();
    });
  });
}
