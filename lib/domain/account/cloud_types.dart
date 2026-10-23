class CloudRecord {
  const CloudRecord({required this.revision, required this.payload});

  final int revision;
  final String payload;
}

sealed class CloudFetch {
  const CloudFetch();
}

class CloudEmpty extends CloudFetch {
  const CloudEmpty();
}

class CloudFound extends CloudFetch {
  const CloudFound(this.record);

  final CloudRecord record;
}

class CloudUnavailable extends CloudFetch {
  const CloudUnavailable({required this.offline});

  final bool offline;
}

class CloudWrite {
  const CloudWrite({
    required this.ok,
    this.offline = false,
    this.conflict = false,
    this.record,
  });

  final bool ok;
  final bool offline;
  final bool conflict;
  final CloudRecord? record;
}

abstract class ProgressCloud {
  bool get configured;

  Future<CloudFetch> download(String idToken);

  Future<CloudWrite> upload({
    required String idToken,
    required String payload,
    required int baseRevision,
  });

  /// True only when the server confirms the account record is gone.
  Future<bool> deleteAccount(String idToken);
}
