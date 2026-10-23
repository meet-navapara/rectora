/// Web OAuth client from android/app/google-services.json (client_type 3).
///
/// A build can replace it with
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=your-client-id.apps.googleusercontent.com`.
const googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '939327556901-2tnuurkj8ao8t2gssac8ckgar8lutbpn.apps.googleusercontent.com',
);

/// HTTPS origin of the progress service, with no trailing path.
///
/// `--dart-define=RECTORA_SYNC_URL=https://sync.example.com`
///
/// An empty value means progress is not uploaded.
const syncBaseUrl = String.fromEnvironment('RECTORA_SYNC_URL');
