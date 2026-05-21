import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_dependencies.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;
  StreamSubscription<UserModel?>? _userStreamSub;

  bool get initialized => _initialized;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _errorMessage = v; notifyListeners(); }
  void clearError() { _errorMessage = null; notifyListeners(); }

  // ── Sign up ────────────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      _setLoading(true); _setError(null);
      final user = await _authService.signUpWithEmailAndPassword(
        email: email, password: password, name: name, phone: phone,
      );
      if (user != null) {
        _currentUser = user;
        _startUserStream(user.uid);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) { _setError(e.toString()); return false; }
    finally { _setLoading(false); }
  }

  // ── Sign in ────────────────────────────────────────────────────
  Future<bool> signIn({required String email, required String password}) async {
    try {
      _setLoading(true); _setError(null);
      final user = await _authService.signInWithEmailAndPassword(
        email: email, password: password,
      );
      if (user != null) {
        _currentUser = user;
        _startUserStream(user.uid);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) { _setError(e.toString()); return false; }
    finally { _setLoading(false); }
  }

  // ── Sign out ───────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _userStreamSub?.cancel();
      _userStreamSub = null;
      final uid = _currentUser?.uid;
      AppDependencies.instance.presenceService.stop();
      if (uid != null) {
        await AppDependencies.instance.notificationRepository
            .unregisterDevice(uid);
      }
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) { _setError(e.toString()); }
    finally { _setLoading(false); }
  }

  // ── Initialize from Firebase Auth state ───────────────────────
  // Called once when auth state changes (app start / sign-in / sign-out).
  Future<void> initializeUser(User? firebaseUser) async {
    _userStreamSub?.cancel();
    _userStreamSub = null;

    if (firebaseUser != null) {
      try {
        final userModel = await _authService.getUserById(firebaseUser.uid);
        _currentUser = userModel;
        if (userModel != null) {
          AppDependencies.instance.presenceService.start(firebaseUser.uid);
          await AppDependencies.instance.notificationRepository
              .registerDevice();
          _startUserStream(firebaseUser.uid);
        }
      } catch (e) {
        developer.log('Error initializing user: $e');
      }
    } else {
      _currentUser = null;
    }
    _initialized = true;
    notifyListeners();
  }

  // ── Live user stream ───────────────────────────────────────────
  void _startUserStream(String uid) {
    _userStreamSub?.cancel();
    _userStreamSub = _authService.streamUserById(uid).listen(
      (user) {
        if (user != null) {
          _currentUser = user;
          notifyListeners();
        }
      },
      onError: (e) => developer.log('User stream error: $e'),
    );
  }

  // ── Online status ──────────────────────────────────────────────
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;
    try {
      await _authService.updateUserOnlineStatus(_currentUser!.uid, isOnline);
    } catch (e) {
      developer.log('Error updating online status: $e');
    }
  }

  // ── Search ─────────────────────────────────────────────────────
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      return await _authService.searchUsers(query);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // ── Update profile ─────────────────────────────────────────────
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
    String? about,
  }) async {
    if (_currentUser == null) return false;
    try {
      _setLoading(true); _setError(null);
      final updated = await _authService.updateUserProfile(
        uid: _currentUser!.uid,
        name: name, phone: phone, photoUrl: photoUrl, about: about,
      );
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) { _setError(e.toString()); return false; }
    finally { _setLoading(false); }
  }

  // ── Stream for profile screen ──────────────────────────────────
  Stream<UserModel?> streamCurrentUser() {
    if (_currentUser == null) return Stream.value(null);
    return _authService.streamUserById(_currentUser!.uid);
  }

  @override
  void dispose() {
    _userStreamSub?.cancel();
    super.dispose();
  }
}
