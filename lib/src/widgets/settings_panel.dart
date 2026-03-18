import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/epub_reader_localization.dart';
import '../models/reader_settings.dart';
import '../providers/settings_provider.dart';

class SettingsPanel extends StatelessWidget {
  final SettingsNotifier settingsNotifier;
  final VoidCallback onSettingsChanged;
  final EpubReaderLocalization localization;

  const SettingsPanel({
    super.key,
    required this.settingsNotifier,
    required this.onSettingsChanged,
    this.localization = const EpubReaderLocalization(),
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsNotifier,
      builder: (context, _) {
        final settings = settingsNotifier.settings;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
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
                _buildSection(
                  localization.theme,
                  settings.textColor,
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorThemes.map((theme) {
                        final isSelected =
                            settings.backgroundColor == theme.background &&
                            settings.textColor == theme.text;
                        return GestureDetector(
                          onTap: () {
                            settingsNotifier.setColorTheme(theme);
                          },
                          child: Container(
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
                                localization.themeSampleChar,
                                style: TextStyle(
                                  color: theme.text,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ),
                const SizedBox(height: 16),
                // Font Family Selector
                _buildSection(
                  localization.font,
                  settings.textColor,
                  Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _buildFontButton(
                          'Noto Sans',
                          settings.fontFamily == 'Noto Sans',
                          settings,
                        ),
                        _buildFontButton(
                          'Nanum Myeongjo',
                          settings.fontFamily == 'Nanum Myeongjo',
                          settings,
                        ),
                        _buildFontButton(
                          'Nanum Gothic',
                          settings.fontFamily == 'Nanum Gothic',
                          settings,
                        ),
                      ],
                    ),
                ),
                const SizedBox(height: 16),
                // Font Size Control (1~9)
                _buildControlRow(
                  localization.fontSize,
                  settings.fontSize,
                  () {
                    settingsNotifier.decreaseFontSize();
                    onSettingsChanged();
                  },
                  () {
                    settingsNotifier.increaseFontSize();
                    onSettingsChanged();
                  },
                  settings.textColor,
                ),
                const SizedBox(height: 8),
                // Line Spacing Control (1~5)
                _buildControlRow(
                  localization.lineSpacing,
                  settings.lineSpacing,
                  () {
                    settingsNotifier.decreaseLineSpacing();
                    onSettingsChanged();
                  },
                  () {
                    settingsNotifier.increaseLineSpacing();
                    onSettingsChanged();
                  },
                  settings.textColor,
                ),
                const SizedBox(height: 8),
                // Margin Control (1~5)
                _buildControlRow(
                  localization.margin,
                  settings.margin,
                  () {
                    settingsNotifier.decreaseMargin();
                    onSettingsChanged();
                  },
                  () {
                    settingsNotifier.increaseMargin();
                    onSettingsChanged();
                  },
                  settings.textColor,
                ),
                const SizedBox(height: 16),
                // Page/Scroll Mode Toggle
                _buildSection(
                  localization.viewMode,
                  settings.textColor,
                  SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: Text(
                              localization.pageMode,
                              style: TextStyle(color: settings.textColor),
                            ),
                            icon: Icon(Icons.auto_stories, color: settings.textColor),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(
                              localization.scrollMode,
                              style: TextStyle(color: settings.textColor),
                            ),
                            icon: Icon(Icons.view_day, color: settings.textColor),
                          ),
                        ],
                        selected: {settings.isPageMode},
                        onSelectionChanged: (value) {
                          settingsNotifier.toggleViewMode();
                          onSettingsChanged();
                        },
                        style: ButtonStyle(
                          side: WidgetStatePropertyAll(
                            BorderSide(color: settings.textColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                    ),
                ),
                const SizedBox(height: 16),
                // Reset Button
                TextButton.icon(
                  onPressed: () {
                    settingsNotifier.resetToDefault();
                    onSettingsChanged();
                  },
                  icon: Icon(Icons.refresh, color: settings.textColor),
                  label: Text(
                    localization.resetSettings,
                    style: TextStyle(color: settings.textColor),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String label, Color textColor, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textColor)),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildFontButton(
    String fontFamily,
    bool isSelected,
    ReaderSettings settings,
  ) {
    // Get display text and style for each font
    String displayText;
    TextStyle textStyle;

    switch (fontFamily) {
      case 'Noto Sans':
        displayText = localization.fontNotoSans;
        textStyle = GoogleFonts.notoSans(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
        break;
      case 'Nanum Myeongjo':
        displayText = localization.fontSerif;
        textStyle = GoogleFonts.nanumMyeongjo(
          color: settings.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        );
        break;
      case 'Nanum Gothic':
        displayText = localization.fontSansSerif;
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

    return OutlinedButton(
        onPressed: () {
          settingsNotifier.setFontFamily(fontFamily);
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? settings.textColor.withValues(alpha: 0.2)
              : null,
          foregroundColor: settings.textColor,
          side: BorderSide(color: settings.textColor.withValues(alpha: 0.5)),
        ),
      child: Text(displayText, style: textStyle),
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
