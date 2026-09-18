import 'package:cycle_partner/main.dart';
import 'package:cycle_partner/partner_session.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'partner_journey_fixtures.dart';
import 'partner_journey_models.dart';

class QueuedPairingPayloadSource implements PairingPayloadSource {
  QueuedPairingPayloadSource(Iterable<String?> payloads)
      : _payloads = List<String?>.of(payloads);

  final List<String?> _payloads;

  @override
  Future<String?> acquire() async =>
      _payloads.isEmpty ? null : _payloads.removeAt(0);
}

class RecordingNotificationSink {
  final List<PrivateNotification?> _notifications = <PrivateNotification?>[];

  List<PrivateNotification?> get notifications =>
      List<PrivateNotification?>.unmodifiable(_notifications);

  void record(PrivateNotification? notification) =>
      _notifications.add(notification);
}

class DeterministicEnvelopeFactory {
  DeterministicEnvelopeFactory(this.fixtureId);

  final String fixtureId;
  int _nextVersion = 2;

  String next() => 'envelope-$fixtureId-v${_nextVersion++}';
}

class PartnerJourneyHarness {
  PartnerJourneyHarness({
    required this.tester,
    required this.fixture,
    this.deviceUnlocked = true,
  })  : _payloadSource = QueuedPairingPayloadSource(fixture.invitationPayloads),
        _registry = RecipientKeyRegistry(initial: fixture.keyRegistry.all()),
        _envelopeFactory = DeterministicEnvelopeFactory(fixture.id),
        _notificationSink = RecordingNotificationSink() {
    _recipientKeyVersionBefore = _activeKeyVersion;
    controller = PartnerSessionController(
      ownerId: fixture.ownerId,
      recipientId: fixture.recipientId,
      payloadSource: _payloadSource,
      revocationGrant: fixture.revocationGrant,
      keyRotator: RegistryRecipientKeyRotator(
        registry: _registry,
        keyEnvelopeIdFactory: _envelopeFactory.next,
      ),
      notificationGrants: fixture.notificationGrants,
      notificationRequest: fixture.notificationRequest,
      now: () => fixture.virtualNow,
    );
  }

  final WidgetTester tester;
  final PartnerJourneyFixture fixture;
  final bool deviceUnlocked;
  final QueuedPairingPayloadSource _payloadSource;
  final RecipientKeyRegistry _registry;
  final DeterministicEnvelopeFactory _envelopeFactory;
  final RecordingNotificationSink _notificationSink;
  late final PartnerSessionController controller;
  late final int? _recipientKeyVersionBefore;
  int _actionCount = 0;
  int _navigationCount = 0;
  int _recoveryCount = 0;
  String? _surfaceReached;

  int? get _activeKeyVersion => _registry
      .activeFor(ownerId: fixture.ownerId, recipientId: fixture.recipientId)
      ?.version;

  Future<void> pump() async {
    controller.setDeviceUnlocked(deviceUnlocked);
    await tester.pumpWidget(
      CyclePartnerApp(
        experienceInput: fixture.experienceInput,
        sessionController: controller,
      ),
    );
    await tester.pumpAndSettle();
    _surfaceReached = 'Now';
  }

  Future<void> pair() async {
    await _tapVisible(find.widgetWithText(FilledButton, 'Scan pairing QR'));
    _actionCount++;
    if (controller.state.errorCode != null) _recoveryCount++;
  }

  Future<void> tapTab(String label) async {
    await _tapVisible(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    _actionCount++;
    _navigationCount++;
    _surfaceReached = label;
  }

  Future<void> previewNotification() async {
    await _tapVisible(find.widgetWithText(TextButton, 'Preview notification'));
    _actionCount++;
    _notificationSink.record(controller.state.preview);
  }

  Future<void> disconnect() async {
    await _tapVisible(find.widgetWithText(TextButton, 'Disconnect'));
    _actionCount++;
    if (find.text('Scan pairing QR').evaluate().isNotEmpty) _recoveryCount++;
  }

  PartnerJourneyObservation observe({
    Map<String, String> visibleAssertions = const <String, String>{},
    Map<String, String> forbiddenMarkers = const <String, String>{},
  }) {
    final latestNotification = _notificationSink.notifications.isEmpty
        ? null
        : _notificationSink.notifications.last;
    return PartnerJourneyObservation(
      surfaceReached: _surfaceReached,
      pairingOutcomeCode: controller.state.errorCode,
      retryAffordanceObserved:
          find.text('Scan pairing QR').evaluate().isNotEmpty,
      visibleAssertionIds: visibleAssertions.entries
          .where((entry) => find.text(entry.value).evaluate().isNotEmpty)
          .map((entry) => entry.key)
          .toList(),
      forbiddenMarkerAbsenceAssertionIds: forbiddenMarkers.entries
          .where((entry) => find.text(entry.value).evaluate().isEmpty)
          .map((entry) => entry.key)
          .toList(),
      rawValueVisible: fixture.sensitiveMarkers.any(
        (marker) => find.text(marker).evaluate().isNotEmpty,
      ),
      cardSummaries: _visibleCardSummaries(),
      notificationPreviewClass: latestNotification == null
          ? null
          : latestNotification.redacted
              ? 'redacted'
              : 'detailed',
      notificationRedacted: latestNotification?.redacted,
      recipientKeyVersionBefore: _recipientKeyVersionBefore,
      recipientKeyVersionAfter: _activeKeyVersion,
      notificationStopped: controller.state.notificationsStopped,
      pairedAfterAction: controller.state.paired,
      actionCount: _actionCount,
      navigationCount: _navigationCount,
      recoveryCount: _recoveryCount,
    );
  }

  Future<void> cleanup() async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    controller.dispose();
  }

  Future<void> _tapVisible(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> _visibleCardSummaries() => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((tile) => tile.title)
      .whereType<Text>()
      .map((title) => title.data)
      .whereType<String>()
      .toList();
}
