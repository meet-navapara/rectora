import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;
import 'package:rectora/domain/account/auth_types.dart';
import 'package:rectora/domain/account/runtime_config.dart';

class GoogleAccountGateway implements AccountGateway {
  GoogleSignIn? _google;

  GoogleSignIn get _client {
    return _google ??= GoogleSignIn(
      scopes: const ['email'],
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
  }

  @override
  Future<AuthResult> signIn() {
    return _read(() => _client.signIn(), cancelledWhenMissing: true);
  }

  @override
  Future<AuthResult> restore() {
    return _read(() => _client.signInSilently(), cancelledWhenMissing: false);
  }

  Future<AuthResult> _read(
    Future<GoogleSignInAccount?> Function() load, {
    required bool cancelledWhenMissing,
  }) async {
    try {
      final account = await load();
      if (account == null) {
        return AuthResult.failure(
          cancelledWhenMissing ? AuthFailure.cancelled : AuthFailure.failed,
        );
      }
      final auth = await account.authentication;
      return AuthResult.success(
        GoogleIdentity(
          id: account.id,
          name: account.displayName,
          email: account.email,
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        ),
      );
    } on PlatformException catch (error) {
      return AuthResult.failure(_map(error));
    } catch (_) {
      return const AuthResult.failure(AuthFailure.failed);
    }
  }

  AuthFailure _map(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = '${error.message ?? ''} ${error.details ?? ''}'
        .toLowerCase();
    if (code.contains('cancel')) return AuthFailure.cancelled;
    if (code.contains('network') ||
        message.contains('network') ||
        message.contains('apiexception: 7')) {
      return AuthFailure.offline;
    }
    if (message.contains('apiexception: 10') ||
        message.contains('developer_error') ||
        message.contains('12500') ||
        message.contains('not configured')) {
      return AuthFailure.notConfigured;
    }
    return AuthFailure.failed;
  }

  @override
  Future<void> signOut() async {
    final client = _google;
    if (client == null) return;
    try {
      await client.signOut();
    } catch (_) {
      // The local account id is cleared by the caller either way.
    }
  }
}
