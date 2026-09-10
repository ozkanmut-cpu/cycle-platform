import 'package:cycle_partner/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Partner shell is read-only and exposes secure sharing controls',
      (
    tester,
  ) async {
    await tester.pumpWidget(const CyclePartnerApp());

    expect(find.text('Cycle Partner'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.text('QR pairing'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('NOTIFY'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Encrypted transport'), findsOneWidget);
    expect(find.text('Private notifications'), findsOneWidget);
    expect(find.textContaining('Edit'), findsNothing);
  });
}
