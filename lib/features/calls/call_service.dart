import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../config/env_config.dart';
import 'models/call_record.dart';
import 'screens/zego_call_screen.dart';

class CallService {
  bool _initialized = false;

  bool get isConfigured => EnvConfig.isZegoConfigured;

  Future<void> initialize() async {
    if (_initialized || !isConfigured) return;
    _initialized = true;
  }

  /// Deterministic room ID for 1:1 calls.
  static String roomIdForUsers(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return 'call_${ids[0]}_${ids[1]}';
  }

  Future<void> startCall({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String currentUserId,
    required String currentUserName,
    required bool isVideo,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Zego is not configured. Add ZEGO_APP_ID and ZEGO_APP_SIGN to .env',
      );
    }

    final roomId = roomIdForUsers(currentUserId, targetUserId);
    final callId = FirebaseFirestore.instance.collection('calls').doc().id;

    await _createCallRecord(
      callId: callId,
      callerId: currentUserId,
      calleeId: targetUserId,
      type: isVideo ? CallType.video : CallType.voice,
    );

    await _sendCallSignal(
      calleeId: targetUserId,
      callerId: currentUserId,
      callerName: currentUserName,
      roomId: roomId,
      isVideo: isVideo,
      callId: callId,
    );

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZegoCallScreen(
          appId: EnvConfig.zegoAppId,
          appSign: EnvConfig.zegoAppSign,
          userId: currentUserId,
          userName: currentUserName,
          callId: roomId,
          isVideo: isVideo,
          inviteeName: targetUserName,
        ),
      ),
    );

    await _endCallRecord(callId, CallStatus.ended);
  }

  Future<void> joinIncomingCall({
    required BuildContext context,
    required String roomId,
    required String currentUserId,
    required String currentUserName,
    required bool isVideo,
    required String callerName,
    required String callDocId,
  }) async {
    if (!isConfigured) {
      throw Exception('Zego is not configured');
    }

    await _updateCallStatus(callDocId, CallStatus.answered);

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZegoCallScreen(
          appId: EnvConfig.zegoAppId,
          appSign: EnvConfig.zegoAppSign,
          userId: currentUserId,
          userName: currentUserName,
          callId: roomId,
          isVideo: isVideo,
          inviteeName: callerName,
        ),
      ),
    );

    await _endCallRecord(callDocId, CallStatus.ended);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> listenIncomingCalls(String uid) {
    return FirebaseFirestore.instance
        .collection('call_signals')
        .where('calleeId', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  Stream<List<CallRecord>> callHistory(String uid) {
    return FirebaseFirestore.instance
        .collection('calls')
        .where('participants', arrayContains: uid)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CallRecord.fromMap({...d.data(), 'callId': d.id}))
            .toList());
  }

  Future<void> _createCallRecord({
    required String callId,
    required String callerId,
    required String calleeId,
    required CallType type,
  }) async {
    final record = CallRecord(
      callId: callId,
      callerId: callerId,
      calleeId: calleeId,
      type: type,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
    );
    await FirebaseFirestore.instance.collection('calls').doc(callId).set({
      ...record.toMap(),
      'participants': [callerId, calleeId],
    });
  }

  Future<void> _endCallRecord(String callId, CallStatus status) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('calls').doc(callId).get();
      if (!doc.exists) return;
      final started = (doc.data()?['startedAt'] as Timestamp?)?.toDate();
      final duration = started != null
          ? DateTime.now().difference(started).inSeconds
          : 0;
      await doc.reference.update({
        'status': status.name,
        'endedAt': FieldValue.serverTimestamp(),
        'durationSeconds': duration,
      });
    } catch (e) {
      developer.log('End call record error: $e');
    }
  }

  Future<void> _updateCallStatus(String callId, CallStatus status) async {
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'status': status.name,
    });
  }

  Future<void> _sendCallSignal({
    required String calleeId,
    required String callerId,
    required String callerName,
    required String roomId,
    required bool isVideo,
    required String callId,
  }) async {
    await FirebaseFirestore.instance.collection('call_signals').doc(callId).set({
      'callId': callId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callerName': callerName,
      'roomId': roomId,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> dismissCallSignal(String signalId) async {
    await FirebaseFirestore.instance
        .collection('call_signals')
        .doc(signalId)
        .update({'status': 'dismissed'});
  }
}
