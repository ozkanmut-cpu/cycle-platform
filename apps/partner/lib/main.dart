import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CyclePartnerApp());
}

class CyclePartnerApp extends StatelessWidget {
  const CyclePartnerApp({
    super.key,
    this.experienceInput,
    this.homeModel,
    this.coordinator = const PartnerExperienceCoordinator(),
  });

  final PartnerExperienceInput? experienceInput;
  final RelationshipHomeModel? homeModel;
  final PartnerExperienceCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle Partner',
      theme: ThemeData(useMaterial3: true),
      home: PartnerHomePage(
        experienceInput: experienceInput,
        homeModel: homeModel,
        coordinator: coordinator,
      ),
    );
  }
}

class PartnerHomePage extends StatefulWidget {
  const PartnerHomePage({
    super.key,
    this.experienceInput,
    this.homeModel,
    this.coordinator = const PartnerExperienceCoordinator(),
  });

  final PartnerExperienceInput? experienceInput;
  final RelationshipHomeModel? homeModel;
  final PartnerExperienceCoordinator coordinator;

  @override
  State<PartnerHomePage> createState() => _PartnerHomePageState();
}

class _PartnerHomePageState extends State<PartnerHomePage> {
  int _selectedIndex = 0;
  bool _paired = false;
  NotificationPrivacyMode _privacyMode = NotificationPrivacyMode.generic;

  RelationshipHomeModel get _model {
    final input = widget.experienceInput;
    if (input != null) return widget.coordinator.build(input);
    return widget.homeModel ?? RelationshipHomeModel(cards: const []);
  }

  @override
  Widget build(BuildContext context) {
    final tab = RelationshipHomeTab.values[_selectedIndex];
    final cards = _model.cardsFor(tab).where(_partnerVisibleCard).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Partner'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('Read-only')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (!_paired) ...[
              _PairingBanner(onPair: () => setState(() => _paired = true)),
              const SizedBox(height: 16),
            ],
            Text(
              _title(tab),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(_subtitle(tab)),
            const SizedBox(height: 18),
            if (cards.isEmpty)
              _EmptyState(tab: tab)
            else
              ...cards.map((card) => _RelationshipCard(card: card)),
            if (tab == RelationshipHomeTab.us) ...[
              const SizedBox(height: 8),
              _SharingControls(
                paired: _paired,
                privacyMode: _privacyMode,
                onPrivacyChanged: (mode) => setState(() => _privacyMode = mode),
                onDisconnect:
                    _paired ? () => setState(() => _paired = false) : null,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.bolt_outlined), label: 'Now'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Us'),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            label: 'Surprise',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            label: 'Shared Health',
          ),
        ],
      ),
    );
  }
}

class _PairingBanner extends StatelessWidget {
  const _PairingBanner({required this.onPair});

  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect securely',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Scan a time-limited pairing QR. Only explicitly shared information can appear here.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onPair,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan pairing QR'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final RelationshipHomeTab tab;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _emptyTitle(tab),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_emptyBody(tab)),
            ],
          ),
        ),
      );
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.card});

  final RelationshipHomeCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_icon(card.kind)),
        title: Text(_cardTitle(card)),
        subtitle: Text(_cardBody(card)),
      ),
    );
  }
}

class _SharingControls extends StatelessWidget {
  const _SharingControls({
    required this.paired,
    required this.privacyMode,
    required this.onPrivacyChanged,
    this.onDisconnect,
  });

  final bool paired;
  final NotificationPrivacyMode privacyMode;
  final ValueChanged<NotificationPrivacyMode> onPrivacyChanged;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sharing controls',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text('VIEW')),
                  Chip(label: Text('NOTIFY')),
                  Chip(label: Text('BACKUP')),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Private notifications'),
              DropdownButton<NotificationPrivacyMode>(
                value: privacyMode,
                isExpanded: true,
                items: NotificationPrivacyMode.values
                    .map(
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(_privacyLabel(mode)),
                      ),
                    )
                    .toList(),
                onChanged: (mode) {
                  if (mode != null) onPrivacyChanged(mode);
                },
              ),
              if (paired)
                TextButton.icon(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect demo'),
                ),
            ],
          ),
        ),
      );
}

