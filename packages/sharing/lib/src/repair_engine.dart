import 'relationship_policy.dart';

enum RepairState {
  needSpace,
  readyToTalk,
  listenDontSolve,
  reconnect,
  apologize
}

enum RepairActionKind {
  giveSpace,
  inviteConversation,
  listenOnly,
  reconnectGently,
  offerApology
}

class RepairSignal {
  const RepairSignal(
      {required this.id,
      required this.ownerId,
      required this.partnerId,
      required this.state,
      required this.createdAt,
      this.expiresAt,
      this.revokedAt});
  final String id;
  final String ownerId;
  final String partnerId;
  final RepairState state;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool isActiveAt(DateTime at) {
    if (at.isBefore(createdAt) || revokedAt != null) return false;
    return expiresAt == null || at.isBefore(expiresAt!);
  }
}

class RepairSuggestion {
  const RepairSuggestion(
      {required this.id,
      required this.ownerId,
      required this.recipientId,
      required this.state,
      required this.action});
  final String id;
  final String ownerId;
  final String recipientId;
  final RepairState state;
  final RepairActionKind action;
}

class RepairEngine {
  const RepairEngine({this.firewall = const RelationshipPermissionFirewall()});
  final RelationshipPermissionFirewall firewall;

  List<RepairSuggestion> suggest({
    required String ownerId,
    required String recipientId,
    required DateTime at,
    required Iterable<RepairSignal> signals,
    required Iterable<RelationshipCategoryGrant> grants,
  }) {
    final scoped = signals
        .where((s) =>
            s.ownerId == ownerId &&
            s.partnerId == recipientId &&
            s.isActiveAt(at))
        .toList()
      ..sort((a, b) {
        final c = b.createdAt.compareTo(a.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    if (scoped.isEmpty) return const [];
    final signal = scoped.first;
    final allowed = firewall
        .evaluate(
          request: RelationshipAccessRequest(
              ownerId: ownerId,
              recipientId: recipientId,
              category: 'relationship.repair.${signal.state.name}',
              capability: RelationshipCapability.relationshipIntelligence,
              at: at),
          grants: grants,
        )
        .allowed;
    if (!allowed) return const [];
    final action = switch (signal.state) {
      RepairState.needSpace => RepairActionKind.giveSpace,
      RepairState.readyToTalk => RepairActionKind.inviteConversation,
      RepairState.listenDontSolve => RepairActionKind.listenOnly,
      RepairState.reconnect => RepairActionKind.reconnectGently,
      RepairState.apologize => RepairActionKind.offerApology,
    };
    return [
      RepairSuggestion(
          id: 'repair-${signal.id}-${action.name}',
          ownerId: ownerId,
          recipientId: recipientId,
          state: signal.state,
          action: action)
    ];
  }
}
