import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Make sure this matches the `name:` in your pubspec.yaml
import 'package:digital_picture_frame_starter/main.dart';

void main() {
  testWidgets('Picture frame UI renders and controls work', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(const DigitalPictureFrameApp());

    // AppBar title shows
    expect(find.text('Digital Picture Frame'), findsOneWidget);

    // Initial state shows Pause button (slideshow running)
    expect(find.text('Pause'), findsOneWidget);

    // Toggle to Resume
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);

    // Tap Next and Previous icons (chevrons exist & are tappable)
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();

    // Little page indicators should exist (one or more)
    // Not asserting a specific count—just that at least one dot is present.
    final dot = find.byType(AnimatedContainer);
    expect(dot, findsWidgets);
  });
}
