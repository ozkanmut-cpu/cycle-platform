import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg =
      args.where((value) => value.startsWith('--seed=')).firstOrNull;
  final seed =
      int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260915;
  final cohort = const CohortGenerator().canonical(seed);
  print(jsonEncode({
    'schemaVersion': cohortSchemaVersion,
    'seed': seed,
    'coverage': cohort.coverageSummary(),
    'cohort': cohort.toJson(),
  }));
}
