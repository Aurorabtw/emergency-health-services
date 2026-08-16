import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../shared/utils/validators.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  String? _organizationName;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;
  int _authGeneration = 0;

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
      (_userModel?.profileComplete ?? false) &&
      (_userModel?.hasUsableContactProfile ?? false);
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
    final generation = ++_authGeneration;
    await _userSub?.cancel();
    if (generation != _authGeneration) return;
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
      if (!_isCurrentAuthRequest(firebaseUser.uid, generation)) return;

      if (doc.exists) {
        _userModel = UserModel.fromFirestore(doc);
      } else {
        if (!_isNewFirebaseAccount(firebaseUser)) {
          await _rejectCurrentSession(
            'This account does not have an active platform profile. Contact support.',
            generation,
          );
          return;
        }
        await _ensureNewUserProfile(
          firebaseUser,
          preferredName: firebaseUser.displayName,
        );
        if (!_isCurrentAuthRequest(firebaseUser.uid, generation)) return;
        final createdProfile = await _firestoreService.getDocument(
          'users/${firebaseUser.uid}',
        );
        if (!createdProfile.exists) {
          throw StateError('The new user profile could not be created.');
        }
        _userModel = UserModel.fromFirestore(createdProfile);
      }

      if (_userModel!.accessRevoked) {
        await _rejectCurrentSession(
          'Your platform access has been revoked. Contact support.',
          generation,
        );
        return;
      }

      _listenToUserProfile(firebaseUser.uid, generation);
    } catch (e) {
      if (!_isCurrentAuthRequest(firebaseUser.uid, generation)) return;
      debugPrint('Auth state change error: $e');
      _userModel = null;
      _organizationName = null;
    }

    if (!_isCurrentAuthRequest(firebaseUser.uid, generation)) return;
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

  void _listenToUserProfile(String uid, int generation) {
    _userSub = _firestoreService
        .streamDocument('users/$uid')
        .listen(
          (doc) async {
            if (!_isCurrentAuthRequest(uid, generation)) return;
            if (!doc.exists) {
              await _rejectCurrentSession(
                'This account does not have an active platform profile. Contact support.',
                generation,
              );
              return;
            }

            final updatedUser = UserModel.fromFirestore(doc);
            if (updatedUser.accessRevoked) {
              await _rejectCurrentSession(
                'Your platform access has been revoked. Contact support.',
                generation,
              );
              return;
            }
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
        await _ensureNewUserProfile(
          credential.user!,
          preferredName: name,
        );
        final profile = await _firestoreService.getDocument(
          'users/${credential.user!.uid}',
        );
        _userModel = UserModel.fromFirestore(profile);
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
    final cleanedPhone = Validators.normalizePhone(phone);
    final complete = trimmedName.length >= 2 &&
        trimmedName.length <= 80 &&
        RegExp(r'^\+?\d{10,15}$').hasMatch(cleanedPhone);
    if (!complete) {
      throw ArgumentError('Enter a valid name and phone number.');
    }

    await _firestoreService.updateDocument('users/${_userModel!.uid}', {
      'name': trimmedName,
      'phone': cleanedPhone,
      'profile_complete': complete,
    });

    _userModel = _userModel!.copyWith(
      name: trimmedName,
      phone: cleanedPhone,
      profileComplete: complete,
    );
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_userModel == null) return;
    final uid = _userModel!.uid;
    final generation = _authGeneration;
    final doc = await _firestoreService.getDocument('users/$uid');
    if (!_isCurrentAuthRequest(uid, generation)) return;
    if (!doc.exists) {
      await _rejectCurrentSession(
        'This account does not have an active platform profile. Contact support.',
        generation,
      );
      return;
    }
    final refreshedUser = UserModel.fromFirestore(doc);
    if (refreshedUser.accessRevoked) {
      await _rejectCurrentSession(
        'Your platform access has been revoked. Contact support.',
        generation,
      );
      return;
    }
    _userModel = refreshedUser;
    if (_isCurrentAuthRequest(uid, generation)) {
      notifyListeners();
      await _refreshOrganizationName(
        uid,
        _userModel?.organizationId,
      );
    }
  }

  // ── Helpers ──

  bool _isCurrentAuthRequest(String uid, int generation) {
    return generation == _authGeneration &&
        _authService.currentUser?.uid == uid;
  }

  bool _isNewFirebaseAccount(User user) {
    final createdAt = user.metadata.creationTime;
    final lastSignIn = user.metadata.lastSignInTime;
    if (createdAt == null || lastSignIn == null) return false;
    return lastSignIn.difference(createdAt).abs() < const Duration(seconds: 5);
  }

  Future<void> _ensureNewUserProfile(
    User firebaseUser, {
    String? preferredName,
  }) async {
    final trimmedName = preferredName?.trim();
    final validName = trimmedName != null &&
            trimmedName.length >= 2 &&
            trimmedName.length <= 80
        ? trimmedName
        : null;
    final userRef = _firestoreService.db.doc('users/${firebaseUser.uid}');
    await _firestoreService.runTransaction((transaction) async {
      final current = await transaction.get(userRef);
      if (!current.exists) {
        transaction.set(
          userRef,
          UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: validName,
            role: 'patient',
            profileComplete: false,
          ).toFirestore(),
        );
      } else if (validName != null && current.data()?['name'] != validName) {
        transaction.update(userRef, {'name': validName});
      }
    });
  }

  Future<void> _rejectCurrentSession(String message, int generation) async {
    if (generation != _authGeneration) return;
    _error = message;
    _userModel = null;
    _organizationName = null;
    _isLoading = false;
    notifyListeners();
    await _authService.signOut();
  }

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
