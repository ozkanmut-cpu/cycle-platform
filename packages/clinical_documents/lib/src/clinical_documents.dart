import 'dart:convert';

import 'package:cycle_core_domain/cycle_core_domain.dart';

enum ClinicalDocumentKind { lab, imaging, pathology, medication, procedure, referral, note, unknown }

enum ClinicalEntityKind { observation, condition, diagnosticReport, serviceRequest, medication, procedure }

enum ExtractionMethod { direct, ocr }

class ClinicalDocumentInput {
  ClinicalDocumentInput({
    required this.id,
    required this.subjectId,
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
    required this.receivedAt,
  }) : bytes = List<int>.unmodifiable(bytes);

  final String id;
  final String subjectId;
  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final DateTime receivedAt;
}

class PreservedSourceDocument {
  PreservedSourceDocument({
    required this.id,
    required this.subjectId,
    required this.fileName,
    required this.mimeType,
    required List<int> bytes,
    required this.checksum,
    required this.receivedAt,
  }) : bytes = List<int>.unmodifiable(bytes);

  final String id;
  final String subjectId;
  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final String checksum;
  final DateTime receivedAt;
}

class TextExtractionResult {
  const TextExtractionResult({
    required this.text,
    required this.method,
    required this.confidence,
  });

  final String text;
  final ExtractionMethod method;
  final double confidence;
}

abstract interface class DirectTextExtractor {
  TextExtractionResult? extract(ClinicalDocumentInput input);
}

abstract interface class OcrTextExtractor {
  TextExtractionResult? extract(ClinicalDocumentInput input);
}

class Utf8DirectTextExtractor implements DirectTextExtractor {
  const Utf8DirectTextExtractor();

  @override
  TextExtractionResult? extract(ClinicalDocumentInput input) {
    if (!input.mimeType.startsWith('text/') &&
        input.mimeType != 'application/json') {
      return null;
    }
    try {
      final text = utf8.decode(input.bytes).trim();
      if (text.isEmpty) return null;
      return TextExtractionResult(
        text: text,
        method: ExtractionMethod.direct,
        confidence: 1,
      );
    } on FormatException {
      return null;
    }
  }
}

class ClinicalEntity {
  const ClinicalEntity({
    required this.id,
    required this.kind,
    required this.code,
    required this.display,
    required this.confidence,
    required this.provenance,
    this.value,
    this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.status,
    this.note,
    this.requiresHumanConfirmation = false,
  });

  final String id;
  final ClinicalEntityKind kind;
  final String code;
  final String display;
  final num? value;
  final String? unit;
  final num? referenceLow;
  final num? referenceHigh;
  final String? status;
  final String? note;
  final double confidence;
  final Provenance provenance;
  final bool requiresHumanConfirmation;
}

class ClinicalDocumentResult {
  ClinicalDocumentResult({
    required this.source,
    required this.documentKind,
    required this.extraction,
    required List<ClinicalEntity> entities,
  }) : entities = List<ClinicalEntity>.unmodifiable(entities);

  final PreservedSourceDocument source;
  final ClinicalDocumentKind documentKind;
  final TextExtractionResult extraction;
  final List<ClinicalEntity> entities;
}

class ClinicalDocumentClassifier {
  const ClinicalDocumentClassifier();

  ClinicalDocumentKind classify(String text) {
    final value = text.toLowerCase();
    if (value.contains('pathology') || value.contains('histopathology') || value.contains('biopsy')) {
      return ClinicalDocumentKind.pathology;
    }
    if (value.contains('radiology') || value.contains('imaging') || value.contains('mri') || value.contains('ct ')) {
      return ClinicalDocumentKind.imaging;
    }
    if (value.contains('laboratory') || value.contains('lab result') || value.contains('reference range')) {
      return ClinicalDocumentKind.lab;
    }
    if (value.contains('medication')) return ClinicalDocumentKind.medication;
    if (value.contains('procedure')) return ClinicalDocumentKind.procedure;
    if (value.contains('referral') || value.contains('service request')) return ClinicalDocumentKind.referral;
    if (value.trim().isNotEmpty) return ClinicalDocumentKind.note;
    return ClinicalDocumentKind.unknown;
  }
}

class UnitNormalizer {
  const UnitNormalizer();

  String? normalize(String? unit) {
    if (unit == null) return null;
    final value = unit.trim().replaceAll('μ', 'u').replaceAll('µ', 'u');
    const aliases = <String, String>{
      'mg/dl': 'mg/dL',
      'g/dl': 'g/dL',
      'mmol/l': 'mmol/L',
      '10^9/l': '10^9/L',
      'u/l': 'U/L',
      '%': '%',
    };
    return aliases[value.toLowerCase()] ?? value;
  }
}

