import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/epub_source.dart';

/// Exception thrown when EPUB loading fails.
class EpubLoadException implements Exception {
  final String message;
  final Object? originalError;

  const EpubLoadException(this.message, [this.originalError]);

  @override
  String toString() => 'EpubLoadException: $message';
}

/// Utility class to load EPUB data from various sources.
class EpubLoader {
  const EpubLoader._();

  /// Loads EPUB bytes from the given [source].
  ///
  /// Returns a [Uint8List] containing the EPUB file data.
  ///
  /// Throws [EpubLoadException] if loading fails.
  static Future<Uint8List> load(EpubSource source) async {
    switch (source) {
      case EpubSourceFile(:final filePath):
        return _loadFromFile(filePath);
      case EpubSourceUrl(:final url, :final headers):
        return _loadFromUrl(url, headers);
      case EpubSourceBytes(:final bytes):
        return bytes;
      case EpubSourceAsset(:final assetPath):
        return _loadFromAsset(assetPath);
    }
  }

  static Future<Uint8List> _loadFromFile(String filePath) async {
    if (kIsWeb) {
      throw const EpubLoadException(
        'File loading is not supported on web platform. '
        'Use EpubSourceUrl or EpubSourceBytes instead.',
      );
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw EpubLoadException('File not found: $filePath');
      }
      return await file.readAsBytes();
    } catch (e) {
      if (e is EpubLoadException) rethrow;
      throw EpubLoadException('Failed to read file: $filePath', e);
    }
  }

  static Future<Uint8List> _loadFromUrl(
    String url,
    Map<String, String>? headers,
  ) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode != 200) {
        throw EpubLoadException(
          'HTTP request failed with status ${response.statusCode}: $url',
        );
      }

      return response.bodyBytes;
    } catch (e) {
      if (e is EpubLoadException) rethrow;
      throw EpubLoadException('Failed to load from URL: $url', e);
    }
  }

  static Future<Uint8List> _loadFromAsset(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      throw EpubLoadException('Failed to load asset: $assetPath', e);
    }
  }
}
