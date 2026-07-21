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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            color: settings.surfaceColor,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: settings.textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildSection(
                  localization.theme,
                  settings,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorThemes
                        .map((theme) => _buildThemeSwatch(theme, settings))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  localization.font,
                  settings,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFontChip('Noto Sans', settings),
                      _buildFontChip('Nanum Myeongjo', settings),
                      _buildFontChip('Nanum Gothic', settings),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildStepper(
                  localization.fontSize,
                  settings.fontSize,
                  settings,
                  onDecrease: () {
                    settingsNotifier.decreaseFontSize();
                    onSettingsChanged();
                  },
                  onIncrease: () {
                    settingsNotifier.increaseFontSize();
                    onSettingsChanged();
                  },
                ),
                const SizedBox(height: 10),
                _buildStepper(
                  localization.lineSpacing,
                  settings.lineSpacing,
                  settings,
                  onDecrease: () {
                    settingsNotifier.decreaseLineSpacing();
                    onSettingsChanged();
                  },
                  onIncrease: () {
                    settingsNotifier.increaseLineSpacing();
                    onSettingsChanged();
                  },
                ),
                const SizedBox(height: 10),
                _buildStepper(
                  localization.margin,
                  settings.margin,
                  settings,
                  onDecrease: () {
                    settingsNotifier.decreaseMargin();
                    onSettingsChanged();
                  },
                  onIncrease: () {
                    settingsNotifier.increaseMargin();
                    onSettingsChanged();
                  },
                ),
                const SizedBox(height: 20),
                _buildSection(
                  localization.viewMode,
                  settings,
                  _buildModeToggle(settings),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      settingsNotifier.resetToDefault();
                      onSettingsChanged();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: settings.mutedColor,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(
                      localization.resetSettings,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String label, ReaderSettings settings, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: settings.mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        content,
      ],
    );
  }

  Widget _buildThemeSwatch(ColorTheme theme, ReaderSettings settings) {
    final isSelected = settings.backgroundColor == theme.background &&
        settings.textColor == theme.text;

    return GestureDetector(
      onTap: () => settingsNotifier.setColorTheme(theme),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? settings.accentColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.background,
            shape: BoxShape.circle,
            border: Border.all(color: settings.dividerColor),
          ),
          child: Center(
            child: Text(
              localization.themeSampleChar,
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontChip(String fontFamily, ReaderSettings settings) {
    final isSelected = settings.fontFamily == fontFamily;
    final accent = settings.accentColor;

    String label;
    TextStyle style;
    switch (fontFamily) {
      case 'Noto Sans':
        label = localization.fontNotoSans;
        style = GoogleFonts.notoSans(color: settings.textColor);
        break;
      case 'Nanum Myeongjo':
        label = localization.fontSerif;
        style = GoogleFonts.nanumMyeongjo(color: settings.textColor);
        break;
      case 'Nanum Gothic':
        label = localization.fontSansSerif;
        style = GoogleFonts.nanumGothic(color: settings.textColor);
        break;
      default:
        label = fontFamily;
        style = TextStyle(color: settings.textColor, fontFamily: fontFamily);
    }

    return GestureDetector(
      onTap: () => settingsNotifier.setFontFamily(fontFamily),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.10) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accent : settings.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: style.copyWith(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(
    String label,
    int value,
    ReaderSettings settings, {
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: settings.textColor, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: settings.dividerColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: Icons.remove,
                color: settings.textColor,
                onTap: onDecrease,
              ),
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: settings.textColor,
                    ),
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                color: settings.textColor,
                onTap: onIncrease,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle(ReaderSettings settings) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: settings.dividerColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildModeSegment(
            localization.pageMode,
            Icons.auto_stories,
            settings.isPageMode,
            settings,
          ),
          _buildModeSegment(
            localization.scrollMode,
            Icons.view_day,
            !settings.isPageMode,
            settings,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSegment(
    String label,
    IconData icon,
    bool isSelected,
    ReaderSettings settings,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // View mode does not affect layout metrics, so the
          // pagination cache stays valid - no onSettingsChanged.
          if (!isSelected) settingsNotifier.toggleViewMode();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color:
                isSelected ? settings.backgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? settings.textColor : settings.mutedColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      isSelected ? settings.textColor : settings.mutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
