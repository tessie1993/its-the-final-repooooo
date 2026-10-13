import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geode/app.dart';

void main() {
  testWidgets('Nature UI opens and navigates to its collection and preferences', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GeodeApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Find your\nflow.'), findsOneWidget);
    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Your collection'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not a saved look');
    await tester.pump();
    expect(find.text('No looks found'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Make it yours'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
