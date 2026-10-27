import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef UserDoc = DocumentReference<Map<String, dynamic>>;

/// The signed-in user's document, `users/{uid}`: the profile is a field on it, the log lives in
/// its `sets`, `sessions` and `meals` collections (see firestore.rules).
///
/// There are no accounts to make: the app signs in anonymously, so every install gets its own
/// user id and the rules keep each user to their own data. Signing in needs the network once;
/// without it this keeps retrying, and the stores hold their writes until it succeeds.
Future<UserDoc> signIn(FirebaseAuth auth, FirebaseFirestore db) async {
  for (var wait = 2; ; wait = math.min(wait * 2, 60)) {
    try {
      // The user from the last launch, once Firebase has restored it.
      var user = await auth.authStateChanges().first;
      if (user == null) {
        user = (await auth.signInAnonymously()).user!;
        // The user's own document, so it shows in the console next to its collections.
        db
            .collection('users')
            .doc(user.uid)
            .set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))
            .catchError((Object e) => debugPrint('Creating the user document failed: $e'));
      }
      return db.collection('users').doc(user.uid);
    } catch (e) {
      // Offline, mostly (network-request-failed).
      debugPrint('Signing in failed, trying again in $wait s: $e');
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }
}

StreamSubscription<User?> watchUserSwitch(
  FirebaseAuth auth,
  FirebaseFirestore db,
  void Function(Future<UserDoc> user) onSwitch,
) {
  var uid = auth.currentUser?.uid;
  return auth.authStateChanges().listen((user) {
    if (user == null) {
      // Signed out: carry on as a new guest.
      if (uid != null) onSwitch(signIn(auth, db));
    } else if (uid != null && user.uid != uid) {
      onSwitch(Future.value(db.collection('users').doc(user.uid)));
    }
    uid = user?.uid;
  });
}
