import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

/// The user's red flags and past checks, stored under `users/{uid}`.
class RedFlagProfile {
  const RedFlagProfile({this.redFlags = const [], this.customFlags = const []});

  final List<String> redFlags;
  final List<String> customFlags;

  bool get isEmpty => redFlags.isEmpty && customFlags.isEmpty;
}

class ProfileService {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('users').doc(_uid);

  Future<RedFlagProfile> load() async {
    final snapshot = await _doc.get();
    final data = snapshot.data() ?? const {};
    return RedFlagProfile(
      redFlags: List<String>.from(data['redFlags'] as List? ?? const []),
      customFlags: List<String>.from(data['customFlags'] as List? ?? const []),
    );
  }

  Future<void> save(RedFlagProfile profile) => _doc.set({
    'redFlags': profile.redFlags,
    'customFlags': profile.customFlags,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Past checks, newest first.
  Stream<List<CheckResult>> history() => _doc
      .collection('checks')
      .orderBy('checkedAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (query) => [
          for (final doc in query.docs)
            CheckResult.fromMap({
              ...doc.data(),
              'checkedAt': (doc.data()['checkedAt'] as Timestamp?)?.toDate(),
            }),
        ],
      );
}
