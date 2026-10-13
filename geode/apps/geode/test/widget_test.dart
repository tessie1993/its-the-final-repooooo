import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geode/app.dart';
import 'package:geode/three_d/controls_3d.dart';

final _captureKey = GlobalKey();

Future<void> _captureScreen(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 20));
  final boundary = _captureKey.currentContext!.findRenderObject()!
      as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  testWidgets('Nature UI opens and navigates to music and preferences', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(key: _captureKey,
      child: const GeodeApp(enableDeviceServices: false)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Find your\nflow.'), findsOneWidget);
    await _captureScreen(tester, 'visuals');
    await tester.tap(find.text('Music'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Music library'), findsOneWidget);
    await _captureScreen(tester, 'music');
    await tester.tap(find.text('Studio'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Let an idea\ntake shape.'), findsOneWidget);
    await _captureScreen(tester, 'studio');
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Make it yours.'), findsOneWidget);
    await _captureScreen(tester, 'settings');
    await tester.tap(find.byType(Switch3D).first);
    await tester.pump();
    expect(tester.widget<Switch3D>(find.byType(Switch3D).first).value, isTrue);
    final state = tester.widget<GeodeShell>(find.byType(GeodeShell)).state;
    expect(state.scene.effectiveReducedMotion, isTrue);
    await tester.tap(find.text('Visuals'));
    await tester.pump();
    await tester.tap(find.byTooltip('Immersive view'));
    await tester.pump();
    expect(state.immersive, isTrue);
    expect(find.text('Music'), findsNothing);
    await tester.tap(find.byTooltip('Exit immersive view'));
    await tester.pump();
    expect(state.immersive, isFalse);
    expect(find.text('Music'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Compact screen keeps each destination usable', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GeodeApp(enableDeviceServices: false));
    await tester.pump(const Duration(milliseconds: 100));
    for (final destination in ['Music', 'Studio', 'Settings', 'Visuals']) {
      await tester.tap(find.text(destination));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '$destination at 320 px');
      expect(find.byTooltip('Immersive view'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
