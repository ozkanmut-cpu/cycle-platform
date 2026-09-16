import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed =
      int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = runProductionRelationshipBehaviorSmoke(seed);
  if (!report.passed) {
    throw StateError(
      'Relationship-behavior production smoke contains contract failures',
    );
  }
  print(report.toNormalizedJson());
}
