import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Color Theme
class ColorTheme {
  final Color background;
  final Color text;
  final String name;

  const ColorTheme({
    required this.background,
    required this.text,
    required this.name,
  });
}

// Available Color Themes
const colorThemes = [
  ColorTheme(background: Color(0xFFFFFBF0), text: Colors.black, name: '따뜻함'),
  ColorTheme(background: Color(0xFFE8E8E8), text: Colors.black87, name: '회색'),
  ColorTheme(background: Colors.black, text: Colors.white, name: '검정'),
  ColorTheme(background: Color(0xFF1E1E1E), text: Color(0xFFE0E0E0), name: '다크'),
  ColorTheme(background: Color(0xFFE8F5E9), text: Color(0xFF1B5E20), name: '녹색'),
  ColorTheme(background: Color(0xFFECEFF1), text: Color(0xFF263238), name: '청회색'),
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
    this.backgroundColor = const Color(0xFFFFFBF0),
    this.textColor = Colors.black,
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
        return baseStyle;
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
      backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFFFFFBF0),
      textColor: Color(json['textColor'] as int? ?? 0xFF000000),
      fontFamily: json['fontFamily'] as String? ?? 'Noto Sans',
      fontSize: json['fontSize'] as int? ?? 4,
      lineSpacing: json['lineSpacing'] as int? ?? 2,
      margin: json['margin'] as int? ?? 1,
      isPageMode: json['isPageMode'] as bool? ?? true,
    );
  }
}
