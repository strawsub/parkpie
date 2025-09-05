// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('App shows bottom navigation items', (tester) async {
    // Build the app
    await tester.pumpWidget(const ParkPieApp());

    // Verify bottom nav labels are present
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
