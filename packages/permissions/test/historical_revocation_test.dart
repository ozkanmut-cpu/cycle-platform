import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:test/test.dart';

void main() {
  test('revocation applies from its timestamp, not retroactively', () {
    final createdAt = DateTime.utc(2026, 9, 14, 8);
    final revokedAt = DateTime.utc(2026, 9, 14, 10);
    final grant = PermissionGrant(
      id: 'historical',
      ownerId: 'owner',
      recipientId: 'partner',
      recipientKind: RecipientKind.partner,
      actions: const {PermissionAction.view},
      scope: const PermissionScope(categories: {'cycle'}),
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
    const evaluator = PermissionEvaluator();

    PermissionDecision decision(DateTime at) => evaluator.evaluate(
      request: PermissionRequest(
        ownerId: 'owner',
        recipientId: 'partner',
        action: PermissionAction.view,
        category: 'cycle',
        at: at,
      ),
      grants: [grant],
    );

    expect(
      decision(revokedAt.subtract(const Duration(seconds: 1))).allowed,
      isTrue,
    );
    expect(decision(revokedAt).allowed, isFalse);
  });
}
