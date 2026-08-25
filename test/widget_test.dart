// Basic Flutter smoke test for StockMateApp

import 'package:flutter_test/flutter_test.dart';
import 'package:stockmate_pro/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StockMateApp());

    // Verify the widget tree renders
    expect(find.byType(StockMateApp), findsOneWidget);
  });
}
