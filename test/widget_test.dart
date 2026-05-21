import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_scanner/main.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartReceiptScannerApp());
    expect(find.text('ReceiptSync'), findsOneWidget);
  });
}
