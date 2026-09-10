enum NotificationPrivacyMode { generic, categoryOnly, detailedWhenUnlocked }

class PrivateNotification {
  const PrivateNotification({
    required this.title,
    required this.body,
    required this.redacted,
  });

  final String title;
  final String body;
  final bool redacted;
}

class NotificationPrivacyPresenter {
  const NotificationPrivacyPresenter();

  PrivateNotification present({
    required NotificationPrivacyMode mode,
    required String category,
    required String detail,
    required bool deviceUnlocked,
  }) {
    switch (mode) {
      case NotificationPrivacyMode.generic:
        return const PrivateNotification(
          title: 'Cycle',
          body: 'You have a private health update.',
          redacted: true,
        );
      case NotificationPrivacyMode.categoryOnly:
        return PrivateNotification(
          title: 'Cycle',
          body: 'New $category update.',
          redacted: true,
        );
      case NotificationPrivacyMode.detailedWhenUnlocked:
        if (!deviceUnlocked) {
          return const PrivateNotification(
            title: 'Cycle',
            body: 'You have a private health update.',
            redacted: true,
          );
        }
        return PrivateNotification(
          title: 'Cycle · $category',
          body: detail,
          redacted: false,
        );
    }
  }
}