class ClinicalEntityExtractor {
  const ClinicalEntityExtractor({this.unitNormalizer = const UnitNormalizer()});

  final UnitNormalizer unitNormalizer;

  List<ClinicalEntity> extract({
    required String text,
    required String documentId,
    required ExtractionMethod method,
    required double extractionConfidence,
  }) {
    final output = <ClinicalEntity>[];
    final lines = const LineSplitter().convert(text);
    var index = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final lab = RegExp(
        r'^LAB\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([-+]?\d+(?:\.\d+)?)\s*\|\s*([^|]+)\|\s*([-+]?\d+(?:\.\d+)?)\s*-\s*([-+]?\d+(?:\.\d+)?)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (lab != null) {
        output.add(
          ClinicalEntity(
            id: '$documentId-e${index++}',
            kind: ClinicalEntityKind.observation,
            code: lab.group(1)!.trim(),
            display: lab.group(2)!.trim(),
            value: num.parse(lab.group(3)!),
            unit: unitNormalizer.normalize(lab.group(4)),
            referenceLow: num.parse(lab.group(5)!),
            referenceHigh: num.parse(lab.group(6)!),
            confidence: extractionConfidence,
            provenance: _provenance(documentId, method),
            requiresHumanConfirmation: extractionConfidence < 0.9,
          ),
        );
        continue;
      }

      final typed = RegExp(
        r'^(IMAGING|PATHOLOGY|CONDITION|SERVICE_REQUEST|MEDICATION|PROCEDURE)\s*\|\s*([^|]+)\|\s*([^|]+)(?:\|\s*(.*))?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (typed == null) continue;
      final kind = _kindFor(typed.group(1)!);
      output.add(
        ClinicalEntity(
          id: '$documentId-e${index++}',
          kind: kind,
          code: typed.group(2)!.trim(),
          display: typed.group(3)!.trim(),
          note: typed.group(4)?.trim(),
          confidence: extractionConfidence,
          provenance: _provenance(documentId, method),
          requiresHumanConfirmation: extractionConfidence < 0.9,
        ),
      );
    }
    return List.unmodifiable(output);
  }

  ClinicalEntityKind _kindFor(String raw) {
    switch (raw.toUpperCase()) {
      case 'IMAGING':
      case 'PATHOLOGY':
        return ClinicalEntityKind.diagnosticReport;
      case 'CONDITION':
        return ClinicalEntityKind.condition;
      case 'SERVICE_REQUEST':
        return ClinicalEntityKind.serviceRequest;
      case 'MEDICATION':
        return ClinicalEntityKind.medication;
      case 'PROCEDURE':
        return ClinicalEntityKind.procedure;
    }
    throw StateError('Unsupported entity kind: $raw');
  }

  Provenance _provenance(String documentId, ExtractionMethod method) =>
      Provenance(
        sourceKind: SourceKind.importedDocument,
        sourceId: documentId,
        metadata: <String, Object?>{'extractionMethod': method.name},
      );
}

class ClinicalDocumentIngestionPipeline {
  const ClinicalDocumentIngestionPipeline({
    this.directExtractor = const Utf8DirectTextExtractor(),
    this.ocrExtractor,
    this.classifier = const ClinicalDocumentClassifier(),
    this.entityExtractor = const ClinicalEntityExtractor(),
  });

  final DirectTextExtractor directExtractor;
  final OcrTextExtractor? ocrExtractor;
  final ClinicalDocumentClassifier classifier;
  final ClinicalEntityExtractor entityExtractor;

  ClinicalDocumentResult ingest(ClinicalDocumentInput input) {
    final direct = directExtractor.extract(input);
    final extraction = direct ?? ocrExtractor?.extract(input);
    if (extraction == null || extraction.text.trim().isEmpty) {
      throw StateError('No text could be extracted from ${input.fileName}.');
    }
    final source = PreservedSourceDocument(
      id: input.id,
      subjectId: input.subjectId,
      fileName: input.fileName,
      mimeType: input.mimeType,
      bytes: input.bytes,
      checksum: _fnv1a64(input.bytes),
      receivedAt: input.receivedAt.toUtc(),
    );
    final kind = classifier.classify(extraction.text);
    final entities = entityExtractor.extract(
      text: extraction.text,
      documentId: input.id,
      method: extraction.method,
      extractionConfidence: extraction.confidence.clamp(0, 1).toDouble(),
    );
    return ClinicalDocumentResult(
      source: source,
      documentKind: kind,
      extraction: extraction,
      entities: entities,
    );
  }

