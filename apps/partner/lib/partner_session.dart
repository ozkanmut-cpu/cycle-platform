import 'package:cycle_permissions/cycle_permissions.dart';
import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/foundation.dart';

const pairingUnavailable = 'pairing_unavailable';
const pairingMalformed = 'pairing_malformed';
const pairingExpired = 'pairing_expired';
const pairingUnsupportedVersion = 'pairing_unsupported_version';
const pairingScopeMismatch = 'pairing_scope_mismatch';

abstract interface class PairingPayloadSource {
  Future<String?> acquire();
}

class UnavailablePairingPayloadSource implements PairingPayloadSource {
  const UnavailablePairingPayloadSource();

  @override
  Future<String?> acquire() async => null;
}

typedef PartnerNow = DateTime Function();
typedef KeyEnvelopeIdFactory = String Function();

@immutable
class PartnerSessionState {
  const PartnerSessionState({
    this.paired = false,
    this.invitation,
    this.privacyMode = NotificationPrivacyMode.generic,
    this.deviceUnlocked = true,
    this.preview,
    this.errorCode,
    this.notificationsStopped = false,
  });

  final bool paired;
  final PairingInvitation? invitation;
  final NotificationPrivacyMode privacyMode;
  final bool deviceUnlocked;
  final PrivateNotification? preview;
  final String? errorCode;
  final bool notificationsStopped;
}

class PartnerSessionController extends ChangeNotifier {
  PartnerSessionController({
    required String ownerId,
    required String recipientId,
    required PairingPayloadSource payloadSource,
    required PermissionGrant? revocationGrant,
    required RecipientKeyRotator keyRotator,
    Iterable<RelationshipCategoryGrant> notificationGrants = const [],
    RelationshipNotificationRequest? notificationRequest,
    PairingQrCodec pairingCodec = const PairingQrCodec(),
    RelationshipNotificationPipeline notificationPipeline =
        const RelationshipNotificationPipeline(),
    SharingRevocationCoordinator revocationCoordinator =
        const SharingRevocationCoordinator(),
    PartnerNow now = DateTime.now,
  })  : _ownerId = ownerId,
        _recipientId = recipientId,
        _payloadSource = payloadSource,
        _revocationGrant = revocationGrant,
        _keyRotator = keyRotator,
        _notificationGrants = List.unmodifiable(notificationGrants),
        _notificationRequest = notificationRequest,
        _pairingCodec = pairingCodec,
        _notificationPipeline = notificationPipeline,
        _revocationCoordinator = revocationCoordinator,
        _now = now;

  final String _ownerId;
  final String _recipientId;
  final PairingPayloadSource _payloadSource;
  final PermissionGrant? _revocationGrant;
  final RecipientKeyRotator _keyRotator;
  final List<RelationshipCategoryGrant> _notificationGrants;
  final RelationshipNotificationRequest? _notificationRequest;
  final PairingQrCodec _pairingCodec;
  final RelationshipNotificationPipeline _notificationPipeline;
  final SharingRevocationCoordinator _revocationCoordinator;
  final PartnerNow _now;

  PartnerSessionState _state = const PartnerSessionState();
  bool _hasValidatedRelationship = false;

  PartnerSessionState get state => _state;

  Future<void> pair() async {
    final payload = await _payloadSource.acquire();
    if (payload == null) {
      _pairingFailed(pairingUnavailable);
      return;
    }

    final at = _now().toUtc();
    late final PairingInvitation invitation;
    try {
      invitation = _pairingCodec.decode(payload, now: at);
    } on FormatException catch (error) {
      _pairingFailed(_pairingErrorCode(error));
      return;
    }

    if (invitation.ownerId != _ownerId ||
        invitation.recipientId != _recipientId ||
        !_configurationMatches(at)) {
      _pairingFailed(pairingScopeMismatch);
      return;
    }

    _hasValidatedRelationship = true;
    _state = PartnerSessionState(
      paired: true,
      invitation: invitation,
      privacyMode: _state.privacyMode,
      deviceUnlocked: _state.deviceUnlocked,
    );
    notifyListeners();
  }

