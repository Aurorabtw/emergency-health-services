import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  String? _organizationName;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _authSub;

  UserModel? get user => _userModel;
  String? get organizationName => _organizationName;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _userModel != null;
  bool get isPatient => _userModel?.isPatient ?? true;
  bool get isOrgAdmin => _userModel?.isOrgAdmin ?? false;
  bool get isHospitalAdmin => _userModel?.isHospitalAdmin ?? false;
  bool get isBloodBankAdmin => _userModel?.isBloodBankAdmin ?? false;
  bool get isAmbulanceAdmin => _userModel?.isAmbulanceAdmin ?? false;
  bool get isSuperAdmin => _userModel?.isSuperAdmin ?? false;
  bool get isProfileComplete => _userModel?.profileComplete ?? false;
  String? get error => _error;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _userModel = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await _firestoreService.getDocument('users/${firebaseUser.uid}');

      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        final configDoc = await _firestoreService.getDocument('config/platform');
        final isFirstUser = !configDoc.exists;

        final role = isFirstUser ? 'super_admin' : 'patient';
        final newUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName,
          role: role,
          profileComplete: firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty,
        );
        await _firestoreService.setDocument('users/${firebaseUser.uid}', newUser.toFirestore());

        if (isFirstUser) {
          await _firestoreService.setDocument('config/platform', {
            'initialized': true,
            'initialized_by': firebaseUser.uid,
            'initialized_at': DateTime.now().toIso8601String(),
          });
        }

        _userModel = newUser;
      }

      _organizationName = null;
      if (_userModel?.organizationId != null) {
        final orgDoc = await _firestoreService.getDocument('organizations/${_userModel!.organizationId}');
        if (orgDoc.exists) {
          final data = orgDoc.data() as Map<String, dynamic>?;
          _organizationName = data?['name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Auth state change error: $e');
      _userModel = null;
      _organizationName = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Google Sign-In ──

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        // User cancelled the popup — reset loading state
        _isLoading = false;
        notifyListeners();
      }
      // On success, _onAuthStateChanged handles loading state
      return result != null;
    } catch (e) {
      _isLoading = false;
      _error = 'Google sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Email + Password ──

  Future<bool> registerWithEmail(String email, String password, String name) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _authService.registerWithEmail(email, password);

      // Update Firebase Auth display name
      await credential.user?.updateDisplayName(name);

      // Create Firestore user doc (will be picked up by _onAuthStateChanged,
      // but we set name + profileComplete here since we have the name)
      if (credential.user != null) {
        final configDoc = await _firestoreService.getDocument('config/platform');
        final isFirstUser = !configDoc.exists;
        final role = isFirstUser ? 'super_admin' : 'patient';

        final newUser = UserModel(
          uid: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
          role: role,
          profileComplete: name.trim().isNotEmpty,
        );
        await _firestoreService.setDocument('users/${credential.user!.uid}', newUser.toFirestore());

        if (isFirstUser) {
          await _firestoreService.setDocument('config/platform', {
            'initialized': true,
            'initialized_by': credential.user!.uid,
            'initialized_at': DateTime.now().toIso8601String(),
          });
        }

        _userModel = newUser;
        _isLoading = false;
        notifyListeners();
      }

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _error = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Registration failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(email, password);
      // _onAuthStateChanged will handle loading the user
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _error = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _error = _mapAuthError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to send reset email. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    notifyListeners();
  }

  // ── Profile ──

  Future<void> updateProfile({required String name, required String phone}) async {
    if (_userModel == null) return;

    await _firestoreService.updateDocument('users/${_userModel!.uid}', {
      'name': name,
      'phone': phone,
      'profile_complete': true,
    });

    _userModel = _userModel!.copyWith(
      name: name,
      phone: phone,
      profileComplete: true,
    );
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_userModel == null) return;
    final doc = await _firestoreService.getDocument('users/${_userModel!.uid}');
    if (doc.exists) {
      _userModel = UserModel.fromFirestore(doc);
      notifyListeners();
    }
  }

  // ── Helpers ──

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Try registering instead.';
      case 'wrong-password':
        return 'Incorrect password. Try again or reset your password.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
