import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  bool get initialized => _initialized;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Auth state stream
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      UserModel? user = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign in
  Future<bool> signIn({required String email, required String password}) async {
    try {
      _setLoading(true);
      _setError(null);

      UserModel? user = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _authService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Initialize user from auth state
  Future<void> initializeUser(User? user) async {
    if (user != null) {
      try {
        UserModel? userModel = await _authService.getUserById(user.uid);
        _currentUser = userModel;
      } catch (e) {
        developer.log('Error initializing user: $e');
      }
    } else {
      _currentUser = null;
    }
    _initialized = true;
    notifyListeners();
  }

  // Update user online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (_currentUser != null) {
      try {
        await _authService.updateUserOnlineStatus(_currentUser!.uid, isOnline);
        _currentUser = _currentUser!.copyWith(
          isOnline: isOnline,
          lastSeen: DateTime.now(),
        );
        notifyListeners();
      } catch (e) {
        developer.log('Error updating online status: $e');
      }
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers(String email) async {
    try {
      return await _authService.searchUsersByEmail(email);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);
      _setError(null);

      UserModel? updatedUser = await _authService.updateUserProfile(
        uid: _currentUser!.uid,
        name: name,
        phone: phone,
        photoUrl: photoUrl,
      );

      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Stream current user for real-time updates
  Stream<UserModel?> streamCurrentUser() {
    if (_currentUser == null) return Stream.value(null);
    return _authService.streamUserById(_currentUser!.uid);
  }
}
