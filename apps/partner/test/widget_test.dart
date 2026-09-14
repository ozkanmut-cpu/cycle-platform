import 'package:cycle_partner/main.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Partner Home exposes four privacy-safe relationship tabs',
      (tester) async {
    await tester.pumpWidget(const CyclePartnerApp());

    expect(find.text('Cycle Partner'), findsOneWidget);
    expect(find.text('Read-only'), findsOneWidget);
    expect(find.text('Now'), findsWidgets);
    expect(find.text('Us'), findsOneWidget);
    expect(find.text('Surprise'), findsOneWidget);
    expect(find.text('Shared Health'), findsOneWidget);
    expect(find.text('Nothing to surface right now'), findsOneWidget);

    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();
    expect(find.text('No shared health details to show'), findsOneWidget);
    expect(
      find.textContaining('does not indicate whether health data exists'),
      findsOneWidget,
    );
  });

  testWidgets('engine-only context is not rendered by partner home',
      (tester) async {
    final model = RelationshipHomeModel(cards: const [
      RelationshipHomeCard(
        id: 'hidden',
        tab: RelationshipHomeTab.us,
        kind: RelationshipHomeCardKind.memory,
        reference: 'private-context',
        visibility: RelationshipVisibility.engineOnly,
      ),
    ]);

    await tester.pumpWidget(CyclePartnerApp(homeModel: model));
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    expect(find.textContaining('private-context'), findsNothing);
  });

  testWidgets('fully shared raw health detail can render', (tester) async {
    final model = RelationshipHomeModel(cards: const [
      RelationshipHomeCard(
        id: 'health-energy',
        tab: RelationshipHomeTab.sharedHealth,
        kind: RelationshipHomeCardKind.sharedHealth,
        reference: 'health.energy',
        visibility: RelationshipVisibility.fullyShared,
        rawValue: 'low',
      ),
    ]);

    await tester.pumpWidget(CyclePartnerApp(homeModel: model));
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.text('health.energy: low'), findsOneWidget);
  });

  testWidgets('Us keeps secure sharing controls available', (tester) async {
    await tester.pumpWidget(const CyclePartnerApp());
    await tester.tap(find.text('Us'));
    await tester.pumpAndSettle();

    expect(find.text('Sharing controls'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
    expect(find.text('NOTIFY'), findsOneWidget);
    expect(find.text('BACKUP'), findsOneWidget);
    expect(find.text('Private notifications'), findsOneWidget);
  });

  testWidgets('coordinator pipeline feeds authorized cards into partner UI',
      (tester) async {
    final now = DateTime.utc(2026, 9, 14, 10);
    final input = PartnerExperienceInput(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      sharedHealthEntries: [
        CoupleContextEntry<Object?>(
          ownerId: 'a',
          category: 'health.energy',
          observedAt: now,
          visibility: RelationshipVisibility.fullyShared,
          value: 'steady',
        ),
      ],
      grants: [
        RelationshipCategoryGrant(
          id: 'view-energy',
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.energy',
          capabilities: {RelationshipCapability.view},
          visibility: RelationshipVisibility.fullyShared,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
    );

    await tester.pumpWidget(CyclePartnerApp(experienceInput: input));
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.text('health.energy: steady'), findsOneWidget);
  });

  testWidgets('coordinator pipeline keeps engine-only health hidden',
      (tester) async {
    final now = DateTime.utc(2026, 9, 14, 10);
    final input = PartnerExperienceInput(
      ownerId: 'a',
      partnerId: 'b',
      at: now,
      sharedHealthEntries: [
        CoupleContextEntry<Object?>(
          ownerId: 'a',
          category: 'health.sleep',
          observedAt: now,
          visibility: RelationshipVisibility.engineOnly,
          value: 'poor',
        ),
      ],
      grants: [
        RelationshipCategoryGrant(
          id: 'engine-sleep',
          ownerId: 'a',
          recipientId: 'b',
          category: 'health.sleep',
          capabilities: {
            RelationshipCapability.relationshipIntelligence,
          },
          visibility: RelationshipVisibility.engineOnly,
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ],
    );

    await tester.pumpWidget(CyclePartnerApp(experienceInput: input));
    await tester.tap(find.text('Shared Health'));
    await tester.pumpAndSettle();

    expect(find.textContaining('health.sleep'), findsNothing);
    expect(find.textContaining('poor'), findsNothing);
    expect(find.text('No shared health details to show'), findsOneWidget);
  });
}
