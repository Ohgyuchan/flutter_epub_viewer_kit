import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/reader_settings.dart';
import '../providers/settings_provider.dart';

class SettingsPanel extends ConsumerWidget {
  final VoidCallback onSettingsChanged;

  const SettingsPanel({super.key, required this.onSettingsChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5, // 화면의 50% 높이로 제한
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        color: settings.backgroundColor,
        border: Border(
          top: BorderSide(
            color: settings.textColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color Theme Selector
            Row(
              children: [
                Text('테마', style: TextStyle(color: settings.textColor)),
                const Spacer(),
                ...colorThemes.map((theme) {
                  final isSelected =
                      settings.backgroundColor == theme.background &&
                      settings.textColor == theme.text;
                  return GestureDetector(
                    onTap: () {
                      ref.read(settingsProvider.notifier).setColorTheme(theme);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.blue
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '가',
                          style: TextStyle(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            // Font Family Selector
            Row(
              children: [
                Text('글꼴', style: TextStyle(color: settings.textColor)),
                const Spacer(),
                _buildFontButton(
                  ref,
                  'Noto Sans',
                  settings.fontFamily == 'Noto Sans',
                  settings,
                ),
                _buildFontButton(
                  ref,
                  'Nanum Myeongjo',
                  settings.fontFamily == 'Nanum Myeongjo',
                  settings,
                ),
                _buildFontButton(
                  ref,
                  'Nanum Gothic',
                  settings.fontFamily == 'Nanum Gothic',
                  settings,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Font Size Control (1~9)
            _buildControlRow(
              '글자 크기',
              settings.fontSize,
              () {
                ref.read(settingsProvider.notifier).decreaseFontSize();
                onSettingsChanged();
              },
              () {
                ref.read(settingsProvider.notifier).increaseFontSize();
                onSettingsChanged();
              },
              settings.textColor,
            ),
            const SizedBox(height: 8),
            // Line Spacing Control (1~5)
            _buildControlRow(
              '줄 간격',
              settings.lineSpacing,
              () {
                ref.read(settingsProvider.notifier).decreaseLineSpacing();
                onSettingsChanged();
              },
              () {
                ref.read(settingsProvider.notifier).increaseLineSpacing();
                onSettingsChanged();
              },
              settings.textColor,
            ),
            const SizedBox(height: 8),
            // Margin Control (1~5)
            _buildControlRow(
              '여백',
              settings.margin,
              () {
                ref.read(settingsProvider.notifier).decreaseMargin();
                onSettingsChanged();
              },
              () {
                ref.read(settingsProvider.notifier).increaseMargin();
                onSettingsChanged();
              },
              settings.textColor,
            ),
            const SizedBox(height: 16),
            // Reset Button
            TextButton.icon(
              onPressed: () {
                ref.read(settingsProvider.notifier).resetToDefault();
                onSettingsChanged();
              },
              icon: Icon(Icons.refresh, color: settings.textColor),
              label: Text(
                '보기 설정 초기화',
                style: TextStyle(color: settings.textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontButton(
    WidgetRef ref,
    String fontFamily,
    bool isSelected,
    ReaderSettings settings,
  ) {
    // Get display text and style for each font
    String displayText;
    TextStyle textStyle;

    switch (fontFamily) {
      case 'Noto Sans':
        displayText = 'Sans';
        textStyle = GoogleFonts.notoSans(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
        break;
      case 'Nanum Myeongjo':
        displayText = '명조';
        textStyle = GoogleFonts.nanumMyeongjo(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
        break;
      case 'Nanum Gothic':
        displayText = '고딕';
        textStyle = GoogleFonts.nanumGothic(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
        break;
      default:
        displayText = fontFamily;
        textStyle = TextStyle(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton(
        onPressed: () {
          ref.read(settingsProvider.notifier).setFontFamily(fontFamily);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? settings.textColor.withValues(alpha: 0.2)
              : null,
          foregroundColor: settings.textColor,
          side: BorderSide(color: settings.textColor.withValues(alpha: 0.5)),
        ),
        child: Text(displayText, style: textStyle),
      ),
    );
  }

  Widget _buildControlRow(
    String label,
    int value,
    VoidCallback onDecrease,
    VoidCallback onIncrease,
    Color textColor,
  ) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: textColor)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.remove_circle_outline, color: textColor),
          onPressed: onDecrease,
        ),
        SizedBox(
          width: 40,
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.add_circle_outline, color: textColor),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}
