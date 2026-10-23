enum AuthFailure { cancelled, offline, notConfigured, failed }

extension AuthFailureMessage on AuthFailure {
  String get message {
    return switch (this) {
      AuthFailure.cancelled => 'Sign-in cancelled.',
      AuthFailure.offline => 'Internet connection required.',
      AuthFailure.notConfigured => 'Google sign-in is not configured.',
      AuthFailure.failed => 'Authentication failed. Please try again.',
    };
  }
}

/// Identity returned by Google. The ID token is kept in memory for one sync
/// and is never written into the local save.
class GoogleIdentity {
  const GoogleIdentity({
    required this.id,
    required this.idToken,
    this.accessToken,
    this.name,
    this.email,
  });

  final String id;
  final String? idToken;
  final String? accessToken;
  final String? name;
  final String? email;
}

class AuthResult {
  const AuthResult.success(this.identity) : failure = null;

  const AuthResult.failure(this.failure) : identity = null;

  final GoogleIdentity? identity;
  final AuthFailure? failure;
}

abstract class AccountGateway {
  Future<AuthResult> signIn();

  /// Restores a session the user already accepted. A missing session is not
  /// a cancellation.
  Future<AuthResult> restore();

  Future<void> signOut();
}

enum SyncPhase {
  localOnly,
  notConfigured,
  synced,
  syncing,
  offline,
  failed,
  signInToSync,
}

String syncPhaseLabel(SyncPhase phase) {
  return switch (phase) {
    SyncPhase.localOnly => 'Saved on this device only.',
    SyncPhase.notConfigured =>
      'Signed in. Cloud sync is not set up for this build.',
    SyncPhase.synced => 'Signed in and synced.',
    SyncPhase.syncing => 'Syncing.',
    SyncPhase.offline =>
      'Waiting for a connection. Progress stays on this device.',
    SyncPhase.failed => 'Sync failed. Progress stays on this device.',
    SyncPhase.signInToSync => 'Sign in again to sync this account.',
  };
}
