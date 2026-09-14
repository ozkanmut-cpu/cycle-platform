import 'dart:convert';

import 'clinical_documents.dart';

class FhirExportValidationException implements Exception {
  const FhirExportValidationException(this.message);

  final String message;

  @override
  String toString() => 'FhirExportValidationException: $message';
}

class FhirExportBundle {
  FhirExportBundle(Map<String, Object?> bundle)
      : bundle = Map<String, Object?>.unmodifiable(bundle);

  final Map<String, Object?> bundle;

  String toJson() => jsonEncode(bundle);
}

class FhirExportBundleBuilder {
  const FhirExportBundleBuilder({this.mapper = const FhirMapper()});

  static const schemaVersion = 1;
  final FhirMapper mapper;

  FhirExportBundle build({
    required String exportId,
    required DateTime exportedAt,
    required List<ClinicalDocumentResult> documents,
  }) {
    final normalizedExportId = exportId.trim();
    if (normalizedExportId.isEmpty) {
      throw const FhirExportValidationException(
        'FHIR export identifier must not be blank.',
      );
    }
    if (documents.isEmpty) {
      throw const FhirExportValidationException(
        'FHIR export requires at least one clinical document.',
      );
    }

    final orderedDocuments = List<ClinicalDocumentResult>.from(documents)
      ..sort((a, b) => a.source.id.compareTo(b.source.id));
    _validateDocuments(orderedDocuments);

    final subjectId = orderedDocuments.first.source.subjectId.trim();
    final resources = <Map<String, Object?>>[
      <String, Object?>{'resourceType': 'Patient', 'id': subjectId},
      for (final document in orderedDocuments) ...mapper.mapAll(document),
    ];

    resources.sort(_compareResources);
    final seenFullUrls = <String>{};
    final entries = <Object?>[];
    for (final resource in resources) {
      final resourceType = _requiredResourceField(resource, 'resourceType');
      final id = _requiredResourceField(resource, 'id');
      final fullUrl = _fullUrl(resourceType, id);
      if (!seenFullUrls.add(fullUrl)) {
        throw FhirExportValidationException(
          'Duplicate FHIR resource identity: $resourceType/$id',
        );
      }
      entries.add(<String, Object?>{
        'fullUrl': fullUrl,
        'resource': Map<String, Object?>.unmodifiable(resource),
      });
    }

    return FhirExportBundle(<String, Object?>{
      'resourceType': 'Bundle',
      'id': normalizedExportId,
      'meta': <String, Object?>{
        'tag': <Object?>[
          <String, Object?>{
            'system': 'https://cycle.health/fhir/CodeSystem/export-schema',
            'code': 'cycle-fhir-export-v$schemaVersion',
          },
        ],
      },
      'identifier': <String, Object?>{
        'system': 'https://cycle.health/fhir/export',
        'value': normalizedExportId,
      },
      'type': 'collection',
      'timestamp': exportedAt.toUtc().toIso8601String(),
      'entry': List<Object?>.unmodifiable(entries),
    });
  }

  void _validateDocuments(List<ClinicalDocumentResult> documents) {
    final subjectIds = <String>{};
    final documentIds = <String>{};
    for (final document in documents) {
      final subjectId = document.source.subjectId.trim();
      final documentId = document.source.id.trim();
      if (subjectId.isEmpty || documentId.isEmpty) {
        throw const FhirExportValidationException(
          'Document and subject identifiers must not be blank.',
        );
      }
      subjectIds.add(subjectId);
      if (!documentIds.add(documentId)) {
        throw FhirExportValidationException(
          'Duplicate clinical document identifier: $documentId',
        );
      }
    }
    if (subjectIds.length != 1) {
      throw const FhirExportValidationException(
        'FHIR export cannot mix multiple subjects.',
      );
    }
  }

  int _compareResources(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    final typeA = _requiredResourceField(a, 'resourceType');
    final typeB = _requiredResourceField(b, 'resourceType');
    final byType = typeA.compareTo(typeB);
    if (byType != 0) return byType;
    return _requiredResourceField(a, 'id')
        .compareTo(_requiredResourceField(b, 'id'));
  }

  String _requiredResourceField(Map<String, Object?> resource, String key) {
    final value = resource[key];
    if (value is! String || value.trim().isEmpty) {
      throw FhirExportValidationException(
        'FHIR resource is missing required $key.',
      );
    }
    return value.trim();
  }

  String _fullUrl(String resourceType, String id) =>
      'https://cycle.health/fhir/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(id)}';
}
