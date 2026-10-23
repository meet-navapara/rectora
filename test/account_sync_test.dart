import 'package:flutter_test/flutter_test.dart';
import 'package:rectora/data/key_value_store.dart';
import 'package:rectora/domain/account/auth_types.dart';
import 'package:rectora/domain/account/cloud_types.dart';
import 'package:rectora/domain/campaign/catalog.dart';
import 'package:rectora/domain/campaign/save_game.dart';
import 'package:rectora/domain/parcels/models.dart';
import 'package:rectora/domain/progression/rewards.dart';
import 'package:rectora/ui/controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a guest starts without calling Google', () async {
    final auth = ScriptAuth(const AuthResult.failure(AuthFailure.failed));
    final cloud = MemoryCloud();
    final controller = await _open(auth: auth, cloud: cloud);
    expect(controller.save.isGuest, isTrue);
    expect(auth.signIns, 0);
    expect(auth.restores, 0);
    expect(controller.syncPhase, SyncPhase.localOnly);

    await controller.finishLevel(
      id: 'parcel-001',
      skipped: false,
      hintsUsed: 0,
      elapsedMs: 1000,
    );
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
    expect(cloud.uploads, 0);
  });

  test('cancelling sign-in keeps the guest save', () async {
    final auth = ScriptAuth(const AuthResult.failure(AuthFailure.cancelled));
    final cloud = MemoryCloud();
    final controller = await _open(
      auth: auth,
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.save.isGuest, isTrue);
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
    expect(controller.accountMessage, 'Sign-in cancelled.');
    expect(cloud.uploads, 0);
  });

  test('a failed sign-in keeps the guest save', () async {
    final auth = ScriptAuth(const AuthResult.failure(AuthFailure.failed));
    final controller = await _open(auth: auth, cloud: MemoryCloud());
    await controller.signInWithGoogle();
    expect(controller.save.isGuest, isTrue);
    expect(
      controller.accountMessage,
      'Authentication failed. Please try again.',
    );
  });

  test('an unconfigured Google client is reported plainly', () async {
    final auth = ScriptAuth(
      const AuthResult.failure(AuthFailure.notConfigured),
    );
    final controller = await _open(auth: auth, cloud: MemoryCloud());
    await controller.signInWithGoogle();
    expect(controller.accountMessage, 'Google sign-in is not configured.');
    expect(controller.save.isGuest, isTrue);
  });

  test('sign-in without a sync server stays local', () async {
    final auth = ScriptAuth(_identity);
    final cloud = MemoryCloud(configured: false);
    final controller = await _open(
      auth: auth,
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.save.isGoogle, isTrue);
    expect(controller.save.accountEmail, 'ada@example.com');
    expect(controller.save.parcelRecords['parcel-001'], isNull);
    expect(controller.syncPhase, SyncPhase.notConfigured);
    expect(cloud.uploads, 0);
    expect(cloud.downloads, 0);
    await controller.signOutAccount();
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
  });

  test('a new Google account uploads its own progress', () async {
    final cloud = MemoryCloud();
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.syncPhase, SyncPhase.synced);
    expect(controller.save.lastSyncAt, isNotNull);
    expect(controller.save.needsSync, isFalse);
    final stored = decodeSave(cloud.payload);
    expect(stored.parcelRecords.containsKey('parcel-001'), isFalse);
    expect(stored.accountPlayerId, 'google-1');
    await controller.signOutAccount();
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
  });

  test('an empty device does not erase an existing cloud save', () async {
    final remote = _solved('parcel-002')
        .copyWith(accountKind: 'google', accountPlayerId: 'google-1');
    final cloud = MemoryCloud()
      ..payload = remote.encode()
      ..revision = 2;
    final controller = await _open(auth: ScriptAuth(_identity), cloud: cloud);
    await controller.signInWithGoogle();
    expect(controller.save.parcelRecords['parcel-002']!.solved, isTrue);
    expect(
      decodeSave(cloud.payload).parcelRecords['parcel-002']!.solved,
      isTrue,
    );
  });

  test(
    'cloud progress stays with Google and guest progress stays with guest',
    () async {
      final remote = _solved(
        'parcel-002',
        hints: 1,
      ).copyWith(accountKind: 'google', accountPlayerId: 'google-1');
      final cloud = MemoryCloud()
        ..payload = remote.encode()
        ..revision = 4;
      final controller = await _open(
        auth: ScriptAuth(_identity),
        cloud: cloud,
        initial: _solved('parcel-001'),
      );
      await controller.signInWithGoogle();
      expect(controller.save.parcelRecords.containsKey('parcel-001'), isFalse);
      expect(controller.save.parcelRecords['parcel-002']!.solved, isTrue);
      final once = controller.save.xp;
      expect(once, masteryXp(Difficulty.hard, perfect: false));
      await controller.syncNow();
      expect(controller.save.xp, once);
      await controller.signOutAccount();
      expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
      expect(controller.save.parcelRecords.containsKey('parcel-002'), isFalse);
    },
  );

  test('a cloud record for someone else is not applied', () async {
    final remote = _solved('parcel-002')
        .copyWith(accountKind: 'google', accountPlayerId: 'other');
    final cloud = MemoryCloud()
      ..payload = remote.encode()
      ..revision = 1;
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.save.parcelRecords.containsKey('parcel-002'), isFalse);
    expect(controller.save.parcelRecords.containsKey('parcel-001'), isFalse);
    expect(cloud.uploads, 0);
    expect(controller.accountMessage, contains('did not match'));
  });

  test('offline sync retries without dropping local progress', () async {
    final cloud = MemoryCloud()..offline = true;
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.syncPhase, SyncPhase.offline);
    expect(controller.save.parcelRecords.containsKey('parcel-001'), isFalse);
    expect(cloud.uploads, 0);
    expect(controller.accountMessage, contains('Internet connection required'));
    cloud.offline = false;
    await controller.syncNow();
    expect(controller.syncPhase, SyncPhase.synced);
    expect(
      decodeSave(cloud.payload).parcelRecords.containsKey('parcel-001'),
      isFalse,
    );
    await controller.signOutAccount();
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
  });

  test('a revision conflict keeps both solves', () async {
    final remote = _solved('parcel-002')
        .copyWith(accountKind: 'google', accountPlayerId: 'google-1');
    final cloud = MemoryCloud()
      ..scripted.add(
        CloudWrite(
          ok: false,
          conflict: true,
          record: CloudRecord(revision: 3, payload: remote.encode()),
        ),
      )
      ..scripted.add(
        const CloudWrite(
          ok: true,
          record: CloudRecord(revision: 4, payload: '{}'),
        ),
      );
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    expect(controller.syncPhase, SyncPhase.synced);
    expect(controller.save.parcelRecords.containsKey('parcel-001'), isFalse);
    expect(controller.save.parcelRecords['parcel-002']!.solved, isTrue);
    expect(cloud.uploads, 2);
  });

  test('sign-out keeps solved levels on the device', () async {
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: MemoryCloud(),
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    await controller.signOutAccount();
    expect(controller.save.isGuest, isTrue);
    expect(controller.save.accountEmail, isNull);
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
    expect(controller.syncPhase, SyncPhase.localOnly);
  });

  test('a refused account deletion does not clear local progress', () async {
    final cloud = MemoryCloud()..allowDelete = false;
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: cloud,
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    await controller.deleteAccount();
    expect(controller.save.isGoogle, isTrue);
    expect(controller.accountMessage, contains('could not be deleted'));
    await controller.signOutAccount();
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
  });

  test('removing the saved user record keeps the Google login', () async {
    final controller = await _open(
      auth: ScriptAuth(_identity),
      cloud: MemoryCloud(),
      initial: _solved('parcel-001'),
    );
    await controller.signInWithGoogle();
    await controller.deleteAccount();
    expect(controller.save.isGoogle, isTrue);
    expect(controller.save.accountPlayerId, 'google-1');
    expect(controller.accountMessage, contains('login is unchanged'));
    await controller.signOutAccount();
    expect(controller.save.parcelRecords['parcel-001']!.solved, isTrue);
  });
}

