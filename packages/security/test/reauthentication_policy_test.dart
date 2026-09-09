import 'package:cycle_security/cycle_security.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9, 16);

  test('secure default always requires reauthentication', () {
    expect(
      ReauthenticationPolicy.secureDefault.requiresAuthentication(
        now: now,
        lastAuthenticatedAt: now,
      ),
      isTrue,
    );
  });

  test('standard grace can avoid a prompt inside configured window', () {
    const policy = ReauthenticationPolicy(
      standardGracePeriod: Duration(seconds: 30),
    );

    expect(
      policy.requiresAuthentication(
        now: now,
        lastAuthenticatedAt: now.subtract(const Duration(seconds: 10)),
      ),
      isFalse,
    );
    expect(
      policy.requiresAuthentication(
        now: now,
        lastAuthenticatedAt: now.subtract(const Duration(seconds: 31)),
      ),
      isTrue,
    );
  });

  test('extra private always ignores grace periods', () {
    const policy = ReauthenticationPolicy(
      standardGracePeriod: Duration(minutes: 5),
      sensitiveGracePeriod: Duration(minutes: 5),
    );

    expect(
      policy.requiresAuthentication(
        now: now,
        lastAuthenticatedAt: now,
        sensitivity: LockSensitivity.extraPrivate,
      ),
      isTrue,
    );
  });

  test('future authentication timestamps fail secure', () {
    const policy = ReauthenticationPolicy(
      standardGracePeriod: Duration(minutes: 5),
    );

    expect(
      policy.requiresAuthentication(
        now: now,
        lastAuthenticatedAt: now.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });
}
