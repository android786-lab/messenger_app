import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/constants/app_constants.dart';

/// Heartbeat-based presence: updates Firestore `isOnline` + `lastSeen`.
class PresenceService with WidgetsBindingObserver {
  PresenceService();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _heartbeatTimer;
  String? _activeUid;
  bool _observerRegistered = false;

  static const _heartbeatInterval = Duration(seconds: 45);
  static const _staleThresholdMinutes = 5;

  void start(String uid) {
    if (_activeUid == uid && _heartbeatTimer != null) return;
    stop();
    _activeUid = uid;
    _setOnline(true);
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _touchLastSeen(uid);
    });
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_activeUid != null) {
      _setOnline(false);
    }
    _activeUid = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        start(uid);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setOnline(false);
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _setOnline(bool online) async {
    final uid = _activeUid ?? _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set(
        {
          'isOnline': online,
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      developer.log('Presence update error: $e');
    }
  }

  Future<void> _touchLastSeen(String uid) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update(
        {'lastSeen': FieldValue.serverTimestamp(), 'isOnline': true},
      );
    } catch (e) {
      developer.log('Presence heartbeat error: $e');
    }
  }

  /// Client-side stale check (also used in UI).
  static bool isUserActuallyOnline({
    required bool isOnlineFlag,
    DateTime? lastSeen,
  }) {
    if (!isOnlineFlag) return false;
    if (lastSeen == null) return isOnlineFlag;
    return DateTime.now().difference(lastSeen).inMinutes < _staleThresholdMinutes;
  }

  void dispose() {
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
    stop();
  }
}
