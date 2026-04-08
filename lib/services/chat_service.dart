import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

      MessageModel message = MessageModel(
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

  // Update chat's last message info
  Future<void> updateChatLastMessage(
    String chatId,
    MessageModel message,
  ) async {
    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        ChatModel chat = ChatModel.fromMap(
          chatDoc.data() as Map<String, dynamic>,
        );

        // Update unread count for other participants
        Map<String, int> newUnreadCount = Map.from(chat.unreadCount);
        for (String participantId in chat.participants) {
          if (participantId != currentUserId) {
            newUnreadCount[participantId] =
                (newUnreadCount[participantId] ?? 0) + 1;
          }
        }

        await _firestore
            .collection(AppConstants.chatsCollection)
            .doc(chatId)
            .update({
              'lastMessage': message.content,
              'lastMessageType': message.type,
              'lastMessageTime': Timestamp.fromDate(message.timestamp),
              'lastMessageSenderId': message.senderId,
              'unreadCount': newUnreadCount,
            });
      }
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

  // Get messages stream for a chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList(),
        );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      // Update chat unread count
      await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .update({'unreadCount.$currentUserId': 0});

      // Also update all messages sent by other user to 'read' status
      // Use a simpler query to avoid composite index requirement
      QuerySnapshot messagesSnapshot = await _firestore
          .collection(AppConstants.chatsCollection)
          .doc(chatId)
          .collection(AppConstants.messagesCollection)
          .where('status', whereIn: ['sent', 'delivered'])
          .get();

      for (var doc in messagesSnapshot.docs) {
        // Only update messages not sent by current user
        final data = doc.data() as Map<String, dynamic>;
        if (data['senderId'] != currentUserId) {
          await doc.reference.update({'status': 'read', 'isRead': true});
        }
      }
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
}
