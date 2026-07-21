import 'dart:typed_data';

import 'package:flutter/material.dart';
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

    test('EpubSourceBytes equality compares content', () {
      final a = EpubSourceBytes(Uint8List.fromList([1, 2, 3]));
      final b = EpubSourceBytes(Uint8List.fromList([1, 2, 3]));
      final c = EpubSourceBytes(Uint8List.fromList([1, 2, 4]));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(EpubSourceBytes(Uint8List(0)), EpubSourceBytes(Uint8List(0)));
    });
  });

  group('ReaderSettings', () {
    test('default settings are correct', () {
      const settings = ReaderSettings();
      expect(settings.fontSize, 4); // default: 4 (range: 1~9)
      expect(settings.isPageMode, true);
      expect(settings.lineSpacing, 2);
    });

    test('copyWith works correctly', () {
      const settings = ReaderSettings();
      final newSettings = settings.copyWith(fontSize: 4);
      expect(newSettings.fontSize, 4);
      expect(newSettings.isPageMode, true); // unchanged
    });

    test('custom fontFamily is applied to textStyle', () {
      const settings = ReaderSettings(fontFamily: 'MyBundledFont');
      expect(settings.textStyle.fontFamily, 'MyBundledFont');
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

  group('Color tokens', () {
    test('preset accent is returned when settings match a preset', () {
      final white = colorThemes.firstWhere((t) => t.name == 'White');
      final settings = ReaderSettings(
        backgroundColor: white.background,
        textColor: white.text,
      );
      expect(settings.accentColor, const Color(0xFF2E7CE0));

      final sepia = colorThemes.firstWhere((t) => t.name == 'Sepia');
      final sepiaSettings = ReaderSettings(
        backgroundColor: sepia.background,
        textColor: sepia.text,
      );
      expect(sepiaSettings.accentColor, const Color(0xFFB0763B));
    });

    test('accent falls back by background brightness for custom colors', () {
      const lightCustom = ReaderSettings(
        backgroundColor: Color(0xFFF0F0F0),
        textColor: Color(0xFF111111),
      );
      const darkCustom = ReaderSettings(
        backgroundColor: Color(0xFF101010),
        textColor: Color(0xFFEEEEEE),
      );
      expect(lightCustom.accentColor, const Color(0xFF2E7CE0));
      expect(darkCustom.accentColor, const Color(0xFF6AA5E8));
    });

    test('surfaceColor shifts darker on light bg, lighter on dark bg', () {
      const light = ReaderSettings(); // default = Sepia
      expect(
        HSLColor.fromColor(light.surfaceColor).lightness,
        lessThan(HSLColor.fromColor(light.backgroundColor).lightness),
      );

      const dark = ReaderSettings(
        backgroundColor: Color(0xFF222326),
        textColor: Color(0xFFC8C8C8),
      );
      expect(
        HSLColor.fromColor(dark.surfaceColor).lightness,
        greaterThan(HSLColor.fromColor(dark.backgroundColor).lightness),
      );
    });

    test('muted and divider tokens derive from textColor alpha', () {
      const settings = ReaderSettings();
      expect(settings.mutedColor.a, closeTo(0.55, 0.01));
      expect(settings.dividerColor.a, closeTo(0.08, 0.01));
    });

    test('default settings use retuned Sepia preset', () {
      const settings = ReaderSettings();
      expect(settings.backgroundColor, const Color(0xFFFAF4E6));
      expect(settings.textColor, const Color(0xFF433A2F));
    });
  });
}
