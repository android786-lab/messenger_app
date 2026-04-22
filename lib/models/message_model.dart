import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyInfo {
  final String messageId;
  final String senderName;
  final String content;
  final String type;

  ReplyInfo({
    required this.messageId,
    required this.senderName,
    required this.content,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderName': senderName,
        'content': content,
        'type': type,
      };

  factory ReplyInfo.fromMap(Map<String, dynamic> map) => ReplyInfo(
        messageId: map['messageId'] ?? '',
        senderName: map['senderName'] ?? '',
        content: map['content'] ?? '',
        type: map['type'] ?? 'text',
      );
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final String type; // 'text', 'image', 'voice', 'file', 'deleted'
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'sent', 'delivered', 'read'
  final String? mediaUrl;
  final int? voiceDuration;
  final String? fileName;
  final String? fileSize;
  final String? fileExtension;
  final bool isPinned;
  final bool isStarred;
  final List<String> deletedFor;
  final ReplyInfo? replyTo;
  final String? forwardedFrom;
  final Map<String, List<String>> reactions; // emoji -> [userIds]
  final DateTime? expiresAt; // disappearing messages

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.status = 'sent',
    this.mediaUrl,
    this.voiceDuration,
    this.fileName,
    this.fileSize,
    this.fileExtension,
    this.isPinned = false,
    this.isStarred = false,
    this.deletedFor = const [],
    this.replyTo,
    this.forwardedFrom,
    this.reactions = const {},
    this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'type': type,
        'timestamp': Timestamp.fromDate(timestamp),
        'isRead': isRead,
        'status': status,
        'mediaUrl': mediaUrl,
        'voiceDuration': voiceDuration,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileExtension': fileExtension,
        'isPinned': isPinned,
        'isStarred': isStarred,
        'deletedFor': deletedFor,
        'replyTo': replyTo?.toMap(),
        'forwardedFrom': forwardedFrom,
        'reactions': reactions.map((k, v) => MapEntry(k, v)),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
        messageId: map['messageId'] ?? '',
        senderId: map['senderId'] ?? '',
        senderName: map['senderName'] ?? '',
        content: map['content'] ?? '',
        type: map['type'] ?? 'text',
        timestamp: (map['timestamp'] as Timestamp).toDate(),
        isRead: map['isRead'] ?? false,
        status: map['status'] ?? 'sent',
        mediaUrl: map['mediaUrl'],
        voiceDuration: map['voiceDuration'],
        fileName: map['fileName'],
        fileSize: map['fileSize'],
        fileExtension: map['fileExtension'],
        isPinned: map['isPinned'] ?? false,
        isStarred: map['isStarred'] ?? false,
        deletedFor: List<String>.from(map['deletedFor'] ?? []),
        replyTo: map['replyTo'] != null
            ? ReplyInfo.fromMap(map['replyTo'] as Map<String, dynamic>)
            : null,
        forwardedFrom: map['forwardedFrom'],
        reactions: (map['reactions'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ),
        expiresAt: map['expiresAt'] != null
            ? (map['expiresAt'] as Timestamp).toDate()
            : null,
      );

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? content,
    String? type,
    DateTime? timestamp,
    bool? isRead,
    String? status,
    String? mediaUrl,
    int? voiceDuration,
    String? fileName,
    String? fileSize,
    String? fileExtension,
    bool? isPinned,
    bool? isStarred,
    List<String>? deletedFor,
    ReplyInfo? replyTo,
    String? forwardedFrom,
    Map<String, List<String>>? reactions,
    DateTime? expiresAt,
  }) =>
      MessageModel(
        messageId: messageId ?? this.messageId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        content: content ?? this.content,
        type: type ?? this.type,
        timestamp: timestamp ?? this.timestamp,
        isRead: isRead ?? this.isRead,
        status: status ?? this.status,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        voiceDuration: voiceDuration ?? this.voiceDuration,
        fileName: fileName ?? this.fileName,
        fileSize: fileSize ?? this.fileSize,
        fileExtension: fileExtension ?? this.fileExtension,
        isPinned: isPinned ?? this.isPinned,
        isStarred: isStarred ?? this.isStarred,
        deletedFor: deletedFor ?? this.deletedFor,
        replyTo: replyTo ?? this.replyTo,
        forwardedFrom: forwardedFrom ?? this.forwardedFrom,
        reactions: reactions ?? this.reactions,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}
