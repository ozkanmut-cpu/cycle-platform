enum RoutingConfidence { insufficientInformation, low, medium, high }

class GuidelineVersion {
  const GuidelineVersion({required this.identifier, required this.version, required this.effectiveFrom});

  final String identifier;
  final String version;
  final DateTime effectiveFrom;
}

class ClinicalEvidenceRef {
  const ClinicalEvidenceRef({required this.sourceId, required this.summary});

  final String sourceId;
  final String summary;
}

class ConditionPack {
  const ConditionPack({
    required this.id,
    required this.schemaVersion,
    required this.title,
    required this.guideline,
    required this.symptomKeys,
    this.evidence = const [],
  });

  final String id;
  final int schemaVersion;
  final String title;
  final GuidelineVersion guideline;
  final Set<String> symptomKeys;
  final List<ClinicalEvidenceRef> evidence;
}

class SymptomReport {
  const SymptomReport({required this.symptomKeys, this.unknownKeys = const {}});

  final Set<String> symptomKeys;
  final Set<String> unknownKeys;
}

class ConditionPackMatch {
  const ConditionPackMatch({required this.pack, required this.score, required this.matchedSymptoms});

  final ConditionPack pack;
  final double score;
  final Set<String> matchedSymptoms;
}

class SymptomRoutingResult {
  const SymptomRoutingResult({
    required this.confidence,
    required this.matches,
    required this.missingInformation,
  });

  final RoutingConfidence confidence;
  final List<ConditionPackMatch> matches;
  final Set<String> missingInformation;

  bool get hasCandidates => matches.isNotEmpty;
}

class SymptomFirstRouter {
  const SymptomFirstRouter();

  SymptomRoutingResult route({required SymptomReport report, required List<ConditionPack> packs}) {
    final known = report.symptomKeys.map(_normalize).where((e) => e.isNotEmpty).toSet();
    if (known.isEmpty) {
      return SymptomRoutingResult(
        confidence: RoutingConfidence.insufficientInformation,
        matches: const [],
        missingInformation: report.unknownKeys.map(_normalize).where((e) => e.isNotEmpty).toSet(),
      );
    }

    final matches = <ConditionPackMatch>[];
    for (final pack in packs) {
      final normalizedPackSymptoms = pack.symptomKeys.map(_normalize).where((e) => e.isNotEmpty).toSet();
      if (normalizedPackSymptoms.isEmpty) continue;
      final overlap = known.intersection(normalizedPackSymptoms);
      if (overlap.isEmpty) continue;
      final score = overlap.length / normalizedPackSymptoms.length;
      matches.add(ConditionPackMatch(pack: pack, score: score, matchedSymptoms: overlap));
    }
    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.pack.id.compareTo(b.pack.id);
    });

    final best = matches.isEmpty ? 0.0 : matches.first.score;
    final confidence = switch (best) {
      >= 0.75 => RoutingConfidence.high,
      >= 0.5 => RoutingConfidence.medium,
      > 0 => RoutingConfidence.low,
      _ => RoutingConfidence.insufficientInformation,
    };

    return SymptomRoutingResult(
      confidence: confidence,
      matches: List.unmodifiable(matches),
      missingInformation: report.unknownKeys.map(_normalize).where((e) => e.isNotEmpty).toSet(),
    );
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
