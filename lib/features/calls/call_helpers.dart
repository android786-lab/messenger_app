import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_dependencies.dart';
import '../../controllers/auth_controller.dart';
import 'call_controller.dart';

/// Starts a voice or video call with configuration checks and user feedback.
Future<void> startCallWithUser({
  required BuildContext context,
  required String targetUserId,
  required String targetUserName,
  required bool isVideo,
}) async {
  if (!AppDependencies.instance.callService.isConfigured) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calls not configured. Add ZEGO_APP_ID and ZEGO_APP_SIGN to .env',
          ),
        ),
      );
    }
    return;
  }

  final auth = context.read<AuthController>();
  final me = auth.currentUser;
  if (me == null) return;

  try {
  final callController = context.read<CallController>();
    if (isVideo) {
      await callController.startVideoCall(
        context: context,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        currentUserId: me.uid,
        currentUserName: me.name,
      );
    } else {
      await callController.startVoiceCall(
        context: context,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
        currentUserId: me.uid,
        currentUserName: me.name,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
