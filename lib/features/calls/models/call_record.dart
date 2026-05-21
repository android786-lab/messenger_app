import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { voice, video }

enum CallStatus { ringing, answered, missed, rejected, ended }

class CallRecord {
  final String callId;
  final String callerId;
  final String calleeId;
  final CallType type;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  CallRecord({
    required this.callId,
    required this.callerId,
    required this.calleeId,
    required this.type,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'callerId': callerId,
        'calleeId': calleeId,
        'type': type.name,
        'status': status.name,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
        'durationSeconds': durationSeconds,
      };

  factory CallRecord.fromMap(Map<String, dynamic> map) {
    CallStatus parseStatus(String? value) {
      switch (value) {
        case 'ringing':
          return CallStatus.ringing;
        case 'answered':
          return CallStatus.answered;
        case 'missed':
          return CallStatus.missed;
        case 'rejected':
          return CallStatus.rejected;
        default:
          return CallStatus.ended;
      }
    }

    return CallRecord(
        callId: map['callId'] ?? '',
        callerId: map['callerId'] ?? '',
        calleeId: map['calleeId'] ?? '',
        type: map['type'] == 'video' ? CallType.video : CallType.voice,
        status: parseStatus(map['status'] as String?),
        startedAt: (map['startedAt'] as Timestamp).toDate(),
        endedAt: map['endedAt'] != null
            ? (map['endedAt'] as Timestamp).toDate()
            : null,
        durationSeconds: map['durationSeconds'] ?? 0,
      );
  }
}
