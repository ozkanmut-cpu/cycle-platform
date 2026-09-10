import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CyclePartnerApp());
}

class CyclePartnerApp extends StatelessWidget {
  const CyclePartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle Partner',
      theme: ThemeData(useMaterial3: true),
      home: const PartnerHomePage(),
    );
  }
}

class PartnerHomePage extends StatefulWidget {
  const PartnerHomePage({super.key});

  @override
  State<PartnerHomePage> createState() => _PartnerHomePageState();
}

class _PartnerHomePageState extends State<PartnerHomePage> {
  bool _paired = false;
  NotificationPrivacyMode _privacyMode = NotificationPrivacyMode.generic;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Trusted sharing',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Only information explicitly shared with you is visible. Sharing permissions remain controlled by the owner.',
            ),
            const SizedBox(height: 24),
            _Panel(
              title: 'QR pairing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _paired
                        ? 'Paired with a trusted health record.'
                        : 'Scan a time-limited pairing QR to connect.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() => _paired = !_paired),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(_paired ? 'Disconnect demo' : 'Scan pairing QR'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Panel(
              title: 'Independent permissions',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('VIEW')),
                  Chip(label: Text('NOTIFY')),
                  Chip(label: Text('BACKUP')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Panel(
              title: 'Encrypted transport',
              child: Text(
                'Shared records and blind backups use recipient-scoped key envelopes. Relay infrastructure receives opaque encrypted payloads only.',
              ),
            ),
            const SizedBox(height: 16),
            _Panel(
              title: 'Private notifications',
              child: DropdownButton<NotificationPrivacyMode>(
                value: _privacyMode,
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
                  if (mode != null) setState(() => _privacyMode = mode);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _privacyLabel(NotificationPrivacyMode mode) {
  switch (mode) {
    case NotificationPrivacyMode.generic:
      return 'Generic';
    case NotificationPrivacyMode.categoryOnly:
      return 'Category only';
    case NotificationPrivacyMode.detailedWhenUnlocked:
      return 'Detailed when unlocked';
  }
}
