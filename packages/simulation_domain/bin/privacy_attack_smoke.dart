import 'package:cycle_simulation_domain/simulation_domain.dart';

Future<void> main(List<String> args) async {
  final seedArg = args.where((item) => item.startsWith('--seed=')).firstOrNull;
  final seed =
      int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260916;
  final report = await runProductionPrivacyAttackSmoke(seed);
  if (!report.passed) {
    throw StateError(
      'Privacy-attack production smoke contains contract failures',
    );
  }
  print(report.toNormalizedJson());
}
