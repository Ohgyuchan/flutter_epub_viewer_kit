import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Color Theme
class ColorTheme {
  final Color background;
  final Color text;

  /// Accent color for chrome (selection rings, sliders, spinners).
  /// When null, a brightness-based fallback is derived.
  final Color? accent;
  final String name;

  const ColorTheme({
    required this.background,
    required this.text,
    this.accent,
    required this.name,
  });
}

// Available Color Themes
const colorThemes = [
  ColorTheme(
      background: Color(0xFFFFFFFF),
      text: Color(0xFF212529),
      accent: Color(0xFF2E7CE0),
      name: 'White'),
  ColorTheme(
      background: Color(0xFF222326),
      text: Color(0xFFC8C8C8),
      accent: Color(0xFF6AA5E8),
      name: 'Dark'),
  ColorTheme(
      background: Color(0xFF000000),
      text: Color(0xFFB8B8B8),
      accent: Color(0xFF6AA5E8),
      name: 'Black'),
];

// Reader Settings Model
class ReaderSettings {
  final Color backgroundColor;
  final Color textColor;
  final String fontFamily;
  final int fontSize; // 1~9 (default: 4)
  final int lineSpacing; // 1~5 (default: 2)
  final int margin; // 1~5 (default: 1)
  final bool isPageMode; // true = 페이지, false = 스크롤

  const ReaderSettings({
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF212529),
    this.fontFamily = 'Noto Sans',
    this.fontSize = 4,
    this.lineSpacing = 2,
    this.margin = 1,
    this.isPageMode = true,
  });

  // 실제 폰트 크기 (fontSize 1~9 -> 12~28px)
  double get actualFontSize => 10.0 + (fontSize * 2);

  // 실제 줄 간격 (lineSpacing 1~5 -> 1.2~2.0)
  double get actualLineHeight => 1.0 + (lineSpacing * 0.2);

  // 실제 문단 간격
  double get actualParagraphSpacing => actualFontSize * 0.8;

  // 실제 여백 (margin 1~5 -> 8~40px)
  EdgeInsets get actualMargin {
    final marginValue = 8.0 + ((margin - 1) * 8);
    return EdgeInsets.all(marginValue);
  }

  static const Color _lightAccentFallback = Color(0xFF2E7CE0);
  static const Color _darkAccentFallback = Color(0xFF6AA5E8);

  bool get _isDarkBackground =>
      ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;

  /// Accent for chrome. Matches a preset by background+text, otherwise
  /// falls back by background brightness.
  Color get accentColor {
    for (final theme in colorThemes) {
      if (theme.background == backgroundColor && theme.text == textColor) {
        final accent = theme.accent;
        if (accent != null) return accent;
      }
    }
    return _isDarkBackground ? _darkAccentFallback : _lightAccentFallback;
  }

  /// Secondary text/icon color.
  Color get mutedColor => textColor.withValues(alpha: 0.55);

  /// Hairline borders and inactive tracks.
  Color get dividerColor => textColor.withValues(alpha: 0.08);

  /// Chrome surface (panels, bars) - background shifted slightly.
  Color get surfaceColor {
    final hsl = HSLColor.fromColor(backgroundColor);
    final shift = _isDarkBackground ? 0.04 : -0.03;
    return hsl.withLightness((hsl.lightness + shift).clamp(0.0, 1.0)).toColor();
  }

  // Google Fonts를 사용한 TextStyle
  TextStyle get textStyle {
    final baseStyle = TextStyle(
      fontSize: actualFontSize,
      height: actualLineHeight,
      color: textColor,
    );

    switch (fontFamily) {
      case 'Noto Sans':
        return GoogleFonts.notoSans(textStyle: baseStyle);
      case 'Nanum Myeongjo':
        return GoogleFonts.nanumMyeongjo(textStyle: baseStyle);
      case 'Nanum Gothic':
        return GoogleFonts.nanumGothic(textStyle: baseStyle);
      default:
        // Unknown names are passed through as-is so apps can use fonts
        // bundled in their own pubspec.
        return baseStyle.copyWith(fontFamily: fontFamily);
    }
  }

  ReaderSettings copyWith({
    Color? backgroundColor,
    Color? textColor,
    String? fontFamily,
    int? fontSize,
    int? lineSpacing,
    int? margin,
    bool? isPageMode,
  }) {
    return ReaderSettings(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      margin: margin ?? this.margin,
      isPageMode: isPageMode ?? this.isPageMode,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'backgroundColor': backgroundColor.toARGB32(),
      'textColor': textColor.toARGB32(),
      'fontFamily': fontFamily,
      'fontSize': fontSize,
      'lineSpacing': lineSpacing,
      'margin': margin,
      'isPageMode': isPageMode,
    };
  }

  /// Create from JSON
  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFFFFFFFF),
      textColor: Color(json['textColor'] as int? ?? 0xFF212529),
      fontFamily: json['fontFamily'] as String? ?? 'Noto Sans',
      fontSize: json['fontSize'] as int? ?? 4,
      lineSpacing: json['lineSpacing'] as int? ?? 2,
      margin: json['margin'] as int? ?? 1,
      isPageMode: json['isPageMode'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReaderSettings &&
        other.backgroundColor == backgroundColor &&
        other.textColor == textColor &&
        other.fontFamily == fontFamily &&
        other.fontSize == fontSize &&
        other.lineSpacing == lineSpacing &&
        other.margin == margin &&
        other.isPageMode == isPageMode;
  }

  @override
  int get hashCode => Object.hash(
        backgroundColor,
        textColor,
        fontFamily,
        fontSize,
        lineSpacing,
        margin,
        isPageMode,
      );
}