  static String _fnv1a64(List<int> bytes) {
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.from(1099511628211);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final byte in bytes) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

class FhirMapper {
  const FhirMapper();

  Map<String, Object?> documentReference(ClinicalDocumentResult result) => <String, Object?>{
        'resourceType': 'DocumentReference',
        'id': result.source.id,
        'status': 'current',
        'subject': <String, Object?>{'reference': 'Patient/${result.source.subjectId}'},
        'content': <Object?>[
          <String, Object?>{
            'attachment': <String, Object?>{
              'contentType': result.source.mimeType,
              'title': result.source.fileName,
              'hash': result.source.checksum,
            },
          },
        ],
      };

  Map<String, Object?> mapEntity(ClinicalEntity entity, {required String subjectId}) {
    switch (entity.kind) {
      case ClinicalEntityKind.observation:
        return _observation(entity, subjectId);
      case ClinicalEntityKind.condition:
        return _coded('Condition', entity, subjectId);
      case ClinicalEntityKind.diagnosticReport:
        return _coded('DiagnosticReport', entity, subjectId);
      case ClinicalEntityKind.serviceRequest:
        return _coded('ServiceRequest', entity, subjectId);
      case ClinicalEntityKind.medication:
        return _medication(entity);
      case ClinicalEntityKind.procedure:
        return _coded('Procedure', entity, subjectId);
    }
  }

  List<Map<String, Object?>> mapAll(ClinicalDocumentResult result) => List.unmodifiable(
        <Map<String, Object?>>[
          documentReference(result),
          ...result.entities.map(
            (entity) => mapEntity(entity, subjectId: result.source.subjectId),
          ),
        ],
      );

  Map<String, Object?> _observation(ClinicalEntity entity, String subjectId) => <String, Object?>{
        'resourceType': 'Observation',
        'id': entity.id,
        'status': 'final',
        'subject': <String, Object?>{'reference': 'Patient/$subjectId'},
        'code': _code(entity),
        if (entity.value != null)
          'valueQuantity': <String, Object?>{
            'value': entity.value,
            if (entity.unit != null) 'unit': entity.unit,
          },
        if (entity.referenceLow != null || entity.referenceHigh != null)
          'referenceRange': <Object?>[
            <String, Object?>{
              if (entity.referenceLow != null)
                'low': <String, Object?>{'value': entity.referenceLow, if (entity.unit != null) 'unit': entity.unit},
              if (entity.referenceHigh != null)
                'high': <String, Object?>{'value': entity.referenceHigh, if (entity.unit != null) 'unit': entity.unit},
            },
          ],
        'extension': _provenanceExtensions(entity),
      };

  Map<String, Object?> _coded(String resourceType, ClinicalEntity entity, String subjectId) => <String, Object?>{
        'resourceType': resourceType,
        'id': entity.id,
        if (resourceType != 'Medication') 'subject': <String, Object?>{'reference': 'Patient/$subjectId'},
        if (resourceType == 'DiagnosticReport') 'status': 'final',
        if (resourceType == 'ServiceRequest') 'status': 'active',
        if (resourceType == 'ServiceRequest') 'intent': 'order',
        if (resourceType == 'Procedure') 'status': 'completed',
        'code': _code(entity),
        if (entity.note != null) 'note': <Object?>[<String, Object?>{'text': entity.note}],
        'extension': _provenanceExtensions(entity),
      };

  Map<String, Object?> _medication(ClinicalEntity entity) => <String, Object?>{
        'resourceType': 'Medication',
        'id': entity.id,
        'code': _code(entity),
        'extension': _provenanceExtensions(entity),
      };

  Map<String, Object?> _code(ClinicalEntity entity) => <String, Object?>{
        'coding': <Object?>[
          <String, Object?>{'code': entity.code, 'display': entity.display},
        ],
        'text': entity.display,
      };

  List<Object?> _provenanceExtensions(ClinicalEntity entity) => <Object?>[
        <String, Object?>{
          'url': 'https://cycle.health/fhir/StructureDefinition/source-document',
          'valueString': entity.provenance.sourceId,
        },
        <String, Object?>{
          'url': 'https://cycle.health/fhir/StructureDefinition/extraction-confidence',
          'valueDecimal': entity.confidence,
        },
        <String, Object?>{
          'url': 'https://cycle.health/fhir/StructureDefinition/human-confirmation-required',
          'valueBoolean': entity.requiresHumanConfirmation,
        },
      ];
}
