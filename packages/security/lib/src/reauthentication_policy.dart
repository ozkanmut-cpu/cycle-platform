enum LockSensitivity {
  standard,
  sensitive,
  extraPrivate,
}

class ReauthenticationPolicy {
  const ReauthenticationPolicy({
    this.standardGracePeriod = Duration.zero,
    this.sensitiveGracePeriod = Duration.zero,
  });

  final Duration standardGracePeriod;
  final Duration sensitiveGracePeriod;

  static const secureDefault = ReauthenticationPolicy();

  bool requiresAuthentication({
    required DateTime now,
    required DateTime? lastAuthenticatedAt,
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) {
    if (lastAuthenticatedAt == null) return true;
    if (sensitivity == LockSensitivity.extraPrivate) return true;

    final grace = sensitivity == LockSensitivity.sensitive
        ? sensitiveGracePeriod
        : standardGracePeriod;
    if (grace <= Duration.zero) return true;

    final elapsed = now.toUtc().difference(lastAuthenticatedAt.toUtc());
    if (elapsed.isNegative) return true;
    return elapsed > grace;
  }
}
