import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final String type; // 'text', 'image', 'voice', 'file'
  final DateTime timestamp;
  final bool isRead;
  final String status; // 'sent', 'delivered', 'read'
  final String? mediaUrl;
  final int? voiceDuration; // in seconds
  final String? fileName;
  final String? fileSize;
  final String? fileExtension;

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
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  // Create from Firestore document
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
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
    );
  }

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
  }) {
    return MessageModel(
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
    );
  }
}