final _identity = const AuthResult.success(
  GoogleIdentity(
    id: 'google-1',
    name: 'Ada',
    email: 'ada@example.com',
    idToken: 'token-1',
  ),
);

SaveGame _solved(String id, {int hints = 0}) {
  return SaveGame.fresh().finishLevel(
    id: id,
    skipped: false,
    hintsUsed: hints,
    elapsedMs: 1000,
  );
}

Future<RectoraController> _open({
  required ScriptAuth auth,
  required MemoryCloud cloud,
  SaveGame? initial,
}) async {
  final store = MemoryStore();
  if (initial != null) await store.write(saveKey, initial.encode());
  final controller = RectoraController(
    catalog: _catalog(),
    store: store,
    accounts: auth,
    cloud: cloud,
    clock: () => DateTime.utc(2026, 10, 22, 9),
  );
  await controller.bootstrap();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return controller;
}

GameCatalog _catalog() {
  ParcelLevel parcel(int number, Difficulty difficulty) {
    return ParcelLevel(
      id: 'parcel-${number.toString().padLeft(3, '0')}',
      number: number,
      packId: 'first-light',
      packName: 'First Light',
      packBlurb: 'Small boards.',
      title: 'Parcel $number',
      difficulty: difficulty,
      milestone: false,
      puzzle: const ParcelPuzzle(rows: 2, cols: 2, clues: [Clue(0, 0, 4)]),
      solution: const [GridRect(0, 0, 1, 1)],
    );
  }

  return GameCatalog(
    parcels: [parcel(1, Difficulty.easy), parcel(2, Difficulty.hard)],
    threads: const [],
    daily: [parcel(1, Difficulty.easy)],
  );
}

class ScriptAuth implements AccountGateway {
  ScriptAuth(this.result);

  AuthResult result;
  int signIns = 0;
  int restores = 0;

  @override
  Future<AuthResult> signIn() async {
    signIns++;
    return result;
  }

  @override
  Future<AuthResult> restore() async {
    restores++;
    return const AuthResult.failure(AuthFailure.failed);
  }

  @override
  Future<void> signOut() async {}
}

class MemoryCloud implements ProgressCloud {
  MemoryCloud({this.configured = true});

  @override
  bool configured;
  bool offline = false;
  bool allowDelete = true;
  String? payload;
  int revision = 0;
  int uploads = 0;
  int downloads = 0;
  final List<CloudWrite> scripted = [];

  @override
  Future<CloudFetch> download(String idToken) async {
    downloads++;
    if (idToken.isEmpty) return const CloudUnavailable(offline: false);
    if (offline) return const CloudUnavailable(offline: true);
    if (payload == null) return const CloudEmpty();
    return CloudFound(CloudRecord(revision: revision, payload: payload!));
  }

  @override
  Future<CloudWrite> upload({
    required String idToken,
    required String payload,
    required int baseRevision,
  }) async {
    uploads++;
    if (scripted.isNotEmpty) return scripted.removeAt(0);
    if (offline) return const CloudWrite(ok: false, offline: true);
    revision += 1;
    this.payload = payload;
    return CloudWrite(
      ok: true,
      record: CloudRecord(revision: revision, payload: payload),
    );
  }

  @override
  Future<bool> deleteAccount(String idToken) async {
    if (!allowDelete || offline) return false;
    payload = null;
    return true;
  }
}
