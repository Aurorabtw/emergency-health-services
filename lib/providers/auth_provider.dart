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

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
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

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();
      final result = await _authService.signInWithGoogle();
      return result != null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    notifyListeners();
  }

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

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
