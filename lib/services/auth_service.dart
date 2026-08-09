import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Google Sign-In ──

  Future<UserCredential?> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    // Let errors propagate so the caller can distinguish a user-cancelled
    // popup from a real failure (config error, blocked popup, etc.) and
    // surface a meaningful message instead of silently returning null.
    return await _auth.signInWithPopup(provider);
  }

  // ── Email + Password ──

  Future<UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
