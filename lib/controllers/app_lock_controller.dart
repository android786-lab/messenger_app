import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../services/app_lock_service.dart';

class AppLockController extends ChangeNotifier {
  final AppLockService _appLockService = AppLockService();
  
  bool _isAppLockEnabled = false;
  bool _isDeviceSupported = false;
  bool _hasBiometrics = false;
  List<String> _availableBiometrics = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isDeviceSupported => _isDeviceSupported;
  bool get hasBiometrics => _hasBiometrics;
  List<String> get availableBiometrics => _availableBiometrics;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  // Initialize app lock controller
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _setError(null);
      
      // Check device support
      _isDeviceSupported = await _appLockService.isDeviceSupported();
      
      if (_isDeviceSupported) {
        // Check available biometrics
        var biometrics = await _appLockService.getAvailableBiometrics();
        _availableBiometrics = biometrics.map((b) => _appLockService.getBiometricTypeString(b)).toList();
        _hasBiometrics = await _appLockService.hasAnyBiometrics();
        
        // Check if app lock is enabled
        _isAppLockEnabled = await _appLockService.isAppLockEnabled();
      }
    } catch (e) {
      _setError('Error initializing app lock: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Toggle app lock
  Future<bool> toggleAppLock() async {
    try {
      _setLoading(true);
      _setError(null);
      
      bool newState = !_isAppLockEnabled;
      await _appLockService.setAppLockEnabled(newState);
      _isAppLockEnabled = newState;
      
      return true;
    } catch (e) {
      _setError('Error toggling app lock: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate({
    String reason = 'Authenticate to access the app',
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      
      bool success = await _appLockService.authenticateWithBiometrics(reason: reason);
      return success;
    } catch (e) {
      _setError('Authentication failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Check if re-authentication is needed
  Future<bool> needsReauthentication() async {
    try {
      return await _appLockService.needsReauthentication();
    } catch (e) {
      developer.log('Error checking re-authentication need: $e');
      return true; // Default to requiring authentication on error
    }
  }

  // Get primary biometric type
  String get primaryBiometricType {
    if (_availableBiometrics.isNotEmpty) {
      return _availableBiometrics.first;
    }
    return 'Biometric';
  }

  // Get authentication reason message
  String getAuthenticationReason() {
    if (_availableBiometrics.contains('Face ID')) {
      return 'Authenticate with Face ID to continue';
    } else if (_availableBiometrics.contains('Fingerprint')) {
      return 'Authenticate with Fingerprint to continue';
    } else {
      return 'Authenticate to continue';
    }
  }
}
