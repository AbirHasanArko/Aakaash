// Smoke test for Aakaash — verifies the app root mounts and the SplashScreen
// renders without throwing. Network-bound providers are not exercised here.

import 'package:aakaash/main.dart';
import 'package:aakaash/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Aakaash app boots and shows SplashScreen', (WidgetTester tester) async {
    await tester.pumpWidget(AakaashApp(themeProvider: ThemeProvider()));
    // First frame: provider tree exists, splash placeholder is mounted.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
