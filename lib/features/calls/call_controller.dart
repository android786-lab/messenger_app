import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_dependencies.dart';
import 'call_service.dart';
import 'models/call_record.dart';
import 'screens/incoming_call_screen.dart';

class CallController extends ChangeNotifier {
  CallController() : _callService = AppDependencies.instance.callService;

  final CallService _callService;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;
  bool _handlingIncoming = false;

  bool get isCallConfigured => _callService.isConfigured;

  void listenForIncomingCalls(BuildContext context, String uid) {
    _incomingSub?.cancel();
    if (!_callService.isConfigured) return;

    _incomingSub = _callService.listenIncomingCalls(uid).listen((snap) {
      if (_handlingIncoming || snap.docs.isEmpty || !context.mounted) return;
      final doc = snap.docs.first;
      final data = doc.data();
      if (data['status'] != 'ringing') return;

      _handlingIncoming = true;
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => IncomingCallScreen(
            signalId: doc.id,
            callerName: data['callerName'] as String? ?? 'Unknown',
            roomId: data['roomId'] as String? ?? '',
            isVideo: data['isVideo'] as bool? ?? false,
            callDocId: data['callId'] as String? ?? doc.id,
          ),
        ),
      )
          .then((_) => _handlingIncoming = false);
    });
  }

  void stopListening() {
    _incomingSub?.cancel();
    _incomingSub = null;
  }

  Future<void> startVoiceCall({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String currentUserId,
    required String currentUserName,
  }) =>
      _callService.startCall(
        context: context,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        isVideo: false,
      );

  Future<void> startVideoCall({
    required BuildContext context,
    required String targetUserId,
    required String targetUserName,
    required String currentUserId,
    required String currentUserName,
  }) =>
      _callService.startCall(
        context: context,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        isVideo: true,
      );

  Future<void> acceptCall({
    required BuildContext context,
    required String signalId,
    required String roomId,
    required bool isVideo,
    required String callerName,
    required String callDocId,
    required String currentUserId,
    required String currentUserName,
  }) async {
    await _callService.dismissCallSignal(signalId);
    await _callService.joinIncomingCall(
      context: context,
      roomId: roomId,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      isVideo: isVideo,
      callerName: callerName,
      callDocId: callDocId,
    );
  }

  Future<void> rejectCall(String signalId) async {
    await _callService.dismissCallSignal(signalId);
  }

  Stream<List<CallRecord>> callHistory(String uid) =>
      _callService.callHistory(uid);

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
