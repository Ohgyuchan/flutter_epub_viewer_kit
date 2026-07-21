# 리더 디자인 리프레시 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리디북스/밀리 계열 톤으로 리더 UI 전면 재조율 - 컬러 토큰 확장, 프리셋 재조율, SettingsPanel 재설계, 하단 바(슬라이더) 신규, 로딩/에러/example 톤 통일.

**Architecture:** `ColorTheme`에 옵션 `accent` 필드를 추가하고 `ReaderSettings`에 파생 토큰 getter 4개(`accentColor`/`mutedColor`/`dividerColor`/`surfaceColor`)를 얹는다. 모든 크롬 위젯은 하드코딩 색상 대신 이 토큰을 쓴다. 하단 바는 독립 위젯(`ReaderBottomBar`)으로 만들어 EPUB 로딩 없이 단독 테스트한다.

**Tech Stack:** Flutter, google_fonts, flutter_test (기존 의존성만 - 신규 의존성 없음)

## Global Constraints

- 스펙: `docs/superpowers/specs/2026-07-21-reader-design-refresh-design.md`
- API breaking 금지: 필드/getter 추가만. 기존 생성자 시그니처, JSON 키, `topBarBuilder`/`bottomBarBuilder`/`progressBarColor` 동작 유지
- 신규 의존성 추가 금지
- 커밋 메시지에 Claude 관련 attribution(Co-Authored-By 등) 절대 금지
- 한국어 텍스트(주석 포함)에 em dash(—) 금지, 하이픈(-) 사용
- `any` 타입 사용 금지 (Dart에서는 해당 없음이지만 dynamic 남용 금지로 해석)
- 각 태스크 완료 시 `flutter analyze` 클린 + `flutter test` 전체 통과
- 테스트 실행은 리포지토리 루트(`/Users/terman/dev/flutter_epub_viewer_kit`)에서

---

### Task 1: 컬러 토큰 & 프리셋 재조율

**Files:**
- Modify: `lib/src/models/reader_settings.dart`
- Test: `test/widget_test.dart` (그룹 추가)

