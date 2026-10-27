import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

const googleWebClientId = '455512342228-xxxx.apps.googleusercontent.com'; // điền web client ID của bạn từ Firebase Console

class AccountError implements Exception {
  const AccountError(this.message);

  final String message;

  @override
  String toString() => message;
}

String authMessage(String code) => switch (code) {
  'invalid-email' => 'Email không hợp lệ.',
  'email-already-in-use' ||
  'credential-already-in-use' => 'Email này đã có tài khoản. Chọn "Đăng nhập" để vào tài khoản đó.',
  'weak-password' => 'Mật khẩu cần ít nhất 6 ký tự.',
  'invalid-credential' || 'wrong-password' || 'user-not-found' => 'Email hoặc mật khẩu không đúng.',
  'user-disabled' => 'Tài khoản này đã bị khoá.',
  'too-many-requests' => 'Thử quá nhiều lần, đợi một lát rồi thử lại.',
  'network-request-failed' => 'Không có mạng. Kiểm tra kết nối rồi thử lại.',
  'operation-not-allowed' => 'Cách đăng nhập này chưa được bật trong Firebase Console.',
  'web-context-canceled' || 'canceled' => 'Đã huỷ đăng nhập.',
  'provider-already-linked' => 'Tài khoản đã được liên kết rồi.',
  _ => 'Không thực hiện được, thử lại nhé.',
};

class AccountStore extends ChangeNotifier {
  AccountStore(this._auth) : _user = _auth.currentUser {
    // userChanges, not authStateChanges: linking an email keeps the same user, and only
    // userChanges reports it.
    _subscription = _auth.userChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  final FirebaseAuth _auth;
  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _googleReady = false;

  /// A guest until an email or Google is linked; also while signing in for the first time.
  bool get isGuest => _user?.isAnonymous ?? true;

  String? get email => _user?.email;

  /// Guest → account with email and password, keeping the guest's log.
  Future<void> register(String email, String password) => _run(() async {
    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
    } else {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    }
  });

  /// An account made earlier. The guest's log on this phone stays with the guest.
  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  /// Google: the phone's own account picker, then links that account to the guest, or signs in
  /// to the Vitalize account it already belongs to.
  Future<void> continueWithGoogle() async {
    final credential = GoogleAuthProvider.credential(idToken: await _googleIdToken());
    await _run(() async {
      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        try {
          await user.linkWithCredential(credential);
          return;
        } on FirebaseAuthException catch (e) {
          if (e.code != 'credential-already-in-use') rethrow;
          // This Google account already has a Vitalize account: sign in to it instead.
        }
      }
      await _auth.signInWithCredential(credential);
    });
  }

  /// Picks a Google account on the phone (Credential Manager) and returns its ID token.
  Future<String?> _googleIdToken() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await google.initialize(serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final account = await google.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      debugPrint('Google: ${e.code} ${e.description}');
      throw AccountError(
        e.code == GoogleSignInExceptionCode.canceled
            ? 'Đã huỷ đăng nhập Google.'
            : 'Không đăng nhập Google được, thử lại nhé.',
      );
    }
  }

  Future<void> resetPassword(String email) =>
      _run(() => _auth.sendPasswordResetEmail(email: email));

  Future<void> signOut() => _run(() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  });

  Future<void> _run(Future<void> Function() work) async {
    try {
      await work();
    } on FirebaseAuthException catch (e) {
      debugPrint('Account: ${e.code} ${e.message}');
      throw AccountError(authMessage(e.code));
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
