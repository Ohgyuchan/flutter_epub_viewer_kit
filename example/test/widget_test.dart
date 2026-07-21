import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_epub_viewer_kit_example/main.dart';

void main() {
  testWidgets('home screen renders feature configuration', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('EPUB Viewer Kit Demo'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Localization'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Open Reader'), 200);
    expect(find.text('Open Reader'), findsOneWidget);
  });
}
