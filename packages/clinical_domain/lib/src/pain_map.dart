import 'package:cycle_core_domain/cycle_core_domain.dart';

enum PainRegionGroup { abdomen, pelvis, back, hipGroin, vulvarPerineal }

enum PainLaterality { none, left, right, bilateral, midline }

class PainRegionDefinition {
  const PainRegionDefinition({
    required this.id,
    required this.title,
    required this.group,
    required this.laterality,
    required this.routingKeys,
    this.parentId,
  });

  final String id;
  final String title;
  final PainRegionGroup group;
  final PainLaterality laterality;
  final Set<String> routingKeys;
  final String? parentId;
}

class PainMapValidationException implements Exception {
  const PainMapValidationException(this.message);
  final String message;

  @override
  String toString() => 'PainMapValidationException: $message';
}

class PainRegionTaxonomy {
  PainRegionTaxonomy(Iterable<PainRegionDefinition> definitions)
      : regions = List.unmodifiable(_validate(definitions));

  final List<PainRegionDefinition> regions;

  PainRegionDefinition? findById(String id) {
    final key = id.trim().toLowerCase();
    for (final region in regions) {
      if (region.id.trim().toLowerCase() == key) return region;
    }
    return null;
  }

  static List<PainRegionDefinition> _validate(
    Iterable<PainRegionDefinition> definitions,
  ) {
    final result = definitions.toList();
    final ids = <String>{};
    for (final region in result) {
      final id = region.id.trim().toLowerCase();
      if (id.isEmpty || region.title.trim().isEmpty) {
        throw const PainMapValidationException(
            'Region id/title must not be empty.');
      }
      if (!ids.add(id)) {
        throw PainMapValidationException('Duplicate pain region id: $id.');
      }
      if (region.routingKeys.isEmpty ||
          region.routingKeys.any((key) => key.trim().isEmpty)) {
        throw PainMapValidationException('Region "$id" needs routing keys.');
      }
    }
    final byId = <String, PainRegionDefinition>{
      for (final region in result) region.id.trim().toLowerCase(): region,
    };
    for (final region in result) {
      final id = region.id.trim().toLowerCase();
      final parent = region.parentId?.trim().toLowerCase();
      if (parent == null || parent.isEmpty) continue;
      final parentRegion = byId[parent];
      if (parentRegion == null) {
        throw PainMapValidationException(
          'Region "${region.id}" references missing parent "$parent".',
        );
      }
      if (parent == id) {
        throw PainMapValidationException(
          'Region "${region.id}" cannot parent itself.',
        );
      }
      if (parentRegion.group != region.group) {
        throw PainMapValidationException(
          'Region "${region.id}" must share its parent group.',
        );
      }
      if (region.laterality == PainLaterality.none) {
        throw PainMapValidationException(
          'Child region "${region.id}" needs explicit laterality.',
        );
      }
      if (parentRegion.laterality != PainLaterality.none) {
        throw PainMapValidationException(
          'Parent region "${parentRegion.id}" must be generalized.',
        );
      }
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }
}

class PainLocationSelection {
  const PainLocationSelection({required this.state, this.regionIds = const {}});

  final DataState state;
  final Set<String> regionIds;
}

class PainRoutingResult {
  const PainRoutingResult({
    required this.state,
    required this.regionIds,
    required this.symptomKeys,
  });

  final DataState state;
  final List<String> regionIds;
  final List<String> symptomKeys;
}

class PainMapRouter {
  const PainMapRouter();

