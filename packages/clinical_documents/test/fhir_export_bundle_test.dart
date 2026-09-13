import 'dart:convert';

import 'package:cycle_clinical_documents/cycle_clinical_documents.dart';
import 'package:test/test.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 9, 14, 12, 30);

  test('single document export includes patient and mapped resources', () {
    final document = _ingest(
      id: 'doc-a',
      subjectId: 'subject-1',
      text: 'LAB | hb | Hemoglobin | 13.2 | g/dL | 12 - 16',
    );

    final export = const FhirExportBundleBuilder().build(
      exportId: 'export-1',
      exportedAt: exportedAt,
      documents: <ClinicalDocumentResult>[document],
    );

    expect(export.bundle['resourceType'], 'Bundle');
    expect(export.bundle['type'], 'collection');
    expect(export.bundle['timestamp'], exportedAt.toIso8601String());

    final entries = export.bundle['entry']! as List<Object?>;
    final resources = entries
        .cast<Map<String, Object?>>()
        .map((entry) => entry['resource']! as Map<String, Object?>)
        .toList();
    expect(resources.any((resource) => resource['resourceType'] == 'Patient'),
        isTrue);
    expect(
      resources.any((resource) => resource['resourceType'] == 'Observation'),
      isTrue,
    );
    expect(
      resources
          .any((resource) => resource['resourceType'] == 'DocumentReference'),
      isTrue,
    );
  });

  test('multi-document export is deterministic regardless of input order', () {
    final a = _ingest(
      id: 'doc-a',
      subjectId: 'subject-1',
      text: 'LAB | hb | Hemoglobin | 13.2 | g/dL | 12 - 16',
    );
    final b = _ingest(
      id: 'doc-b',
      subjectId: 'subject-1',
      text: 'CONDITION | c1 | Example condition',
    );
    const builder = FhirExportBundleBuilder();

    final first = builder.build(
      exportId: 'export-stable',
      exportedAt: exportedAt,
      documents: <ClinicalDocumentResult>[a, b],
    );
    final second = builder.build(
      exportId: 'export-stable',
      exportedAt: exportedAt,
      documents: <ClinicalDocumentResult>[b, a],
    );

    expect(first.toJson(), second.toJson());
    expect(jsonDecode(first.toJson()), first.bundle);
  });

  test('mixed subjects fail deterministically', () {
    final a = _ingest(
      id: 'doc-a',
      subjectId: 'subject-1',
      text: 'CONDITION | c1 | Example condition',
    );
    final b = _ingest(
      id: 'doc-b',
      subjectId: 'subject-2',
      text: 'CONDITION | c2 | Another condition',
    );

    expect(
      () => const FhirExportBundleBuilder().build(
        exportId: 'export-mixed',
        exportedAt: exportedAt,
        documents: <ClinicalDocumentResult>[a, b],
      ),
      throwsA(isA<FhirExportValidationException>()),
    );
  });

  test('duplicate document ids fail deterministically', () {
    final a = _ingest(
      id: 'doc-dup',
      subjectId: 'subject-1',
      text: 'CONDITION | c1 | Example condition',
    );
    final b = _ingest(
      id: 'doc-dup',
      subjectId: 'subject-1',
      text: 'CONDITION | c2 | Another condition',
    );

    expect(
      () => const FhirExportBundleBuilder().build(
        exportId: 'export-duplicate',
        exportedAt: exportedAt,
        documents: <ClinicalDocumentResult>[a, b],
      ),
      throwsA(isA<FhirExportValidationException>()),
    );
  });

  test('blank export ids and empty exports fail deterministically', () {
    final document = _ingest(
      id: 'doc-a',
      subjectId: 'subject-1',
      text: 'CONDITION | c1 | Example condition',
    );
    const builder = FhirExportBundleBuilder();

    expect(
      () => builder.build(
        exportId: '   ',
        exportedAt: exportedAt,
        documents: <ClinicalDocumentResult>[document],
      ),
      throwsA(isA<FhirExportValidationException>()),
    );
    expect(
      () => builder.build(
        exportId: 'export-empty',
        exportedAt: exportedAt,
        documents: const <ClinicalDocumentResult>[],
      ),
      throwsA(isA<FhirExportValidationException>()),
    );
  });

  test('human confirmation metadata survives bundle export', () {
    final input = ClinicalDocumentInput(
      id: 'doc-ocr',
      subjectId: 'subject-1',
      fileName: 'scan.png',
      mimeType: 'image/png',
      bytes: const <int>[1],
      receivedAt: DateTime.utc(2026, 9, 14),
    );
    final result = ClinicalDocumentIngestionPipeline(
      ocrExtractor: const _Ocr(),
    ).ingest(input);

    final bundle = const FhirExportBundleBuilder().build(
      exportId: 'export-ocr',
      exportedAt: exportedAt,
      documents: <ClinicalDocumentResult>[result],
    );
    final entries = bundle.bundle['entry']! as List<Object?>;
    final observation = entries
        .cast<Map<String, Object?>>()
        .map((entry) => entry['resource']! as Map<String, Object?>)
        .firstWhere((resource) => resource['resourceType'] == 'Observation');
    final extensions = observation['extension']! as List<Object?>;

    expect(
      extensions.cast<Map<String, Object?>>().any(
            (extension) =>
                extension['url'] ==
                    'https://cycle.health/fhir/StructureDefinition/human-confirmation-required' &&
                extension['valueBoolean'] == true,
          ),
      isTrue,
    );
  });
}

ClinicalDocumentResult _ingest({
  required String id,
  required String subjectId,
  required String text,
}) =>
    const ClinicalDocumentIngestionPipeline().ingest(
      ClinicalDocumentInput(
        id: id,
        subjectId: subjectId,
        fileName: '$id.txt',
        mimeType: 'text/plain',
        bytes: utf8.encode(text),
        receivedAt: DateTime.utc(2026, 9, 14),
      ),
    );

class _Ocr implements OcrTextExtractor {
  const _Ocr();

  @override
  TextExtractionResult? extract(ClinicalDocumentInput input) =>
      const TextExtractionResult(
        text: 'LAB | hb | Hemoglobin | 13.2 | g/dL | 12 - 16',
        method: ExtractionMethod.ocr,
        confidence: 0.82,
      );
}
