import 'package:cycle_doctor/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders multi-patient clinical copilot shell', (tester) async {
    await tester.pumpWidget(const CycleDoctorApp());

    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Patient One'), findsWidgets);
    expect(find.text('Patient Two'), findsOneWidget);
    expect(find.text('Patient Three'), findsOneWidget);
    expect(find.text('What Changed'), findsOneWidget);
    expect(find.text('What Matters'), findsWidgets);
    expect(find.text('Missing'), findsOneWidget);
    expect(find.text('Uncertain'), findsOneWidget);
    expect(find.text('Conflicts'), findsOneWidget);
    expect(find.text('Open Loops'), findsOneWidget);
    expect(find.text('Doctor Review required for writes'), findsOneWidget);
  });

  testWidgets('switches selected patient without leaving clinician shell',
      (tester) async {
    await tester.pumpWidget(const CycleDoctorApp());
    await tester.tap(find.text('Patient Two'));
    await tester.pump();

    expect(find.text('Patient Two'), findsWidgets);
    expect(
      find.textContaining('Structured clinical content for Patient Two'),
      findsOneWidget,
    );
  });
}
