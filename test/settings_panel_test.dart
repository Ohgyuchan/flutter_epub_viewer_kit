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
    expect(find.text('가'), findsNWidgets(3));

    // Dark 스와치(index 1) 탭
    await tester.tap(find.text('가').at(1));
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

    await tester.scrollUntilVisible(find.text('스크롤'), 50);
    await tester.tap(find.text('스크롤'));
    await tester.pump();
    expect(notifier.settings.isPageMode, false);
  });
}
