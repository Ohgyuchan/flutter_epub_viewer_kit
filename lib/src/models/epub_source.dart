import 'dart:typed_data';

/// Base class for EPUB source types.
/// Use one of the subclasses to specify how to load the EPUB file.
sealed class EpubSource {
  const EpubSource();
}

/// Load EPUB from a local file path.
///
/// Example:
/// ```dart
/// EpubSourceFile('/path/to/book.epub')
/// ```
class EpubSourceFile extends EpubSource {
  /// The absolute file path to the EPUB file.
  final String filePath;

  const EpubSourceFile(this.filePath);
}

/// Load EPUB from a remote URL.
///
/// Example:
/// ```dart
/// EpubSourceUrl(
///   'https://example.com/book.epub',
///   headers: {'Authorization': 'Bearer token'},
/// )
/// ```
class EpubSourceUrl extends EpubSource {
  /// The URL of the EPUB file.
  final String url;

  /// Optional HTTP headers for the request.
  final Map<String, String>? headers;

  const EpubSourceUrl(this.url, {this.headers});
}

/// Load EPUB from raw bytes.
///
/// Example:
/// ```dart
/// final bytes = await File('book.epub').readAsBytes();
/// EpubSourceBytes(bytes)
/// ```
class EpubSourceBytes extends EpubSource {
  /// The raw EPUB file bytes.
  final Uint8List bytes;

  const EpubSourceBytes(this.bytes);
}

/// Load EPUB from Flutter assets.
///
/// Example:
/// ```dart
/// EpubSourceAsset('assets/books/sample.epub')
/// ```
class EpubSourceAsset extends EpubSource {
  /// The asset path (relative to the assets directory).
  final String assetPath;

  const EpubSourceAsset(this.assetPath);
}