  void setPrivacyMode(NotificationPrivacyMode mode) {
    _state = PartnerSessionState(
      paired: _state.paired,
      invitation: _state.invitation,
      privacyMode: mode,
      deviceUnlocked: _state.deviceUnlocked,
      preview: _state.preview,
      errorCode: _state.errorCode,
      notificationsStopped: _state.notificationsStopped,
    );
    notifyListeners();
  }

  void setDeviceUnlocked(bool unlocked) {
    _state = PartnerSessionState(
      paired: _state.paired,
      invitation: _state.invitation,
      privacyMode: _state.privacyMode,
      deviceUnlocked: unlocked,
      preview: _state.preview,
      errorCode: _state.errorCode,
      notificationsStopped: _state.notificationsStopped,
    );
    notifyListeners();
  }

  void previewNotification() {
    final request = _notificationRequest;
    final preview = _state.paired && request != null
        ? _notificationPipeline.present(
            request: request,
            mode: _state.privacyMode,
            deviceUnlocked: _state.deviceUnlocked,
            grants: _notificationGrants,
          )
        : null;
    _state = PartnerSessionState(
      paired: _state.paired,
      invitation: _state.invitation,
      privacyMode: _state.privacyMode,
      deviceUnlocked: _state.deviceUnlocked,
      preview: preview,
      errorCode: _state.errorCode,
      notificationsStopped: _state.notificationsStopped,
    );
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (!_hasValidatedRelationship) return;

    final grant = _revocationGrant;
    final result = grant == null
        ? null
        : await _revocationCoordinator.revoke(
            grant: grant,
            keyRotator: _keyRotator,
            at: _now().toUtc(),
          );
    _hasValidatedRelationship = false;
    _state = PartnerSessionState(
      privacyMode: _state.privacyMode,
      deviceUnlocked: _state.deviceUnlocked,
      notificationsStopped: result?.notificationsStopped ?? false,
    );
    notifyListeners();
  }

  bool _configurationMatches(DateTime at) {
    final revocationGrant = _revocationGrant;
    if (revocationGrant != null &&
        (!_matchesActors(
              revocationGrant.ownerId,
              revocationGrant.recipientId,
            ) ||
            !revocationGrant.isActiveAt(at))) {
      return false;
    }

    final notificationRequest = _notificationRequest;
    if (notificationRequest != null &&
        !_matchesActors(
          notificationRequest.ownerId,
          notificationRequest.recipientId,
        )) {
      return false;
    }

    return _notificationGrants.every(
      (grant) => _matchesActors(grant.ownerId, grant.recipientId),
    );
  }

  bool _matchesActors(String ownerId, String recipientId) =>
      ownerId == _ownerId && recipientId == _recipientId;

  void _pairingFailed(String errorCode) {
    _state = PartnerSessionState(
      privacyMode: _state.privacyMode,
      deviceUnlocked: _state.deviceUnlocked,
      errorCode: errorCode,
      notificationsStopped: _state.notificationsStopped,
    );
    notifyListeners();
  }
}

class RegistryRecipientKeyRotator implements RecipientKeyRotator {
  RegistryRecipientKeyRotator({
    required RecipientKeyRegistry registry,
    required KeyEnvelopeIdFactory keyEnvelopeIdFactory,
  })  : _registry = registry,
        _keyEnvelopeIdFactory = keyEnvelopeIdFactory;

  final RecipientKeyRegistry _registry;
  final KeyEnvelopeIdFactory _keyEnvelopeIdFactory;

  @override
  Future<String> rotate({
    required String ownerId,
    required String recipientId,
    required DateTime at,
  }) async {
    final state = _registry.rotate(
      ownerId: ownerId,
      recipientId: recipientId,
      newKeyEnvelopeId: _keyEnvelopeIdFactory(),
      at: at,
    );
    return state.keyEnvelopeId;
  }
}

String _pairingErrorCode(FormatException error) => switch (error.message) {
      'Pairing invitation expired.' => pairingExpired,
      'Unsupported pairing payload version.' => pairingUnsupportedVersion,
      _ => pairingMalformed,
    };