**Interfaces:**
- Produces (이후 모든 태스크가 사용):
  - `ColorTheme.accent` (`Color?` - 옵션 필드, named param `accent`)
  - `ReaderSettings.accentColor` (`Color` getter)
  - `ReaderSettings.mutedColor` (`Color` getter - textColor 55% 알파)
  - `ReaderSettings.dividerColor` (`Color` getter - textColor 8% 알파)
  - `ReaderSettings.surfaceColor` (`Color` getter - 배경 대비 밝기 시프트)
  - 재조율된 `colorThemes` 상수 (6개, 순서: White, Sepia, Gray, Paper Green, Dark, Black)
  - `ReaderSettings()` 기본값이 Sepia(#FAF4E6 배경 / #433A2F 글자)로 변경됨

- [ ] **Step 1: 실패하는 테스트 작성**

`test/widget_test.dart` 상단 import에 추가:

```dart
import 'package:flutter/material.dart';
```

파일 끝(`main()`의 마지막 group 뒤, 닫는 `}` 앞)에 그룹 추가:

```dart
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
      const light = ReaderSettings(); // 기본값 = Sepia
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/widget_test.dart`
Expected: FAIL - `accentColor` getter 미정의 컴파일 에러 또는 색상 불일치

- [ ] **Step 3: 구현**

`lib/src/models/reader_settings.dart`에서 `ColorTheme` 클래스와 `colorThemes` 상수를 다음으로 교체:

```dart
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
      background: Color(0xFFFAF4E6),
      text: Color(0xFF433A2F),
      accent: Color(0xFFB0763B),
      name: 'Sepia'),
  ColorTheme(
      background: Color(0xFFECEEF0),
      text: Color(0xFF343A40),
      accent: Color(0xFF2E7CE0),
      name: 'Gray'),
  ColorTheme(
      background: Color(0xFFE5EFE7),
      text: Color(0xFF2E4A38),
      accent: Color(0xFF3E7A55),
      name: 'Paper Green'),
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
```

`ReaderSettings` 기본 생성자의 기본값 변경:

```dart
  const ReaderSettings({
    this.backgroundColor = const Color(0xFFFAF4E6),
    this.textColor = const Color(0xFF433A2F),
    this.fontFamily = 'Noto Sans',
    this.fontSize = 4,
    this.lineSpacing = 2,
    this.margin = 1,
    this.isPageMode = true,
  });
```

`fromJson`의 폴백도 동일 값으로 변경:

```dart
      backgroundColor: Color(json['backgroundColor'] as int? ?? 0xFFFAF4E6),
      textColor: Color(json['textColor'] as int? ?? 0xFF433A2F),
```

`actualMargin` getter 아래(= `textStyle` getter 위)에 토큰 getter 추가:

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test`
Expected: 전체 PASS (기존 테스트 포함)

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze`
Expected: No issues found

```bash
git add lib/src/models/reader_settings.dart test/widget_test.dart
git commit -m "feat: add color tokens and retuned theme presets"
```

---

### Task 2: SettingsPanel 재설계

**Files:**
- Modify: `lib/src/widgets/settings_panel.dart` (전면 교체)
- Test: `test/settings_panel_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 토큰 getter(`accentColor`, `mutedColor`, `dividerColor`, `surfaceColor`)와 재조율된 `colorThemes`
- Produces: `SettingsPanel` 공개 시그니처 불변 (생성자 파라미터 동일). 내부만 재설계

- [ ] **Step 1: 실패하는 테스트 작성**

`test/settings_panel_test.dart` 신규 생성:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer_kit/src/providers/settings_provider.dart';
import 'package:flutter_epub_viewer_kit/src/widgets/settings_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(SettingsNotifier notifier) {
    return MaterialApp(
      home: Scaffold(
        body: SettingsPanel(
          settingsNotifier: notifier,
          onSettingsChanged: () {},
        ),
      ),
    );
  }

  testWidgets('theme swatch tap updates settings', (tester) async {
    final notifier = SettingsNotifier();
    await tester.pumpWidget(wrap(notifier));

    // 6개 테마 스와치가 샘플 문자를 렌더링
    expect(find.text('가'), findsNWidgets(6));

    // Dark 스와치(index 4) 탭
    await tester.tap(find.text('가').at(4));
    await tester.pump();

    expect(notifier.settings.backgroundColor, const Color(0xFF222326));
    expect(notifier.settings.textColor, const Color(0xFFC8C8C8));
  });

  testWidgets('stepper buttons change font size', (tester) async {
    final notifier = SettingsNotifier();
    await tester.pumpWidget(wrap(notifier));

    expect(notifier.settings.fontSize, 4);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(notifier.settings.fontSize, 5);

    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump();
    expect(notifier.settings.fontSize, 4);
  });

  testWidgets('mode segment tap toggles view mode', (tester) async {
    final notifier = SettingsNotifier();
    await tester.pumpWidget(wrap(notifier));

    expect(notifier.settings.isPageMode, true);

    await tester.tap(find.text('스크롤'));
    await tester.pump();
    expect(notifier.settings.isPageMode, false);
  });
}
```

참고: 스와치 탭 테스트는 신규 프리셋 색상(Task 1)에 의존한다. `find.text('스크롤')`은
기본 로컬라이제이션(`scrollMode = '스크롤'`) 기준. 테스트 뷰포트(800x600)에서 패널
maxHeight는 300인데, 스크롤 세그먼트가 화면 밖이면
`await tester.scrollUntilVisible(find.text('스크롤'), 50)` 을 탭 전에 추가한다.

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/settings_panel_test.dart`
Expected: FAIL - 현재 구현은 스와치가 40px + `Icons.add` 아이콘 없음(`Icons.add_circle_outline` 사용)이라 `find.byIcon(Icons.add)`가 매치 안 됨. 스와치 테스트는 신규 프리셋 색상이라 불일치

- [ ] **Step 3: 구현 - settings_panel.dart 전면 교체**

`lib/src/widgets/settings_panel.dart` 전체를 다음으로 교체:

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test`
Expected: 전체 PASS. google_fonts가 테스트 환경에서 폰트를 네트워크 로드하지 못해
콘솔에 로그를 남길 수 있으나 실패로 이어지지 않음 (내부에서 catch됨)

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze`
Expected: No issues found

```bash
git add lib/src/widgets/settings_panel.dart test/settings_panel_test.dart
git commit -m "feat: redesign settings panel with token-based styling"
```

---

### Task 3: ReaderBottomBar 신규 위젯

**Files:**
- Create: `lib/src/widgets/reader_bottom_bar.dart`
- Test: `test/reader_bottom_bar_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 토큰 getter
- Produces: `ReaderBottomBar` 위젯. 시그니처:
  ```dart
  ReaderBottomBar({
    Key? key,
    required ReaderSettings settings,
    required int pageIndex,     // 0-based 현재 페이지
    required int totalPages,
    required ValueChanged<int> onPageSelected, // 0-based 대상 페이지
  })
  ```
  Task 4가 `_buildBottomOverlay`에서 이 위젯을 사용한다.
  공개 export(`lib/flutter_epub_viewer_kit.dart`)에는 추가하지 않는다 -
  커스텀은 기존 `bottomBarBuilder`로 하면 되므로 (YAGNI)

- [ ] **Step 1: 실패하는 테스트 작성**

`test/reader_bottom_bar_test.dart` 신규 생성:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer_kit/src/models/reader_settings.dart';
import 'package:flutter_epub_viewer_kit/src/widgets/reader_bottom_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('slider drag end selects target page', (tester) async {
    int? selected;
    await tester.pumpWidget(wrap(
      ReaderBottomBar(
        settings: const ReaderSettings(),
        pageIndex: 0,
        totalPages: 100,
        onPageSelected: (page) => selected = page,
      ),
    ));

    expect(find.text('1 / 100'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected, greaterThan(0));
  });

  testWidgets('page display follows pageIndex', (tester) async {
    await tester.pumpWidget(wrap(
      ReaderBottomBar(
        settings: const ReaderSettings(),
        pageIndex: 11,
        totalPages: 340,
        onPageSelected: (_) {},
      ),
    ));

    expect(find.text('12 / 340'), findsOneWidget);
  });

  testWidgets('single page book hides slider', (tester) async {
    await tester.pumpWidget(wrap(
      ReaderBottomBar(
        settings: const ReaderSettings(),
        pageIndex: 0,
        totalPages: 1,
        onPageSelected: (_) {},
      ),
    ));

    expect(find.byType(Slider), findsNothing);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/reader_bottom_bar_test.dart`
Expected: FAIL - `reader_bottom_bar.dart` 파일 없음 (컴파일 에러)

- [ ] **Step 3: 구현**

`lib/src/widgets/reader_bottom_bar.dart` 신규 생성:

```dart
import 'package:flutter/material.dart';

import '../models/reader_settings.dart';

/// Default bottom overlay: page slider + current page display.
///
/// Dragging updates only the local display; navigation fires once on
/// drag end via [onPageSelected].
class ReaderBottomBar extends StatefulWidget {
  final ReaderSettings settings;
  final int pageIndex;
  final int totalPages;
  final ValueChanged<int> onPageSelected;

  const ReaderBottomBar({
    super.key,
    required this.settings,
    required this.pageIndex,
    required this.totalPages,
    required this.onPageSelected,
  });

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final maxPage = (widget.totalPages - 1).toDouble();
    final value =
        (_dragValue ?? widget.pageIndex.toDouble()).clamp(0.0, maxPage);
    final displayPage = value.round() + 1;

    return Material(
      color: settings.surfaceColor.withValues(alpha: 0.96),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: settings.dividerColor)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.totalPages > 1)
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: settings.accentColor,
                  inactiveTrackColor: settings.dividerColor,
                  thumbColor: settings.accentColor,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: value,
                  max: maxPage,
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    widget.onPageSelected(v.round());
                    setState(() => _dragValue = null);
                  },
                ),
              ),
            Text(
              '$displayPage / ${widget.totalPages}',
              style: TextStyle(color: settings.mutedColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test`
Expected: 전체 PASS

- [ ] **Step 5: analyze + 커밋**

Run: `flutter analyze`
Expected: No issues found

```bash
git add lib/src/widgets/reader_bottom_bar.dart test/reader_bottom_bar_test.dart
git commit -m "feat: add reader bottom bar with page slider"
```

---

### Task 4: 오버레이 / 로딩 / 에러 토큰 적용

**Files:**
- Modify: `lib/src/widgets/epub_reader_widget.dart`
  - `_buildTopOverlay` (~line 1931)
  - `_buildBottomOverlay` (~line 1957)
  - 진행 바 기본색 (~line 1895)
  - 로딩 뷰 4곳 + 페이지네이션 진행 뷰 2곳 (~lines 1266, 1278, 1299, 1470, 1482, 1503)
  - `_buildErrorView` (~line 1396), `_buildEmptyView` (~line 1428)

**Interfaces:**
- Consumes: Task 1 토큰 getter, Task 3 `ReaderBottomBar`
- Produces: 없음 (내부 변경). `topBarBuilder`/`bottomBarBuilder`/`progressBarColor`
  오버라이드 동작은 기존과 동일하게 유지

이 태스크는 순수 스타일 변경이라 신규 테스트 없음 - 기존 테스트 통과 + analyze로 검증.

- [ ] **Step 1: import 추가**

`epub_reader_widget.dart` 상단 import 블록의 `settings_panel.dart` import 옆에 추가:

```dart
import 'reader_bottom_bar.dart';
```

- [ ] **Step 2: 상단 바 / 하단 바 교체**

`_buildTopOverlay`를 다음으로 교체:

```dart
  Widget _buildTopOverlay(ReaderSettings settings) {
    return Material(
      color: settings.surfaceColor.withValues(alpha: 0.96),
      child: Container(
        height: kToolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: settings.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.title ?? _loadedBook?.Title ?? 'EPUB Reader',
                style: TextStyle(
                  color: settings.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

`_buildBottomOverlay`를 다음으로 교체:

```dart
  Widget _buildBottomOverlay(ReaderSettings settings) {
    if (_pages.isEmpty) return const SizedBox.shrink();
    return ReaderBottomBar(
      settings: settings,
      pageIndex: _currentPageIndex,
      totalPages: _pages.length,
      onPageSelected: _goToPage,
    );
  }
```

참고: `_goToPage`는 내부에서 `_effectiveMaxPages`로 클램프하고 페이지/스크롤 모드를
모두 처리하므로 하단 바는 페이지 인덱스만 넘기면 된다.

- [ ] **Step 3: 진행 바 기본색 변경**

`build()` 안의 `LinearProgressIndicator` (~line 1895) `valueColor`를:

```dart
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.progressBarColor ??
                        settings.accentColor.withValues(alpha: 0.4),
                  ),
```

- [ ] **Step 4: 로딩/페이지네이션 뷰 공통화**

클래스 내부(`_buildErrorView` 위)에 헬퍼 추가:

```dart
  Widget _buildLoadingView(ReaderSettings settings, {bool showProgress = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: settings.accentColor,
            strokeWidth: 2.5,
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            Text(
              '${(_paginationProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: settings.mutedColor, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
```

`_buildPagedReader`와 `_buildScrollReader` 양쪽에서:
- `return const Center(child: CircularProgressIndicator());` 4곳 전부 →
  `return _buildLoadingView(settings);`
- 페이지네이션 진행 블록 2곳 (`Center(child: Column(...CircularProgressIndicator...%...)))` →
  `return _buildLoadingView(settings, showProgress: true);`

- [ ] **Step 5: 에러/빈 콘텐츠 뷰 토큰화**

`_buildErrorView`에서:

```dart
            Icon(Icons.error_outline, size: 44, color: settings.mutedColor),
            const SizedBox(height: 16),
            Text(
              widget.localization.loadFailed,
              style: TextStyle(
                color: settings.textColor,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? widget.localization.unknownError,
              style: TextStyle(
                color: settings.mutedColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
```

(`const Icon(..., color: Colors.red)` 을 settings 기반 `Icon`으로 바꾸므로 `const` 제거)

`_buildEmptyView`에서:

```dart
          Icon(Icons.error_outline, size: 44, color: settings.mutedColor),
          const SizedBox(height: 16),
          Text(
            widget.localization.cannotLoadContent,
            style: TextStyle(color: settings.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            widget.localization.checkFileFormat,
            style: TextStyle(color: settings.mutedColor, fontSize: 12),
          ),
```

- [ ] **Step 6: 테스트 + analyze + 커밋**

Run: `flutter test && flutter analyze`
Expected: 전체 PASS / No issues found

```bash
git add lib/src/widgets/epub_reader_widget.dart
git commit -m "feat: apply design tokens to reader overlays and status views"
```

---

### Task 5: example 앱 톤 통일

**Files:**
- Modify: `example/lib/main.dart`
  - `ThemeData` 시드 (~line 17)
  - `_SectionCard` (~line 390)
  - `_buildTopBar` (~line 609)
  - `_buildBottomBar` (~line 666)

**Interfaces:**
- Consumes: Task 1 토큰 getter (`accentColor`, `mutedColor`, `dividerColor`, `surfaceColor`)
- Produces: 없음 (데모 전용)

example은 위젯 테스트 대상이 아니므로 analyze + 수동 확인으로 검증.

- [ ] **Step 1: 시드 컬러 + 카드 톤**

line ~17의 테마를:

```dart
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7CE0)),
      ),
```

`_SectionCard.build`의 `Card`를:

```dart
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
```

- [ ] **Step 2: 커스텀 상단 바 토큰화**

`_buildTopBar`에서:
- `Material(color: settings.backgroundColor.withValues(alpha: 0.95), elevation: 4, ...)` →
  `Material(color: settings.surfaceColor.withValues(alpha: 0.96), ...)` (elevation 제거)
- `Container`에 하단 헤어라인 추가:

```dart
        child: Container(
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: settings.dividerColor)),
          ),
```

- 북마크 아이콘의 `Colors.amber` → `settings.accentColor`:

```dart
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color:
                      isBookmarked ? settings.accentColor : settings.textColor,
                ),
                onPressed: () => _controller.toggleBookmark(),
              ),
```

- [ ] **Step 3: 커스텀 하단 바 토큰화**

`_buildBottomBar`에서:
- `Material(color: ..., elevation: 4)` → `Material(color: settings.surfaceColor.withValues(alpha: 0.96))` (elevation 제거)
- `Padding` 을 상단 헤어라인 있는 `Container`로:

```dart
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: settings.dividerColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
```

- `LinearProgressIndicator` 색상:

```dart
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: settings.dividerColor,
                valueColor:
                    AlwaysStoppedAnimation<Color>(settings.accentColor),
              ),
```

- 진행 텍스트 색상: `settings.textColor.withValues(alpha: 0.7)` → `settings.mutedColor`

- [ ] **Step 4: analyze + 수동 확인 + 커밋**

Run: `flutter analyze`
Expected: No issues found (example 포함)

수동 확인 (가능한 환경이면): `cd example && flutter run` 후
6개 테마 각각에서 설정 패널 / 상단·하단 바 / 진행 바 대비 확인.
헤드리스 환경이면 이 단계는 사용자 확인 요청으로 대체.

```bash
git add example/lib/main.dart
git commit -m "chore: align example app with new design tokens"
```

---

## 최종 검증

- [ ] `flutter analyze` - No issues found
- [ ] `flutter test` - 전체 PASS
- [ ] 스펙 대비 커버리지: 토큰/프리셋(Task 1), 패널(Task 2), 하단 바(Task 3),
      상단 바·진행 바·로딩·에러(Task 4), example(Task 5) - 스펙 5개 섹션 전부 매핑
- [ ] 하위호환: `git diff f247bf7 -- lib/` 에서 공개 시그니처 제거/변경 없음 확인
      (추가만 있어야 함)
