import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed = seedArg == null ? 20260916 : int.parse(seedArg.substring(7));
  final cohort = const CohortGenerator().canonical(seed);
  final world = const SyntheticHealthWorldGenerator()
      .generate(cohort: cohort, seed: seed);
  final longitudinal = const LongitudinalSimulationGenerator().generate(
    cohort: cohort,
    healthWorld: world,
    seed: seed,
    years: 1,
  );
  final report = const GroundTruthOracle().evaluateSimulation(
    cohort: cohort,
    healthWorld: world,
    longitudinal: longitudinal,
    seed: seed,
  );
  final roundTrip = GroundTruthReport.fromJson(
    (jsonDecode(report.toNormalizedJson()) as Map).cast<String, Object?>(),
  );
  if (roundTrip.toNormalizedJson() != report.toNormalizedJson()) {
    throw StateError('Oracle JSON round-trip is not stable');
  }
  print(report.toNormalizedJson());
}
