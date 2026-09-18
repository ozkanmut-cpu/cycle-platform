import 'package:cycle_sharing/cycle_sharing.dart';
import 'package:flutter/material.dart';

class NotificationPrivacyPreview extends StatelessWidget {
  const NotificationPrivacyPreview({
    super.key,
    required this.notification,
  });

  final PrivateNotification notification;

  @override
  Widget build(BuildContext context) => Semantics(
        label: notification.redacted ? 'Redacted' : 'Detailed',
        container: true,
        explicitChildNodes: true,
        child: Card(
          child: ListTile(
            title: Text(notification.title),
            subtitle: Text(notification.body),
          ),
        ),
      );
}
