enum PrivacyClass {
  standard,
  sensitive,
  highlySensitive,
  privateVault,
}

enum ShareAction {
  view,
  notify,
  backup,
  export,
}

class PolicyRef {
  const PolicyRef({
    required this.id,
    required this.version,
  });

  final String id;
  final int version;
}
