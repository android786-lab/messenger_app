import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int defaultMessagePageSize = 40;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Get or create chat between two users
  Future<String> getOrCreateChat(String otherUserId) async {
    try {
      // Create chat ID by sorting user IDs
      List<String> participants = [currentUserId, otherUserId];
      participants.sort();
      String chatId = participants.join('_');

      // Check if chat already exists
      DocumentSnapshot chatDoc = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        // Create new chat
        ChatModel newChat = ChatModel(
          chatId: chatId,
          participants: participants,
          lastMessage: '',
          lastMessageType: AppConstants.textMessage,
          lastMessageTime: DateTime.now(),
          lastMessageSenderId: '',
          unreadCount: {currentUserId: 0, otherUserId: 0},
          isGroup: false,
        );

        await _firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatId)
            .set(newChat.toMap());
      }

      return chatId;
    } catch (e) {
      throw Exception('Error creating chat: ${e.toString()}');
    }
  }

  // Send text message
  Future<void> sendMessage({
    required String chatId,
    required String content,
    required String senderName,
    String type = 'text',
    String? mediaUrl,
    int? voiceDuration,
    String? fileName,
    String? fileSize,
    String? fileExtension,
  }) async {
    try {
      String messageId = _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc()
          .id;

      final chatDoc = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();
      final disappearingSeconds =
          (chatDoc.data()?['disappearingSeconds'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      final expiresAt = disappearingSeconds > 0
          ? now.add(Duration(seconds: disappearingSeconds))
          : null;

      MessageModel message = MessageModel(
        messageId: messageId,
        senderId: currentUserId,
        senderName: senderName,
        content: content,
        type: type,
        timestamp: now,
        mediaUrl: mediaUrl,
        voiceDuration: voiceDuration,
        fileName: fileName,
        fileSize: fileSize,
        fileExtension: fileExtension,
        expiresAt: expiresAt,
      );

      // Add message to subcollection
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .set(message.toMap());

      // Update chat's last message
      await updateChatLastMessage(chatId, message);
    } catch (e) {
      throw Exception('Error sending message: ${e.toString()}');
    }
  }

  // Update chat's last message info — direct update, no read needed
  Future<void> updateChatLastMessage(
    String chatId,
    MessageModel message,
  ) async {
    try {
      // Fetch only the participants + unreadCount fields we need
      final chatDoc = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!chatDoc.exists) return;

      final data = chatDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      final rawUnread = Map<String, dynamic>.from(data['unreadCount'] ?? {});
      final unreadCount = rawUnread.map(
          (k, v) => MapEntry(k, (v as num).toInt()));

      // Increment unread for everyone except the sender
      final updates = <String, dynamic>{
        'lastMessage': message.content,
        'lastMessageType': message.type,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
        'lastMessageSenderId': message.senderId,
      };
      for (final uid in participants) {
        if (uid != currentUserId) {
          updates['unreadCount.$uid'] =
              (unreadCount[uid] ?? 0) + 1;
        }
      }

      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update(updates);
    } catch (e) {
      developer.log('Error updating last message: $e');
    }
  }

  // Get user's chats stream
  Stream<List<ChatModel>> getUserChats() {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Real-time stream for the most recent page (efficient listener)
  Stream<List<MessageModel>> getChatMessages(
    String chatId, {
    int limit = defaultMessagePageSize,
  }) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Older messages for infinite scroll (before [beforeTimestamp]).
  Future<List<MessageModel>> loadOlderMessages(
    String chatId, {
    required DateTime beforeTimestamp,
    int limit = defaultMessagePageSize,
  }) async {
    final snap = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(beforeTimestamp)])
        .limit(limit)
        .get();

    return snap.docs.map((d) => MessageModel.fromMap(d.data())).toList();
  }

  // Mark messages as read — uses batch write for performance
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      // Reset unread counter
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'unreadCount.$currentUserId': 0});

      // Batch-update message statuses
      final snap = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      if (snap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['senderId'] != currentUserId) {
          batch.update(doc.reference, {'status': 'read', 'isRead': true});
        }
      }
      await batch.commit();
    } catch (e) {
      developer.log('Error marking messages as read: $e');
    }
  }

  // Create group chat
  Future<String> createGroupChat({
    required String groupName,
    required List<String> memberIds,
    String? groupPhotoUrl,
  }) async {
    try {
      String chatId = _firestore
          .collection(AppConstants.chatsCollection)
          .doc()
          .id;

      List<String> allMembers = [currentUserId, ...memberIds];
      Map<String, int> unreadCount = {};
      for (String memberId in allMembers) {
        unreadCount[memberId] = 0;
      }

      ChatModel groupChat = ChatModel(
        chatId: chatId,
        participants: allMembers,
        lastMessage: '',
        lastMessageType: AppConstants.textMessage,
        lastMessageTime: DateTime.now(),
        lastMessageSenderId: '',
        unreadCount: unreadCount,
        isGroup: true,
        groupName: groupName,
        groupPhotoUrl: groupPhotoUrl,
        admins: [currentUserId],
        createdBy: currentUserId,
      );

      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .set(groupChat.toMap());

      return chatId;
    } catch (e) {
      throw Exception('Error creating group chat: ${e.toString()}');
    }
  }

  // Add member to group
  Future<void> addMemberToGroup(String chatId, String memberId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'participants': FieldValue.arrayUnion([memberId]),
            'unreadCount.$memberId': 0,
          });
    } catch (e) {
      throw Exception('Error adding member: ${e.toString()}');
    }
  }

  // Remove member from group
  Future<void> removeMemberFromGroup(String chatId, String memberId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'participants': FieldValue.arrayRemove([memberId]),
            'unreadCount.$memberId': FieldValue.delete(),
          });
    } catch (e) {
      throw Exception('Error removing member: ${e.toString()}');
    }
  }

  // Update chat pin status
  Future<void> updateChatPinStatus(String chatId, bool isPinned) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'isPinned': isPinned,
            'pinnedTime': isPinned
                ? Timestamp.fromDate(DateTime.now())
                : FieldValue.delete(),
          });
    } catch (e) {
      throw Exception('Error updating pin status: ${e.toString()}');
    }
  }

  // Update chat archive status
  Future<void> updateChatArchiveStatus(String chatId, bool isArchived) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'isArchived': isArchived});
    } catch (e) {
      throw Exception('Error updating archive status: ${e.toString()}');
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      QuerySnapshot messagesSnapshot = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .get();

      for (DocumentSnapshot doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the chat document
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting chat: ${e.toString()}');
    }
  }

  // Mark chat as read for specific user
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'unreadCount.$userId': 0});
    } catch (e) {
      throw Exception('Error marking chat as read: ${e.toString()}');
    }
  }

  // Mark chat as unread for specific user
  Future<void> markChatAsUnread(String chatId, String userId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'unreadCount.$userId': 1});
    } catch (e) {
      throw Exception('Error marking chat as unread: ${e.toString()}');
    }
  }

  // Update chat lock status
  Future<void> updateChatLockStatus(String chatId, bool isLocked) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'isLocked': isLocked});
    } catch (e) {
      throw Exception('Error updating lock status: ${e.toString()}');
    }
  }

  // Update chat favorite status
  Future<void> updateChatFavoriteStatus(String chatId, bool isFavorite) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'isFavorite': isFavorite});
    } catch (e) {
      throw Exception('Error updating favorite status: ${e.toString()}');
    }
  }

  // Clear chat messages
  Future<void> clearChatMessages(String chatId) async {
    try {
      // Delete all messages in the chat
      QuerySnapshot messagesSnapshot = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .get();

      for (DocumentSnapshot doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Reset chat's last message
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'lastMessage': '',
            'lastMessageType': 'text',
            'lastMessageTime': Timestamp.fromDate(DateTime.now()),
            'lastMessageSenderId': '',
          });
    } catch (e) {
      throw Exception('Error clearing chat: ${e.toString()}');
    }
  }

  // Block chat
  Future<void> blockChat(String chatId) async {
    try {
      // Get chat details
      DocumentSnapshot chatDoc = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        ChatModel chat = ChatModel.fromMap(
          chatDoc.data() as Map<String, dynamic>,
        );

        // Find the other user to block (for individual chats)
        for (String participantId in chat.participants) {
          if (participantId != currentUserId) {
            // Add to blocked users collection
            await _firestore.collection('blocked_users').doc(currentUserId).set(
              {
                'blockedUsers': FieldValue.arrayUnion([participantId]),
              },
              SetOptions(merge: true),
            );
            break;
          }
        }

        // Delete the chat
        await deleteChat(chatId);
      }
    } catch (e) {
      throw Exception('Error blocking chat: ${e.toString()}');
    }
  }

  // Update message status (sent, delivered, read)
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    String status,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'status': status, 'isRead': status == 'read'});
    } catch (e) {
      developer.log('Error updating message status: $e');
    }
  }

  // Stream to check if other user is online
  Stream<bool> isUserOnline(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return doc.data()?['isOnline'] ?? false;
          }
          return false;
        });
  }

  // Get a single chat document as a stream
  Stream<ChatModel?> getChatStream(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .snapshots()
        .map((doc) {
          if (doc.exists) return ChatModel.fromMap(doc.data()!);
          return null;
        });
  }

  // Make a member a group admin
  Future<void> makeGroupAdmin(String chatId, String memberId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'admins': FieldValue.arrayUnion([memberId]),
          });
    } catch (e) {
      throw Exception('Error making admin: ${e.toString()}');
    }
  }

  // Remove admin role from a member
  Future<void> removeGroupAdmin(String chatId, String memberId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'admins': FieldValue.arrayRemove([memberId]),
          });
    } catch (e) {
      throw Exception('Error removing admin: ${e.toString()}');
    }
  }

  // Update group name
  Future<void> updateGroupName(String chatId, String newName) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'groupName': newName});
    } catch (e) {
      throw Exception('Error updating group name: ${e.toString()}');
    }
  }

  // Exit group (remove self from participants and admins)
  Future<void> exitGroup(String chatId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'participants': FieldValue.arrayRemove([currentUserId]),
            'admins': FieldValue.arrayRemove([currentUserId]),
            'unreadCount.$currentUserId': FieldValue.delete(),
          });
    } catch (e) {
      throw Exception('Error exiting group: ${e.toString()}');
    }
  }

  // Pin a message
  Future<void> pinMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'isPinned': true});
    } catch (e) {
      throw Exception('Error pinning message: ${e.toString()}');
    }
  }

  // Unpin a message
  Future<void> unpinMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'isPinned': false});
    } catch (e) {
      throw Exception('Error unpinning message: ${e.toString()}');
    }
  }

  // Delete message for everyone (hard delete)
  Future<void> deleteMessageForEveryone(
      String chatId, String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({
            'content': 'This message was deleted',
            'type': 'deleted',
            'mediaUrl': FieldValue.delete(),
            'isPinned': false,
          });
    } catch (e) {
      throw Exception('Error deleting message: ${e.toString()}');
    }
  }

  // Delete message for me only (soft delete — add uid to deletedFor list)
  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          });
    } catch (e) {
      throw Exception('Error deleting message for me: ${e.toString()}');
    }
  }

  // Star / unstar a message
  Future<void> toggleStarMessage(
      String chatId, String messageId, bool star) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({'isStarred': star});
    } catch (e) {
      throw Exception('Error starring message: ${e.toString()}');
    }
  }

  // Send a reply message
  Future<void> sendReplyMessage({
    required String chatId,
    required String content,
    required String senderName,
    required String replyToMessageId,
    required String replyToSenderName,
    required String replyToContent,
    required String replyToType,
    String type = 'text',
    String? mediaUrl,
    int? voiceDuration,
    String? fileName,
    String? fileSize,
    String? fileExtension,
  }) async {
    try {
      final messageId = _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc()
          .id;

      final message = MessageModel(
        messageId: messageId,
        senderId: currentUserId,
        senderName: senderName,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        mediaUrl: mediaUrl,
        voiceDuration: voiceDuration,
        fileName: fileName,
        fileSize: fileSize,
        fileExtension: fileExtension,
        replyTo: ReplyInfo(
          messageId: replyToMessageId,
          senderName: replyToSenderName,
          content: replyToContent,
          type: replyToType,
        ),
      );

      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .set(message.toMap());

      await updateChatLastMessage(chatId, message);
    } catch (e) {
      throw Exception('Error sending reply: ${e.toString()}');
    }
  }

  // Forward a message to another chat
  Future<void> forwardMessage({
    required String toChatId,
    required String content,
    required String senderName,
    required String originalSenderName,
    required String type,
    String? mediaUrl,
    String? fileName,
    String? fileSize,
    String? fileExtension,
    int? voiceDuration,
  }) async {
    try {
      final messageId = _firestore
          .collection(AppConstants.chatsCollection)
          .doc(toChatId)
          .collection(AppConstants.messagesCollection)
          .doc()
          .id;

      final message = MessageModel(
        messageId: messageId,
        senderId: currentUserId,
        senderName: senderName,
        content: content,
        type: type,
        timestamp: DateTime.now(),
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileExtension: fileExtension,
        voiceDuration: voiceDuration,
        forwardedFrom: originalSenderName,
      );

      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(toChatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .set(message.toMap());

      await updateChatLastMessage(toChatId, message);
    } catch (e) {
      throw Exception('Error forwarding message: ${e.toString()}');
    }
  }

  // Mute / unmute a chat for current user
  Future<void> muteChatForUser(String chatId, bool mute) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({
            'mutedBy': mute
                ? FieldValue.arrayUnion([currentUserId])
                : FieldValue.arrayRemove([currentUserId]),
          });
    } catch (e) {
      throw Exception('Error muting chat: ${e.toString()}');
    }
  }

  // Update group description
  Future<void> updateGroupDescription(
      String chatId, String description) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'groupDescription': description});
    } catch (e) {
      throw Exception('Error updating group description: ${e.toString()}');
    }
  }

  // Get starred messages for a chat
  Stream<List<MessageModel>> getStarredMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('isStarred', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MessageModel.fromMap(d.data())).toList());
  }

  // ── Typing indicator ──────────────────────────────────────────

  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection('typing')
          .doc(currentUserId)
          .set({'isTyping': isTyping, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      developer.log('Error setting typing: $e');
    }
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection('typing')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => d.id)
            .where((id) => id != currentUserId)
            .toList());
  }

  // ── Reactions ─────────────────────────────────────────────────

  Future<void> addReaction(
      String chatId, String messageId, String emoji) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({
            'reactions.$emoji': FieldValue.arrayUnion([currentUserId]),
          });
    } catch (e) {
      throw Exception('Error adding reaction: ${e.toString()}');
    }
  }

  Future<void> removeReaction(
      String chatId, String messageId, String emoji) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .update({
            'reactions.$emoji': FieldValue.arrayRemove([currentUserId]),
          });
    } catch (e) {
      throw Exception('Error removing reaction: ${e.toString()}');
    }
  }

  // ── Disappearing messages ─────────────────────────────────────

  /// Sets disappearing message timer for a chat (duration in seconds, 0 = off)
  Future<void> setDisappearingMessages(String chatId, int seconds) async {
    try {
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'disappearingSeconds': seconds});
    } catch (e) {
      throw Exception('Error setting disappearing messages: ${e.toString()}');
    }
  }

  // ── Search messages ───────────────────────────────────────────

  Future<List<MessageModel>> searchMessages(
      String chatId, String query) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .orderBy('timestamp', descending: true)
          .get();

      final lower = query.toLowerCase();
      return snap.docs
          .map((d) => MessageModel.fromMap(d.data()))
          .where((m) =>
              m.type == 'text' &&
              m.content.toLowerCase().contains(lower) &&
              !m.deletedFor.contains(currentUserId))
          .toList();
    } catch (e) {
      developer.log('Error searching messages: $e');
      return [];
    }
  }
}
