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
  StreamSubscription? _userSub;

  UserModel? get user => _userModel;
  String? get organizationName => _organizationName;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _userModel != null;
  bool get isPatient => _userModel?.isPatient ?? true;
  bool get isOrgAdmin => _userModel?.isOrgAdmin ?? false;
  bool get isBedAdmin => _userModel?.isBedAdmin ?? false;
  bool get isTestAdmin => _userModel?.isTestAdmin ?? false;
  bool get isHospitalAdmin => _userModel?.isHospitalAdmin ?? false;
  bool get isBloodBankAdmin => _userModel?.isBloodBankAdmin ?? false;
  bool get isAmbulanceAdmin => _userModel?.isAmbulanceAdmin ?? false;
  bool get isSuperAdmin => _userModel?.isSuperAdmin ?? false;
  bool get isProfileComplete =>
      _userModel?.hasUsableContactProfile ?? false;
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
    await _userSub?.cancel();
    _userSub = null;

    if (firebaseUser == null) {
      _userModel = null;
      _organizationName = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await _firestoreService.getDocument(
        'users/${firebaseUser.uid}',
      );

      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        final newUser = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          name: firebaseUser.displayName,
          role: 'patient',
          profileComplete: false,
        );
        await _firestoreService.setDocument(
          'users/${firebaseUser.uid}',
          newUser.toFirestore(),
        );

        _userModel = newUser;
      }

      _listenToUserProfile(firebaseUser.uid);
    } catch (e) {
      debugPrint('Auth state change error: $e');
      _userModel = null;
      _organizationName = null;
    }

    _isLoading = false;
    notifyListeners();
    if (_userModel != null) {
      unawaited(
        _refreshOrganizationName(
          firebaseUser.uid,
          _userModel?.organizationId,
        ),
      );
    }
  }

  void _listenToUserProfile(String uid) {
    _userSub = _firestoreService
        .streamDocument('users/$uid')
        .listen(
          (doc) async {
            if (!doc.exists || _authService.currentUser?.uid != uid) return;

            final updatedUser = UserModel.fromFirestore(doc);
            final organizationChanged =
                updatedUser.organizationId != _userModel?.organizationId;
            _userModel = updatedUser;
            _isLoading = false;
            notifyListeners();

            if (organizationChanged || _organizationName == null) {
              unawaited(
                _refreshOrganizationName(uid, updatedUser.organizationId),
              );
            }
          },
          onError: (Object error) {
            debugPrint('User profile listener error: $error');
          },
        );
  }

  Future<void> _refreshOrganizationName(
    String uid,
    String? organizationId,
  ) async {
    String? organizationName;
    try {
      if (organizationId != null) {
        final orgDoc = await _firestoreService.getDocument(
          'organizations/$organizationId',
        );
        if (orgDoc.exists) {
          final data = orgDoc.data() as Map<String, dynamic>?;
          organizationName = data?['name'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Organization name load error: $e');
      return;
    }

    if (_authService.currentUser?.uid == uid &&
        _userModel?.organizationId == organizationId &&
        _organizationName != organizationName) {
      _organizationName = organizationName;
      notifyListeners();
    }
  }

  // ── Google Sign-In ──

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        // Defensive: signInWithPopup normally throws rather than returning
        // null, but reset the loading state just in case.
        _isLoading = false;
        notifyListeners();
      }
      // On success, _onAuthStateChanged handles loading state
      return result != null;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      // The user closing the popup or a duplicate request isn't a real
      // failure — don't nag them with an error message.
      if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request' &&
          e.code != 'user-cancelled') {
        _error = _mapAuthError(e.code);
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Google sign-in failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Email + Password ──

  Future<bool> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
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
        final newUser = UserModel(
          uid: credential.user!.uid,
          email: email.trim(),
          name: name.trim(),
          role: 'patient',
          profileComplete: false,
        );
        await _firestoreService.setDocument(
          'users/${credential.user!.uid}',
          newUser.toFirestore(),
        );

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

  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    if (_userModel == null) {
      throw StateError('No authenticated user profile is available.');
    }
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final cleanedPhone = trimmedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final complete = trimmedName.length >= 2 &&
        trimmedName.length <= 80 &&
        RegExp(r'^\+?\d{10,15}$').hasMatch(cleanedPhone);
    if (!complete) {
      throw ArgumentError('Enter a valid name and phone number.');
    }

    await _firestoreService.updateDocument('users/${_userModel!.uid}', {
      'name': trimmedName,
      'phone': trimmedPhone,
      'profile_complete': complete,
    });

    _userModel = _userModel!.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
      profileComplete: complete,
    );
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_userModel == null) return;
    final doc = await _firestoreService.getDocument('users/${_userModel!.uid}');
    if (doc.exists) {
      _userModel = UserModel.fromFirestore(doc);
      notifyListeners();
      await _refreshOrganizationName(
        _userModel!.uid,
        _userModel?.organizationId,
      );
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
      case 'popup-blocked':
        return 'The sign-in popup was blocked by your browser. Please allow popups and try again.';
      case 'unauthorized-domain':
        return 'This domain isn\'t authorized for sign-in. Contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      case 'operation-not-allowed':
        return 'Google sign-in isn\'t enabled for this app. Contact support.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
