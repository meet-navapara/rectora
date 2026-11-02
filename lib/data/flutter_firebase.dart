import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rectora/domain/account/account_binder.dart';
import 'package:rectora/domain/account/cloud_types.dart';
import 'package:rectora/domain/account/firebase_start.dart';

const firebaseBuildEnabled = bool.fromEnvironment(
  'RECTORA_FIREBASE',
  defaultValue: true,
);

Future<FirebaseStart> startFlutterFirebase() {
  return startFirebase(
    enabled: firebaseBuildEnabled,
    initialize: Firebase.initializeApp,
  );
}

class FirebaseAccountBinder extends AccountBinder {
  const FirebaseAccountBinder();

  @override
  Future<bool> bind(String? idToken, {String? accessToken}) async {
    final hasId = idToken != null && idToken.isNotEmpty;
    final hasAccess = accessToken != null && accessToken.isNotEmpty;
    if (Firebase.apps.isEmpty || (!hasId && !hasAccess)) return false;
    try {
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: hasId ? idToken : null,
          accessToken: hasAccess ? accessToken : null,
        ),
      );
      final user = FirebaseAuth.instance.currentUser;
      return user != null && user.uid.isNotEmpty;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> unbind() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Local sign-out still proceeds when Firebase is unreachable.
    }
  }
}

class FirestoreProgressCloud implements ProgressCloud {
  const FirestoreProgressCloud();

  @override
  bool get configured => Firebase.apps.isNotEmpty;

  DocumentReference<Map<String, dynamic>>? get _progress {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('gameProgress')
        .doc('primary');
  }

  @override
  Future<CloudFetch> download(String idToken) async {
    final progress = _progress;
    if (!configured || progress == null) {
      return const CloudUnavailable(offline: false);
    }
    try {
      final snap = await progress.get();
      final data = snap.data();
      final payload = data?['payload'];
      if (!snap.exists || payload is! String || payload.isEmpty) {
        return const CloudEmpty();
      }
      final revision = data?['revision'];
      return CloudFound(
        CloudRecord(revision: revision is int ? revision : 0, payload: payload),
      );
    } on FirebaseException catch (error) {
      return CloudUnavailable(offline: _offline(error.code));
    } catch (_) {
      return const CloudUnavailable(offline: false);
    }
  }

  @override
  Future<CloudWrite> upload({
    required String idToken,
    required String payload,
    required int baseRevision,
  }) async {
    final progress = _progress;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!configured || progress == null || uid == null) {
      return const CloudWrite(ok: false);
    }
    try {
      final revision = await FirebaseFirestore.instance.runTransaction<int>((
        transaction,
      ) async {
        final snap = await transaction.get(progress);
        final current = snap.data()?['revision'];
        final stored = current is int ? current : 0;
        final remotePayload = snap.data()?['payload'];
        if (snap.exists && stored != baseRevision) {
          throw _RevisionConflict(
            stored,
            remotePayload is String ? remotePayload : '',
          );
        }
        final next = stored + 1;
        transaction.set(progress, {
          'schemaVersion': 1,
          'payload': payload,
          'revision': next,
        });
        transaction.set(
          FirebaseFirestore.instance.collection('users').doc(uid),
          {'schemaVersion': 1, 'lastSyncAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        return next;
      });
      return CloudWrite(
        ok: true,
        record: CloudRecord(revision: revision, payload: payload),
      );
    } on _RevisionConflict catch (conflict) {
      return CloudWrite(
        ok: false,
        conflict: true,
        record: CloudRecord(
          revision: conflict.revision,
          payload: conflict.payload,
        ),
      );
    } on FirebaseException catch (error) {
      return CloudWrite(ok: false, offline: _offline(error.code));
    } catch (_) {
      return const CloudWrite(ok: false);
    }
  }

  @override
  Future<bool> deleteAccount(String idToken) async {
    final progress = _progress;
    final user = FirebaseAuth.instance.currentUser;
    if (!configured || progress == null || user == null) return false;
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(progress);
      batch.delete(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
      );
      // A write waits forever without a connection, so give it a limit.
      await batch.commit().timeout(const Duration(seconds: 15));
      await user.delete();
      return true;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _offline(String code) {
    return code == 'unavailable' || code == 'network-request-failed';
  }
}

class _RevisionConflict implements Exception {
  _RevisionConflict(this.revision, this.payload);

  final int revision;
  final String payload;
}
