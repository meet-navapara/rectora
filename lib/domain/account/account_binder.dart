/// Links the current Google sign-in to Firebase Authentication.
///
/// The default binder does nothing, so guest play and the HTTP sync client
/// keep their existing behavior.
abstract class AccountBinder {
  const AccountBinder();

  Future<bool> bind(String? idToken, {String? accessToken});

  Future<void> unbind();
}

class NoAccountBinder extends AccountBinder {
  const NoAccountBinder();

  @override
  Future<bool> bind(String? idToken, {String? accessToken}) async => false;

  @override
  Future<void> unbind() async {}
}
