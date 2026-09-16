import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed =
      int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = runProductionPermissionFlowSmoke(seed);
  if (!report.passed) {
    throw StateError('Permission-flow production smoke contains S4 failures');
  }
  print(report.toNormalizedJson());
}
