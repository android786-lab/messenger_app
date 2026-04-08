import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageType;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount; // userId -> count
  final bool isGroup;
  final String? groupName;
  final String? groupPhotoUrl;
  final bool isPinned;
  final bool isArchived;
  final bool isFavorite;
  final bool isLocked;
  final DateTime? pinnedTime;

  ChatModel({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.isGroup = false,
    this.groupName,
    this.groupPhotoUrl,
    this.isPinned = false,
    this.isArchived = false,
    this.isFavorite = false,
    this.isLocked = false,
    this.pinnedTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isFavorite': isFavorite,
      'isLocked': isLocked,
      'pinnedTime': pinnedTime != null ? Timestamp.fromDate(pinnedTime!) : null,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      chatId: map['chatId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageType: map['lastMessageType'] ?? 'text',
      lastMessageTime: (map['lastMessageTime'] as Timestamp).toDate(),
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      groupPhotoUrl: map['groupPhotoUrl'],
      isPinned: map['isPinned'] ?? false,
      isArchived: map['isArchived'] ?? false,
      isFavorite: map['isFavorite'] ?? false,
      isLocked: map['isLocked'] ?? false,
      pinnedTime: map['pinnedTime'] != null
          ? (map['pinnedTime'] as Timestamp).toDate()
          : null,
    );
  }

  ChatModel copyWith({
    String? chatId,
    List<String>? participants,
    String? lastMessage,
    String? lastMessageType,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    Map<String, int>? unreadCount,
    bool? isGroup,
    String? groupName,
    String? groupPhotoUrl,
    bool? isPinned,
    bool? isArchived,
    bool? isFavorite,
    bool? isLocked,
    DateTime? pinnedTime,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupPhotoUrl: groupPhotoUrl ?? this.groupPhotoUrl,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      isLocked: isLocked ?? this.isLocked,
      pinnedTime: pinnedTime ?? this.pinnedTime,
    );
  }
}
