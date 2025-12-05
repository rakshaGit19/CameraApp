// This is a basic Flutter widget test for the camera app.

import 'package:flutter_test/flutter_test.dart';
import 'package:camera_first/main.dart';

void main() {
  testWidgets('Camera app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SimpleCameraApp());

    // Verify that the app launches without errors
    expect(find.byType(SimpleCameraApp), findsOneWidget);
  });
}
