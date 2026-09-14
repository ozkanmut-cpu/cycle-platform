import 'dart:convert';

import 'package:cycle_clinical_documents/cycle_clinical_documents.dart';
import 'package:test/test.dart';

void main() {
  const builder = PortableClinicalPackageBuilder();
  final createdAt = DateTime.utc(2026, 9, 14, 4, 30);

  PortableClinicalEntry entry({
    required String id,
    required String path,
    required PortableClinicalEntryKind kind,
    required Object payload,
    String patientId = 'patient-1',
    String mediaType = 'application/json',
    int schemaVersion = 1,
    List<String> provenanceIds = const ['prov-1'],
    List<String> evidenceIds = const ['evidence-1'],
  }) {
    final bytes = utf8.encode(jsonEncode(payload));
    return PortableClinicalEntry(
      id: id,
      patientId: patientId,
      path: path,
      kind: kind,
      mediaType: mediaType,
      payload: bytes,
      sha256: sha256Hex(bytes),
      schemaVersion: schemaVersion,
      provenanceIds: provenanceIds,
      evidenceIds: evidenceIds,
    );
  }

  PortableClinicalPackage build(List<PortableClinicalEntry> entries) {
    return builder.build(
      packageId: 'pkg-1',
      patientId: 'patient-1',
      createdAt: createdAt,
      authorization: const PortableClinicalExportAuthorization(
        patientId: 'patient-1',
        exportAllowed: true,
      ),
      entries: entries,
    );
  }

  test('packages snapshot, document and FHIR entries deterministically', () {
    final snapshot = entry(
      id: 'snapshot',
      path: 'clinical/snapshot.json',
      kind: PortableClinicalEntryKind.clinicalSnapshot,
      payload: {'missingness': 'unknown', 'confidence': 'low'},
    );
    final document = entry(
      id: 'doc',
      path: 'documents/report.json',
      kind: PortableClinicalEntryKind.document,
      payload: {'confirmation': 'human-confirmed'},
    );
    final fhir = entry(
      id: 'fhir',
      path: 'fhir/bundle.json',
      kind: PortableClinicalEntryKind.fhirBundle,
      payload: {'resourceType': 'Bundle', 'type': 'collection'},
    );

    final first = build([fhir, snapshot, document]);
    final second = build([document, fhir, snapshot]);

    expect(first.manifest.canonicalJson(), second.manifest.canonicalJson());
    expect(
      first.manifest.entries.map((item) => item.path),
      ['clinical/snapshot.json', 'documents/report.json', 'fhir/bundle.json'],
    );
    expect(first.manifest.entries.first.provenanceIds, ['prov-1']);
    expect(first.manifest.entries.first.evidenceIds, ['evidence-1']);
  });

  test('denies export without matching explicit authorization', () {
    expect(
      () => builder.build(
        packageId: 'pkg-1',
        patientId: 'patient-1',
        createdAt: createdAt,
        authorization: const PortableClinicalExportAuthorization(
          patientId: 'patient-1',
          exportAllowed: false,
        ),
        entries: [
          entry(
            id: 'snapshot',
            path: 'snapshot.json',
            kind: PortableClinicalEntryKind.clinicalSnapshot,
            payload: {'state': 'notRecorded'},
          ),
        ],
      ),
      throwsA(isA<PortableClinicalPackageException>()),
    );
  });

  test('rejects mixed patients', () {
    expect(
      () => build([
        entry(
          id: 'one',
          path: 'one.json',
          kind: PortableClinicalEntryKind.document,
          payload: {'value': 1},
        ),
        entry(
          id: 'two',
          patientId: 'patient-2',
          path: 'two.json',
          kind: PortableClinicalEntryKind.document,
          payload: {'value': 2},
        ),
      ]),
      throwsA(isA<PortableClinicalPackageException>()),
    );
  });

  test('rejects duplicate ids and paths', () {
    final one = entry(
      id: 'same',
      path: 'one.json',
      kind: PortableClinicalEntryKind.document,
      payload: {'value': 1},
    );
    final duplicateId = entry(
      id: 'same',
      path: 'two.json',
      kind: PortableClinicalEntryKind.document,
      payload: {'value': 2},
    );
    final duplicatePath = entry(
      id: 'other',
      path: 'one.json',
      kind: PortableClinicalEntryKind.document,
      payload: {'value': 3},
    );

    expect(
      () => build([one, duplicateId]),
      throwsA(isA<PortableClinicalPackageException>()),
    );
    expect(
      () => build([one, duplicatePath]),
      throwsA(isA<PortableClinicalPackageException>()),
    );
  });

  test('rejects checksum tampering', () {
    final original = utf8.encode('{"safe":true}');
    final tampered = [...original]..add(0);
    final invalid = PortableClinicalEntry(
      id: 'doc',
      patientId: 'patient-1',
      path: 'doc.json',
      kind: PortableClinicalEntryKind.document,
      mediaType: 'application/json',
      payload: tampered,
      sha256: sha256Hex(original),
      schemaVersion: 1,
    );

    expect(
      () => build([invalid]),
      throwsA(isA<PortableClinicalPackageException>()),
    );
  });

  test('preserves explicit missingness and uncertainty payload bytes', () {
    final payload = {
      'state': 'notRecorded',
      'uncertainty': 'conflicting',
      'value': null,
    };
    final source = entry(
      id: 'snapshot',
      path: 'snapshot.json',
      kind: PortableClinicalEntryKind.clinicalSnapshot,
      payload: payload,
      provenanceIds: ['prov-b', 'prov-a', 'prov-a'],
      evidenceIds: ['ev-b', 'ev-a', 'ev-a'],
    );
    final package = build([source]);

    expect(package.payloadsByPath['snapshot.json'], source.payload);
    expect(package.manifest.entries.single.provenanceIds, ['prov-a', 'prov-b']);
    expect(package.manifest.entries.single.evidenceIds, ['ev-a', 'ev-b']);
  });

  test('rejects blank identifiers and invalid schema versions', () {
    expect(
      () => PortableClinicalEntry(
        id: ' ',
        patientId: 'patient-1',
        path: 'doc.json',
        kind: PortableClinicalEntryKind.document,
        mediaType: 'application/json',
        payload: const [],
        sha256: sha256Hex(const []),
        schemaVersion: 1,
      ),
      throwsA(isA<PortableClinicalPackageException>()),
    );
    expect(
      () => PortableClinicalEntry(
        id: 'doc',
        patientId: 'patient-1',
        path: 'doc.json',
        kind: PortableClinicalEntryKind.document,
        mediaType: 'application/json',
        payload: const [],
        sha256: sha256Hex(const []),
        schemaVersion: 0,
      ),
      throwsA(isA<PortableClinicalPackageException>()),
    );
  });

  test('sha256 implementation matches a known vector', () {
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
}
