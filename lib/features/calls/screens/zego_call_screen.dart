import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

/// Full-screen Zego prebuilt call UI (voice or video).
class ZegoCallScreen extends StatelessWidget {
  const ZegoCallScreen({
    super.key,
    required this.appId,
    required this.appSign,
    required this.userId,
    required this.userName,
    required this.callId,
    required this.isVideo,
    required this.inviteeName,
  });

  final int appId;
  final String appSign;
  final String userId;
  final String userName;
  final String callId;
  final bool isVideo;
  final String inviteeName;

  @override
  Widget build(BuildContext context) {
    final config = isVideo
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: appId,
        appSign: appSign,
        userID: userId,
        userName: userName,
        callID: callId,
        config: config,
      ),
    );
  }
}
