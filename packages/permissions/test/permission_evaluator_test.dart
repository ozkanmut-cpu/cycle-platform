import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9, 16);

  PermissionGrant grant({
    required String id,
    required String recipientId,
    required RecipientKind recipientKind,
    required Set<PermissionAction> actions,
    required Set<String> categories,
    Set<String> fields = const <String>{},
    Set<String> purposes = const <String>{},
    DateTime? validUntil,
    DateTime? revokedAt,
  }) {
    return PermissionGrant(
      id: id,
      ownerId: 'patient-1',
      recipientId: recipientId,
      recipientKind: recipientKind,
      actions: actions,
      scope: PermissionScope(
        categories: categories,
        fields: fields,
        purposes: purposes,
        validUntil: validUntil,
      ),
      createdAt: now.subtract(const Duration(days: 1)),
      revokedAt: revokedAt,
    );
  }

  test('default deny when there is no matching grant', () {
    const evaluator = PermissionEvaluator();
    final decision = evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        action: PermissionAction.view,
        category: 'cycle',
        at: now,
      ),
      grants: const <PermissionGrant>[],
    );

    expect(decision.allowed, isFalse);
    expect(decision.reason, 'default-deny');
  });

  test('partner can view only explicitly shared fields', () {
    const evaluator = PermissionEvaluator();
    final partnerGrant = grant(
      id: 'grant-partner',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{PermissionAction.view},
      categories: const <String>{'cycle'},
      fields: const <String>{'cycleDay', 'periodWindow'},
    );

    final allowed = evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        action: PermissionAction.view,
        category: 'cycle',
        field: 'cycleDay',
        at: now,
      ),
      grants: <PermissionGrant>[partnerGrant],
    );
    final denied = evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'patient-1',
        recipientId: 'partner-1',
        action: PermissionAction.view,
        category: 'cycle',
        field: 'sexualActivity',
        at: now,
      ),
      grants: <PermissionGrant>[partnerGrant],
    );

    expect(allowed.allowed, isTrue);
    expect(denied.allowed, isFalse);
  });

  test('doctor export requires explicit action and purpose', () {
    const evaluator = PermissionEvaluator();
    final doctorGrant = grant(
      id: 'grant-doctor',
      recipientId: 'doctor-1',
      recipientKind: RecipientKind.clinician,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.export,
      },
      categories: const <String>{'labs'},
      fields: const <String>{'result'},
      purposes: const <String>{'care'},
    );

    final careExport = evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'patient-1',
        recipientId: 'doctor-1',
        action: PermissionAction.export,
        category: 'labs',
        field: 'result',
        purpose: 'care',
        at: now,
      ),
      grants: <PermissionGrant>[doctorGrant],
    );
    final researchExport = evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'patient-1',
        recipientId: 'doctor-1',
        action: PermissionAction.export,
        category: 'labs',
        field: 'result',
        purpose: 'research',
        at: now,
      ),
      grants: <PermissionGrant>[doctorGrant],
    );

    expect(careExport.allowed, isTrue);
    expect(researchExport.allowed, isFalse);
  });

  test('expired and revoked grants are denied', () {
    const evaluator = PermissionEvaluator();
    final expired = grant(
      id: 'expired',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{PermissionAction.notify},
      categories: const <String>{'cycle'},
      validUntil: now,
    );
    final revoked = grant(
      id: 'revoked',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{PermissionAction.notify},
      categories: const <String>{'cycle'},
      revokedAt: now.subtract(const Duration(minutes: 1)),
    );
    final request = PermissionRequest(
      ownerId: 'patient-1',
      recipientId: 'partner-1',
      action: PermissionAction.notify,
      category: 'cycle',
      at: now,
    );

    expect(evaluator.evaluate(request: request, grants: <PermissionGrant>[expired]).allowed, isFalse);
    expect(evaluator.evaluate(request: request, grants: <PermissionGrant>[revoked]).allowed, isFalse);
  });

  test('revocation effect rotates recipient keys', () {
    const evaluator = PermissionEvaluator();
    final doctorGrant = grant(
      id: 'grant-doctor',
      recipientId: 'doctor-1',
      recipientKind: RecipientKind.clinician,
      actions: const <PermissionAction>{
        PermissionAction.view,
        PermissionAction.notify,
        PermissionAction.export,
      },
      categories: const <String>{'labs'},
    );

    final effect = evaluator.revocationEffect(doctorGrant);

    expect(effect.rotateRecipientKeys, isTrue);
    expect(effect.stopNotifications, isTrue);
    expect(effect.invalidateExports, isTrue);
  });

  test('privacy simulator uses production evaluator decisions', () {
    final simulator = PrivacySimulator();
    final partnerGrant = grant(
      id: 'grant-partner',
      recipientId: 'partner-1',
      recipientKind: RecipientKind.partner,
      actions: const <PermissionAction>{PermissionAction.view},
      categories: const <String>{'cycle'},
      fields: const <String>{'cycleDay'},
    );

    final result = simulator.simulate(
      requests: <PermissionRequest>[
        PermissionRequest(
          ownerId: 'patient-1',
          recipientId: 'partner-1',
          action: PermissionAction.view,
          category: 'cycle',
          field: 'cycleDay',
          at: now,
        ),
        PermissionRequest(
          ownerId: 'patient-1',
          recipientId: 'partner-1',
          action: PermissionAction.view,
          category: 'cycle',
          field: 'sexualActivity',
          at: now,
        ),
      ],
      grants: <PermissionGrant>[partnerGrant],
    );

    expect(result.visible.length, 1);
    expect(result.hidden.length, 1);
  });
}
