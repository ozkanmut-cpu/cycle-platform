import 'permission_evaluator.dart';
import 'permission_models.dart';

class PrivacySimulationEntry {
  const PrivacySimulationEntry({required this.request, required this.decision});

  final PermissionRequest request;
  final PermissionDecision decision;
}

class PrivacySimulationResult {
  const PrivacySimulationResult(this.entries);

  final List<PrivacySimulationEntry> entries;

  Iterable<PrivacySimulationEntry> get visible =>
      entries.where((entry) => entry.decision.allowed);

  Iterable<PrivacySimulationEntry> get hidden =>
      entries.where((entry) => !entry.decision.allowed);
}

class PrivacySimulator {
  const PrivacySimulator({this.evaluator = const PermissionEvaluator()});

  final PermissionEvaluator evaluator;

  PrivacySimulationResult simulate({
    required Iterable<PermissionRequest> requests,
    required Iterable<PermissionGrant> grants,
  }) {
    final grantList = List<PermissionGrant>.unmodifiable(grants);
    return PrivacySimulationResult(
      List<PrivacySimulationEntry>.unmodifiable(
        requests.map(
          (request) => PrivacySimulationEntry(
            request: request,
            decision: evaluator.evaluate(request: request, grants: grantList),
          ),
        ),
      ),
    );
  }
}
