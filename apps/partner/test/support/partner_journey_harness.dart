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
  bool _disconnectRecoveryPending = false;

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
  }

  Future<void> pair() async {
    await _tapVisible(find.widgetWithText(FilledButton, 'Scan pairing QR'));
    _actionCount++;
    if (controller.state.errorCode != null) _recoveryCount++;
  }

  Future<void> tapTab(String label) async {
    final destination = _navigationDestination(label);
    await _tapVisible(destination);
    _actionCount++;
    _navigationCount++;
    final renderedSurface = _renderedSurface();
    if (renderedSurface != label) {
      throw StateError('partner_surface_unreachable');
    }
  }

  Future<void> previewNotification() async {
    await _tapVisible(find.widgetWithText(TextButton, 'Preview notification'));
    _actionCount++;
    _notificationSink.record(controller.state.preview);
  }

  Future<void> disconnect() async {
    await _tapVisible(find.widgetWithText(TextButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Scan pairing QR'),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    _actionCount++;
    _notificationSink.record(controller.state.preview);
    _disconnectRecoveryPending = true;
  }

  PartnerJourneyObservation observe({
    Map<String, String> visibleAssertions = const <String, String>{},
    Map<String, String> forbiddenMarkers = const <String, String>{},
  }) {
    final latestNotification = _notificationSink.notifications.isEmpty
        ? null
        : _notificationSink.notifications.last;
    final retryAffordanceObserved =
        find.text('Scan pairing QR').evaluate().isNotEmpty;
    if (_disconnectRecoveryPending &&
        !controller.state.paired &&
        retryAffordanceObserved) {
      _recoveryCount++;
      _disconnectRecoveryPending = false;
    }
    return PartnerJourneyObservation(
      surfaceReached: _renderedSurface(),
      pairingOutcomeCode: controller.state.errorCode,
      retryAffordanceObserved: retryAffordanceObserved,
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
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder _navigationDestination(String label) {
    final destination = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    if (destination.evaluate().length != 1) {
      throw StateError('partner_navigation_destination_unreachable');
    }
    return destination;
  }

  String? _renderedSurface() {
    final listViews = find.byType(ListView);
    if (listViews.evaluate().length != 1) return null;
    for (final label in const <String>[
      'Now',
      'Us',
      'Surprise',
      'Shared Health',
    ]) {
      final marker = find.descendant(
        of: listViews,
        matching: find.text(label),
      );
      if (marker.evaluate().length == 1) return label;
    }
    return null;
  }

  List<String> _visibleCardSummaries() => tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map(_cardSummary)
      .whereType<String>()
      .toList();

  String? _cardSummary(ListTile tile) {
    final title = tile.title;
    final subtitle = tile.subtitle;
    if (title is! Text || subtitle is! Text) return null;
    final titleText = title.data;
    final bodyText = subtitle.data;
    if (titleText == null || bodyText == null) return null;

    final kind = switch (titleText) {
      'Right now' => 'roomAction',
      'Relationship weather' => 'weather',
      'Small moment' => 'microMoment',
      'Shared with you' => 'memory',
      'Surprise idea' => 'surprise',
      'Shared health' => 'sharedHealth',
      _ => 'unknown',
    };
    final abstractSeparator = bodyText.indexOf(' · ');
    if (abstractSeparator >= 0) {
      return '$kind|${bodyText.substring(0, abstractSeparator)}|abstractShared';
    }
    final rawSeparator = bodyText.indexOf(': ');
    if (rawSeparator >= 0) {
      return '$kind|${bodyText.substring(0, rawSeparator)}|fullyShared';
    }
    return '$kind|$bodyText|unspecified';
  }
}
