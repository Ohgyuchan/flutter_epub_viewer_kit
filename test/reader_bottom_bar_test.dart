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
