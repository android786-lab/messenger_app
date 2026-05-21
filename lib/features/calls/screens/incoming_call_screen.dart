import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../call_controller.dart';

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({
    super.key,
    required this.signalId,
    required this.callerName,
    required this.roomId,
    required this.isVideo,
    required this.callDocId,
  });

  final String signalId;
  final String callerName;
  final String roomId;
  final bool isVideo;
  final String callDocId;

  @override
  Widget build(BuildContext context) {
    final callController = context.read<CallController>();

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.videocam : Icons.call,
              size: 72,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Incoming video call' : 'Incoming voice call',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundButton(
                  color: Colors.red,
                  icon: Icons.call_end,
                  onTap: () async {
                    await callController.rejectCall(signalId);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                _RoundButton(
                  color: AppTheme.lightPrimaryColor,
                  icon: Icons.call,
                  onTap: () async {
                    final me = context.read<AuthController>().currentUser;
                    if (me == null) return;
                    await callController.acceptCall(
                      context: context,
                      signalId: signalId,
                      roomId: roomId,
                      isVideo: isVideo,
                      callerName: callerName,
                      callDocId: callDocId,
                      currentUserId: me.uid,
                      currentUserName: me.name,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Icon(Icons.call, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
