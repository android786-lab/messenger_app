import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService {
  static const String _appLockEnabledKey = 'app_lock_enabled';
  static const String _lastAuthTimeKey = 'last_auth_time';
  static const int _authTimeoutMinutes = 5; // Auto-lock after 5 minutes

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      developer.log('Error checking device support: $e');
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      developer.log('Error getting available biometrics: $e');
      return [];
    }
  }

  // Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_appLockEnabledKey) ?? false;
    } catch (e) {
      developer.log('Error checking app lock status: $e');
      return false;
    }
  }

  // Enable/disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_appLockEnabledKey, enabled);

      if (enabled) {
        // Set last auth time when enabling
        await _updateLastAuthTime();
      } else {
        // Clear last auth time when disabling
        await prefs.remove(_lastAuthTimeKey);
      }
    } catch (e) {
      throw Exception('Error setting app lock: ${e.toString()}');
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Authenticate to access the app',
    bool useBiometricOnly = true,
  }) async {
    try {
      bool isAuthenticated = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: useBiometricOnly,
      );

      if (isAuthenticated) {
        await _updateLastAuthTime();
      }

      return isAuthenticated;
    } on PlatformException catch (e) {
      developer.log('Authentication error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      developer.log('Unexpected authentication error: $e');
      return false;
    }
  }

  // Check if re-authentication is needed
  Future<bool> needsReauthentication() async {
    try {
      if (!await isAppLockEnabled()) {
        return false;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? lastAuthTime = prefs.getInt(_lastAuthTimeKey);

      if (lastAuthTime == null) {
        return true;
      }

      DateTime lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
      DateTime now = DateTime.now();

      // Check if more than timeout minutes have passed
      return now.difference(lastAuth).inMinutes >= _authTimeoutMinutes;
    } catch (e) {
      developer.log('Error checking re-authentication need: $e');
      return true; // Default to requiring authentication on error
    }
  }

  // Update last authentication time
  Future<void> _updateLastAuthTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastAuthTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      developer.log('Error updating last auth time: $e');
    }
  }

  // Get biometric type string for display
  String getBiometricTypeString(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.iris:
        return 'Iris Scanner';
      case BiometricType.weak:
        return 'Device Unlock';
      default:
        return 'Biometric';
    }
  }

  // Check if any biometrics are available
  Future<bool> hasAnyBiometrics() async {
    try {
      List<BiometricType> availableBiometrics = await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      developer.log('Error checking biometrics availability: $e');
      return false;
    }
  }
}
