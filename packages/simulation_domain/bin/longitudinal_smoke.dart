import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed = seedArg == null ? 20260915 : int.parse(seedArg.substring(7));
  final cohort = const CohortGenerator().canonical(seed);
  final world = const SyntheticHealthWorldGenerator().generate(
    cohort: cohort,
    seed: seed,
  );
  final horizons = <String, Object?>{};
  for (final years in [1, 3, 5]) {
    final simulation = const LongitudinalSimulationGenerator().generate(
      cohort: cohort,
      healthWorld: world,
      seed: seed,
      years: years,
    );
    simulation.validate(cohort: cohort);
    horizons['${years}y'] = simulation.coverageSummary();
  }
  print(jsonEncode({
    'schemaVersion': longitudinalSimulationSchemaVersion,
    'seed': seed,
    'syntheticEvidenceOnly': true,
    'horizons': horizons,
  }));
}
