import 'dart:convert';
import 'dart:io';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
        'Usage: dart run bin/replay_failure.dart <failure-bundle.json>');
    exitCode = 64;
    return;
  }

  final bundle = FailureBundle.decode(File(args.single).readAsStringSync());
  final invariant = _invariantFor(bundle.targetInvariantId);
  final replay = const ReplayEngine().replay(
    bundle: bundle,
    invariant: invariant,
  );
  if (!replay.matches(bundle)) {
    stderr.writeln('Replay did not reproduce the recorded target failure.');
    exitCode = 1;
    return;
  }

  final minimized = const ScenarioMinimizer().minimize(
    bundle: bundle,
    invariant: invariant,
  );
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'reproduced': true,
      'targetInvariantId': replay.target.id,
      'severity': replay.target.severity.name,
      'evidence': replay.target.evidence,
      'originalEventCount': bundle.events.length,
      'minimizedEventCount': minimized.events.length,
      'minimizedReplay': minimized.replay.toJson(),
    }),
  );
}

SimulationInvariant _invariantFor(String id) {
  switch (id) {
    case 'missing-is-not-zero':
      return const MissingIsNotZeroInvariant();
    case 'revocation-boundary':
      return const PermissionRevocationInvariant();
    default:
      throw ArgumentError('Unsupported invariant: $id');
  }
}
