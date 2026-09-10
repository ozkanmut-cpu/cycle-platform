import 'dart:io';

import 'package:cycle_clinical_documents/cycle_clinical_documents.dart';
import 'package:test/test.dart';

void main() {
  final fixture = File('test/fixtures/clinical_document.txt').readAsBytesSync();
  final receivedAt = DateTime.utc(2026, 9, 10, 9);

  test('direct ingestion preserves source and extracts normalized entities',
      () {
    final result = const ClinicalDocumentIngestionPipeline().ingest(
      ClinicalDocumentInput(
        id: 'doc-1',
        subjectId: 'subject-1',
        fileName: 'lab.txt',
        mimeType: 'text/plain',
        bytes: fixture,
        receivedAt: receivedAt,
      ),
    );

    expect(result.documentKind, ClinicalDocumentKind.pathology);
    expect(result.extraction.method, ExtractionMethod.direct);
    expect(result.source.bytes, orderedEquals(fixture));
    expect(result.source.checksum, hasLength(16));
    expect(result.entities, hasLength(7));

    final lab = result.entities.first;
    expect(lab.kind, ClinicalEntityKind.observation);
    expect(lab.value, 13.2);
    expect(lab.unit, 'g/dL');
    expect(lab.referenceLow, 12);
    expect(lab.referenceHigh, 16);
    expect(lab.requiresHumanConfirmation, isFalse);
  });

  test('image/PDF-like inputs fall back to OCR and require confirmation', () {
    final result = ClinicalDocumentIngestionPipeline(
      ocrExtractor: _FixtureOcrExtractor(fixture),
    ).ingest(
      ClinicalDocumentInput(
        id: 'doc-ocr',
        subjectId: 'subject-1',
        fileName: 'scan.png',
        mimeType: 'image/png',
        bytes: const <int>[1, 2, 3, 4],
        receivedAt: receivedAt,
      ),
    );

    expect(result.extraction.method, ExtractionMethod.ocr);
    expect(result.extraction.confidence, 0.82);
    expect(result.entities, isNotEmpty);
    expect(result.entities.every((entity) => entity.requiresHumanConfirmation),
        isTrue);
  });

  test('FHIR mapping covers every required resource type', () {
    final result = const ClinicalDocumentIngestionPipeline().ingest(
      ClinicalDocumentInput(
        id: 'doc-fhir',
        subjectId: 'subject-1',
        fileName: 'clinical.txt',
        mimeType: 'text/plain',
        bytes: fixture,
        receivedAt: receivedAt,
      ),
    );

    final resources = const FhirMapper().mapAll(result);
    final types = resources.map((resource) => resource['resourceType']).toSet();
    expect(
      types,
      containsAll(<String>{
        'Observation',
        'Condition',
        'DiagnosticReport',
        'ServiceRequest',
        'DocumentReference',
        'Medication',
        'Procedure',
      }),
    );

    final observation = resources.firstWhere(
      (resource) => resource['resourceType'] == 'Observation',
    );
    final quantity = observation['valueQuantity']! as Map<String, Object?>;
    expect(quantity['unit'], 'g/dL');
  });

  test('ingestion fails deterministically when neither extractor yields text',
      () {
    expect(
      () => const ClinicalDocumentIngestionPipeline().ingest(
        ClinicalDocumentInput(
          id: 'empty',
          subjectId: 'subject-1',
          fileName: 'scan.pdf',
          mimeType: 'application/pdf',
          bytes: <int>[1, 2, 3],
          receivedAt: receivedAt,
        ),
      ),
      throwsStateError,
    );
  });
}

class _FixtureOcrExtractor implements OcrTextExtractor {
  _FixtureOcrExtractor(this.bytes);

  final List<int> bytes;

  @override
  TextExtractionResult? extract(ClinicalDocumentInput input) =>
      TextExtractionResult(
        text: String.fromCharCodes(bytes),
        method: ExtractionMethod.ocr,
        confidence: 0.82,
      );
}
