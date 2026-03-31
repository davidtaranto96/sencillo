import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_app/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanzasApp());
    expect(find.byType(FinanzasApp), findsOneWidget);
  });
}