String _title(RelationshipHomeTab tab) => switch (tab) {
      RelationshipHomeTab.now => 'Now',
      RelationshipHomeTab.us => 'Us',
      RelationshipHomeTab.surprise => 'Surprise',
      RelationshipHomeTab.sharedHealth => 'Shared Health',
    };

String _subtitle(RelationshipHomeTab tab) => switch (tab) {
      RelationshipHomeTab.now =>
        'Useful right-now context and low-burden actions.',
      RelationshipHomeTab.us =>
        'Shared relationship context, preferences and memories.',
      RelationshipHomeTab.surprise =>
        'Only safe, permitted ideas worth surfacing.',
      RelationshipHomeTab.sharedHealth =>
        'Only health information explicitly shared for viewing.',
    };

String _emptyTitle(RelationshipHomeTab tab) => switch (tab) {
      RelationshipHomeTab.now => 'Nothing to surface right now',
      RelationshipHomeTab.us => 'Nothing shared here right now',
      RelationshipHomeTab.surprise => 'No suggestion right now',
      RelationshipHomeTab.sharedHealth => 'No shared health details to show',
    };

String _emptyBody(RelationshipHomeTab tab) => switch (tab) {
      RelationshipHomeTab.now =>
        'Cycle stays quiet when there is no timely, useful partner action.',
      RelationshipHomeTab.us =>
        'Private and engine-only context stays hidden. This screen does not reveal whether other context exists.',
      RelationshipHomeTab.surprise =>
        'Cycle will not invent a suggestion just to fill the screen.',
      RelationshipHomeTab.sharedHealth =>
        'This does not indicate whether health data exists. Only partner-visible VIEW data appears here.',
    };

IconData _icon(RelationshipHomeCardKind kind) => switch (kind) {
      RelationshipHomeCardKind.roomAction => Icons.touch_app_outlined,
      RelationshipHomeCardKind.weather => Icons.wb_cloudy_outlined,
      RelationshipHomeCardKind.microMoment => Icons.flash_on_outlined,
      RelationshipHomeCardKind.memory => Icons.bookmark_border,
      RelationshipHomeCardKind.surprise => Icons.auto_awesome_outlined,
      RelationshipHomeCardKind.sharedHealth => Icons.health_and_safety_outlined,
    };

String _cardTitle(RelationshipHomeCard card) => switch (card.kind) {
      RelationshipHomeCardKind.roomAction => 'Right now',
      RelationshipHomeCardKind.weather => 'Relationship weather',
      RelationshipHomeCardKind.microMoment => 'Small moment',
      RelationshipHomeCardKind.memory => 'Shared with you',
      RelationshipHomeCardKind.surprise => 'Surprise idea',
      RelationshipHomeCardKind.sharedHealth => 'Shared health',
    };

String _cardBody(RelationshipHomeCard card) {
  if (card.rawValue != null) return '${card.reference}: ${card.rawValue}';
  if (card.visibility == RelationshipVisibility.abstractShared) {
    return '${card.reference} · shared without raw detail';
  }
  return card.reference;
}

String _privacyLabel(NotificationPrivacyMode mode) => switch (mode) {
      NotificationPrivacyMode.generic => 'Generic',
      NotificationPrivacyMode.categoryOnly => 'Category only',
      NotificationPrivacyMode.detailedWhenUnlocked => 'Detailed when unlocked',
    };

bool _partnerVisibleCard(RelationshipHomeCard card) {
  if (card.kind != RelationshipHomeCardKind.memory &&
      card.kind != RelationshipHomeCardKind.sharedHealth) {
    return true;
  }
  return card.visibility == RelationshipVisibility.abstractShared ||
      card.visibility == RelationshipVisibility.fullyShared;
}