  PainRoutingResult route({
    required PainLocationSelection selection,
    required PainRegionTaxonomy taxonomy,
  }) {
    if (selection.state == DataState.unknown ||
        selection.state == DataState.notRecorded) {
      if (selection.regionIds.isNotEmpty) {
        throw const PainMapValidationException(
          'Unknown/not-recorded pain location cannot contain regions.',
        );
      }
      return PainRoutingResult(
        state: selection.state,
        regionIds: const [],
        symptomKeys: const [],
      );
    }
    if (selection.state != DataState.yes || selection.regionIds.isEmpty) {
      throw const PainMapValidationException(
        'Recorded pain location requires explicit selected regions.',
      );
    }

    final ids = selection.regionIds.map((e) => e.trim().toLowerCase()).toSet();
    final keys = <String>{};
    for (final id in ids) {
      final region = taxonomy.findById(id);
      if (region == null) {
        throw PainMapValidationException('Unknown pain region id: $id.');
      }
      keys.addAll(region.routingKeys.map((e) => e.trim().toLowerCase()));
    }
    final sortedIds = ids.toList()..sort();
    final sortedKeys = keys.toList()..sort();
    return PainRoutingResult(
      state: selection.state,
      regionIds: List.unmodifiable(sortedIds),
      symptomKeys: List.unmodifiable(sortedKeys),
    );
  }
}

const bodyPelvicPainRegions = <PainRegionDefinition>[
  PainRegionDefinition(
      id: 'lower-abdomen-generalized',
      title: 'Lower abdomen',
      group: PainRegionGroup.abdomen,
      laterality: PainLaterality.none,
      routingKeys: {'lower abdominal pain'}),
  PainRegionDefinition(
      id: 'lower-abdomen-left',
      title: 'Left lower abdomen',
      group: PainRegionGroup.abdomen,
      laterality: PainLaterality.left,
      parentId: 'lower-abdomen-generalized',
      routingKeys: {'lower abdominal pain', 'left lower abdominal pain'}),
  PainRegionDefinition(
      id: 'lower-abdomen-right',
      title: 'Right lower abdomen',
      group: PainRegionGroup.abdomen,
      laterality: PainLaterality.right,
      parentId: 'lower-abdomen-generalized',
      routingKeys: {'lower abdominal pain', 'right lower abdominal pain'}),
  PainRegionDefinition(
      id: 'pelvis-generalized',
      title: 'Pelvis',
      group: PainRegionGroup.pelvis,
      laterality: PainLaterality.none,
      routingKeys: {'pelvic pain'}),
  PainRegionDefinition(
      id: 'pelvis-left',
      title: 'Left pelvis',
      group: PainRegionGroup.pelvis,
      laterality: PainLaterality.left,
      parentId: 'pelvis-generalized',
      routingKeys: {'pelvic pain', 'left pelvic pain'}),
  PainRegionDefinition(
      id: 'pelvis-right',
      title: 'Right pelvis',
      group: PainRegionGroup.pelvis,
      laterality: PainLaterality.right,
      parentId: 'pelvis-generalized',
      routingKeys: {'pelvic pain', 'right pelvic pain'}),
  PainRegionDefinition(
      id: 'pelvis-midline',
      title: 'Central pelvis',
      group: PainRegionGroup.pelvis,
      laterality: PainLaterality.midline,
      parentId: 'pelvis-generalized',
      routingKeys: {'pelvic pain', 'midline pelvic pain'}),
  PainRegionDefinition(
      id: 'groin-left',
      title: 'Left groin',
      group: PainRegionGroup.hipGroin,
      laterality: PainLaterality.left,
      routingKeys: {'groin pain', 'left groin pain'}),
  PainRegionDefinition(
      id: 'groin-right',
      title: 'Right groin',
      group: PainRegionGroup.hipGroin,
      laterality: PainLaterality.right,
      routingKeys: {'groin pain', 'right groin pain'}),
  PainRegionDefinition(
      id: 'lower-back-midline',
      title: 'Lower back',
      group: PainRegionGroup.back,
      laterality: PainLaterality.midline,
      routingKeys: {'lower back pain'}),
  PainRegionDefinition(
      id: 'flank-left',
      title: 'Left flank',
      group: PainRegionGroup.back,
      laterality: PainLaterality.left,
      routingKeys: {'flank pain', 'left flank pain'}),
  PainRegionDefinition(
      id: 'flank-right',
      title: 'Right flank',
      group: PainRegionGroup.back,
      laterality: PainLaterality.right,
      routingKeys: {'flank pain', 'right flank pain'}),
  PainRegionDefinition(
      id: 'vulvar-generalized',
      title: 'Vulvar area',
      group: PainRegionGroup.vulvarPerineal,
      laterality: PainLaterality.none,
      routingKeys: {'vulvar pain'}),
  PainRegionDefinition(
      id: 'perineum-midline',
      title: 'Perineum',
      group: PainRegionGroup.vulvarPerineal,
      laterality: PainLaterality.midline,
      routingKeys: {'perineal pain'}),
];

final bodyPelvicPainTaxonomy = PainRegionTaxonomy(bodyPelvicPainRegions);
