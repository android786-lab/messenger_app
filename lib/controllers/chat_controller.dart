import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/block_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();
  final BlockService _blockService = BlockService();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  List<MessageModel> _olderMessages = [];
  bool _hasMoreMessages = true;
  bool _isLoadingOlder = false;
  bool _isLoading = false;
  double _uploadProgress = 0;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _errorMessage;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription? _chatsSubscription;
  StreamSubscription? _messagesSubscription;
  String? _currentPlayingMessageId;

  // Getters
  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages {
    final byId = <String, MessageModel>{};
    for (final m in [..._messages, ..._olderMessages]) {
      byId[m.messageId] = m;
    }
    return byId.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingOlder => _isLoadingOlder;
  double get uploadProgress => _uploadProgress;
  bool get isLoading => _isLoading;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get errorMessage => _errorMessage;
  Duration get recordingDuration => _recordingDuration;
  String? get currentPlayingMessageId => _currentPlayingMessageId;

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error message
  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Get or create chat
  Future<String?> getOrCreateChat(String otherUserId) async {
    try {
      _setLoading(true);
      String chatId = await _chatService.getOrCreateChat(otherUserId);
      return chatId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Send text message
  Future<void> sendTextMessage({
    required String chatId,
    required String content,
    required String senderName,
  }) async {
    try {
      await _chatService.sendMessage(
        chatId: chatId,
        content: content,
        senderName: senderName,
        type: AppConstants.textMessage,
      );
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Send image message
  Future<void> sendImageMessage({
    required String chatId,
    required String senderName,
    required File imageFile,
  }) async {
    try {
      _setLoading(true);

      // Upload image to Firebase Storage
      String imageUrl = await _storageService.uploadChatImage(
        imageFile,
        chatId: chatId,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      _uploadProgress = 0;

      // Send message with image URL
      await _chatService.sendMessage(
        chatId: chatId,
        content: 'Photo',
        senderName: senderName,
        type: AppConstants.imageMessage,
        mediaUrl: imageUrl,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Pick and send image from gallery
  Future<void> pickAndSendImageFromGallery({
    required String chatId,
    required String senderName,
  }) async {
    try {
      File? imageFile = await _storageService.pickImageFromGallery();
      if (imageFile != null) {
        await sendImageMessage(
          chatId: chatId,
          senderName: senderName,
          imageFile: imageFile,
        );
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Pick and send image from camera
  Future<void> pickAndSendImageFromCamera({
    required String chatId,
    required String senderName,
  }) async {
    try {
      File? imageFile = await _storageService.pickImageFromCamera();
      if (imageFile != null) {
        await sendImageMessage(
          chatId: chatId,
          senderName: senderName,
          imageFile: imageFile,
        );
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Start voice recording
  Future<void> startRecording() async {
    try {
      // Initialize recorder
      await _audioRecorder.openRecorder();
      await _audioRecorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      Directory tempDir = await getTemporaryDirectory();
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      _recordingPath = '${tempDir.path}/$fileName';

      await _audioRecorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.aacADTS,
      );

      _isRecording = true;
      _recordingDuration = Duration.zero;
      notifyListeners();

      // Start duration timer
      _startRecordingTimer();
    } catch (e) {
      _setError('Error starting recording: ${e.toString()}');
    }
  }

  // Stop voice recording
  Future<void> stopRecording() async {
    try {
      String? path = await _audioRecorder.stopRecorder();
      _isRecording = false;
      notifyListeners();

      if (path != null && _recordingDuration.inSeconds > 0) {
        return; // Recording stopped successfully, path available for sending
      }
    } catch (e) {
      _setError('Error stopping recording: ${e.toString()}');
    }
  }

  // Send voice message
  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderName,
  }) async {
    try {
      if (_recordingPath != null) {
        _setLoading(true);

        File audioFile = File(_recordingPath!);

        // Upload audio to Firebase Storage
        String audioUrl = await _storageService.uploadVoiceMessage(
          audioFile,
          chatId: chatId,
          onProgress: (p) {
            _uploadProgress = p;
            notifyListeners();
          },
        );
        _uploadProgress = 0;

        // Send voice message
        await _chatService.sendMessage(
          chatId: chatId,
          content: 'Voice message',
          senderName: senderName,
          type: AppConstants.voiceMessage,
          mediaUrl: audioUrl,
          voiceDuration: _recordingDuration.inSeconds,
        );

        // Clean up local file
        await audioFile.delete();
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Play voice message
  Future<void> playVoiceMessage(String messageId, String audioUrl) async {
    try {
      if (_isPlaying && _currentPlayingMessageId == messageId) {
        // Stop current playback
        await _audioPlayer.stop();
        _isPlaying = false;
        _currentPlayingMessageId = null;
      } else {
        // Start new playback
        await _audioPlayer.stop(); // Stop any current playback
        await _audioPlayer.play(UrlSource(audioUrl));
        _isPlaying = true;
        _currentPlayingMessageId = messageId;

        // Listen for playback completion
        _audioPlayer.onPlayerComplete.listen((_) {
          _isPlaying = false;
          _currentPlayingMessageId = null;
          notifyListeners();
        });
      }
      notifyListeners();
    } catch (e) {
      _setError('Error playing voice message: ${e.toString()}');
    }
  }

  // Start recording timer
  void _startRecordingTimer() {
    Stream.periodic(const Duration(seconds: 1)).listen((count) {
      if (_isRecording) {
        _recordingDuration = Duration(seconds: count + 1);
        notifyListeners();

        // Stop recording if max duration reached
        if (_recordingDuration.inSeconds >=
            AppConstants.maxVoiceMessageDuration) {
          stopRecording();
        }
      }
    });
  }

  // Listen to user chats
  void listenToUserChats() {
    // Cancel existing subscription before creating a new one
    _chatsSubscription?.cancel();
    _chatsSubscription = _chatService.getUserChats().listen(
      (chats) {
        _chats = chats;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading chats: ${error.toString()}');
      },
    );
  }

  // Listen to chat messages (recent page + realtime)
  void listenToChatMessages(String chatId) {
    _olderMessages = [];
    _hasMoreMessages = true;
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService.getChatMessages(chatId).listen(
      (messages) {
        _messages = messages;
        notifyListeners();
      },
      onError: (error) {
        _setError('Error loading messages: ${error.toString()}');
      },
    );
  }

  Future<void> loadOlderMessages(String chatId) async {
    if (_isLoadingOlder || !_hasMoreMessages) return;
    final all = [..._messages, ..._olderMessages];
    if (all.isEmpty) return;

    final oldest = all.reduce(
      (a, b) => a.timestamp.isBefore(b.timestamp) ? a : b,
    );

    try {
      _isLoadingOlder = true;
      notifyListeners();
      final older = await _chatService.loadOlderMessages(
        chatId,
        beforeTimestamp: oldest.timestamp,
      );
      if (older.isEmpty) {
        _hasMoreMessages = false;
      } else {
        final existingIds = all.map((m) => m.messageId).toSet();
        _olderMessages.addAll(
          older.where((m) => !existingIds.contains(m.messageId)),
        );
        if (older.length < ChatService.defaultMessagePageSize) {
          _hasMoreMessages = false;
        }
      }
    } catch (e) {
      _setError('Error loading older messages: ${e.toString()}');
    } finally {
      _isLoadingOlder = false;
      notifyListeners();
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      await _chatService.markMessagesAsRead(chatId);
    } catch (e) {
      developer.log('Error marking messages as read: $e');
    }
  }

  // Create group chat
  Future<String?> createGroupChat({
    required String groupName,
    required List<String> memberIds,
  }) async {
    try {
      _setLoading(true);
      String chatId = await _chatService.createGroupChat(
        groupName: groupName,
        memberIds: memberIds,
      );
      return chatId;
    } catch (e) {
      _setError(e.toString());
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Add member to group
  Future<void> addMemberToGroup(String chatId, String memberId) async {
    try {
      await _chatService.addMemberToGroup(chatId, memberId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Remove member from group
  Future<void> removeMemberFromGroup(String chatId, String memberId) async {
    try {
      await _chatService.removeMemberFromGroup(chatId, memberId);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Send file message
  Future<void> sendFileMessage({
    required String chatId,
    required String senderName,
    required File file,
  }) async {
    try {
      _setLoading(true);

      // Get file info
      Map<String, String> fileInfo = _storageService.getFileInfo(file);

      // Upload file to Firebase Storage
      String fileUrl = await _storageService.uploadFile(
        file,
        chatId: chatId,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      _uploadProgress = 0;

      // Send message with file URL
      await _chatService.sendMessage(
        chatId: chatId,
        content: fileInfo['name'] ?? 'File',
        senderName: senderName,
        type: AppConstants.fileMessage,
        mediaUrl: fileUrl,
        fileName: fileInfo['name'],
        fileSize: fileInfo['size'],
        fileExtension: fileInfo['extension'],
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Pick and send file
  Future<void> pickAndSendFile({
    required String chatId,
    required String senderName,
  }) async {
    try {
      File? file = await _storageService.pickFile();
      if (file != null) {
        await sendFileMessage(
          chatId: chatId,
          senderName: senderName,
          file: file,
        );
      }
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Download file — opens via url_launcher
  Future<void> downloadFile(String url, String fileName) async {
    try {
      developer.log('Opening file: $fileName from $url');
      // url_launcher is in pubspec — wire when needed:
      // await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _setError('Error downloading file: ${e.toString()}');
    }
  }

  // Check if user is blocked
  Future<bool> isUserBlocked(String userId) async {
    try {
      return await _blockService.isUserBlocked(userId);
    } catch (e) {
      developer.log('Error checking if user is blocked: $e');
      return false;
    }
  }

  // Check if current user is blocked by another user
  Future<bool> isCurrentUserBlockedBy(String userId) async {
    try {
      return await _blockService.isCurrentUserBlockedBy(userId);
    } catch (e) {
      developer.log('Error checking if current user is blocked: $e');
      return false;
    }
  }

  // Check if messaging is allowed between users
  Future<bool> canSendMessages(String otherUserId) async {
    try {
      // Check if current user has blocked other user
      bool isOtherUserBlocked = await isUserBlocked(otherUserId);
      if (isOtherUserBlocked) return false;

      // Check if current user is blocked by other user
      bool isCurrentUserBlocked = await isCurrentUserBlockedBy(otherUserId);
      if (isCurrentUserBlocked) return false;

      return true;
    } catch (e) {
      developer.log('Error checking messaging permissions: $e');
      return false;
    }
  }

  // Update chat pin status
  Future<void> updateChatPinStatus(String chatId, bool isPinned) async {
    try {
      await _chatService.updateChatPinStatus(chatId, isPinned);
    } catch (e) {
      _setError('Error pinning chat: ${e.toString()}');
    }
  }

  // Update chat archive status
  Future<void> updateChatArchiveStatus(String chatId, bool isArchived) async {
    try {
      await _chatService.updateChatArchiveStatus(chatId, isArchived);
    } catch (e) {
      _setError('Error archiving chat: ${e.toString()}');
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    try {
      await _chatService.deleteChat(chatId);
    } catch (e) {
      _setError('Error deleting chat: ${e.toString()}');
    }
  }

  // Mark chat as read
  Future<void> markChatAsRead(String chatId, String userId) async {
    try {
      await _chatService.markChatAsRead(chatId, userId);
    } catch (e) {
      _setError('Error marking chat as read: ${e.toString()}');
    }
  }

  // Mark chat as unread
  Future<void> markChatAsUnread(String chatId, String userId) async {
    try {
      await _chatService.markChatAsUnread(chatId, userId);
    } catch (e) {
      _setError('Error marking chat as unread: ${e.toString()}');
    }
  }

  // Update chat lock status
  Future<void> updateChatLockStatus(String chatId, bool isLocked) async {
    try {
      await _chatService.updateChatLockStatus(chatId, isLocked);
    } catch (e) {
      _setError('Error locking chat: ${e.toString()}');
    }
  }

  // Update chat favorite status
  Future<void> updateChatFavoriteStatus(String chatId, bool isFavorite) async {
    try {
      await _chatService.updateChatFavoriteStatus(chatId, isFavorite);
    } catch (e) {
      _setError('Error updating favorite status: ${e.toString()}');
    }
  }

  // Clear chat messages
  Future<void> clearChatMessages(String chatId) async {
    try {
      await _chatService.clearChatMessages(chatId);
    } catch (e) {
      _setError('Error clearing chat: ${e.toString()}');
    }
  }

  // Block chat
  Future<void> blockChat(String chatId) async {
    try {
      await _chatService.blockChat(chatId);
    } catch (e) {
      _setError('Error blocking chat: ${e.toString()}');
    }
  }

  // Pin a message
  Future<void> pinMessage(String chatId, String messageId) async {
    try {
      await _chatService.pinMessage(chatId, messageId);
    } catch (e) {
      _setError('Error pinning message: ${e.toString()}');
    }
  }

  // Unpin a message
  Future<void> unpinMessage(String chatId, String messageId) async {
    try {
      await _chatService.unpinMessage(chatId, messageId);
    } catch (e) {
      _setError('Error unpinning message: ${e.toString()}');
    }
  }

  // Delete message for everyone
  Future<void> deleteMessageForEveryone(
      String chatId, String messageId) async {
    try {
      await _chatService.deleteMessageForEveryone(chatId, messageId);
    } catch (e) {
      _setError('Error deleting message: ${e.toString()}');
    }
  }

  // Delete message for me only
  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    try {
      await _chatService.deleteMessageForMe(chatId, messageId);
    } catch (e) {
      _setError('Error deleting message: ${e.toString()}');
    }
  }

  // Star / unstar a message
  Future<void> toggleStarMessage(
      String chatId, String messageId, bool star) async {
    try {
      await _chatService.toggleStarMessage(chatId, messageId, star);
    } catch (e) {
      _setError('Error starring message: ${e.toString()}');
    }
  }

  // Send reply message
  Future<void> sendReplyMessage({
    required String chatId,
    required String content,
    required String senderName,
    required String replyToMessageId,
    required String replyToSenderName,
    required String replyToContent,
    required String replyToType,
  }) async {
    try {
      await _chatService.sendReplyMessage(
        chatId: chatId,
        content: content,
        senderName: senderName,
        replyToMessageId: replyToMessageId,
        replyToSenderName: replyToSenderName,
        replyToContent: replyToContent,
        replyToType: replyToType,
      );
    } catch (e) {
      _setError('Error sending reply: ${e.toString()}');
    }
  }

  // Forward message to another chat
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
      await _chatService.forwardMessage(
        toChatId: toChatId,
        content: content,
        senderName: senderName,
        originalSenderName: originalSenderName,
        type: type,
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
        fileExtension: fileExtension,
        voiceDuration: voiceDuration,
      );
    } catch (e) {
      _setError('Error forwarding message: ${e.toString()}');
    }
  }

  // Mute / unmute chat
  Future<void> muteChatForUser(String chatId, bool mute) async {
    try {
      await _chatService.muteChatForUser(chatId, mute);
    } catch (e) {
      _setError('Error muting chat: ${e.toString()}');
    }
  }

  // Update group description
  Future<void> updateGroupDescription(
      String chatId, String description) async {
    try {
      await _chatService.updateGroupDescription(chatId, description);
    } catch (e) {
      _setError('Error updating group description: ${e.toString()}');
    }
  }

  // ── Typing indicator ──────────────────────────────────────────

  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      await _chatService.setTyping(chatId, isTyping);
    } catch (_) {}
  }

  Stream<List<String>> getTypingUsers(String chatId) =>
      _chatService.getTypingUsers(chatId);

  // ── Reactions ─────────────────────────────────────────────────

  Future<void> addReaction(
      String chatId, String messageId, String emoji) async {
    try {
      await _chatService.addReaction(chatId, messageId, emoji);
    } catch (e) {
      _setError('Error adding reaction: ${e.toString()}');
    }
  }

  Future<void> removeReaction(
      String chatId, String messageId, String emoji) async {
    try {
      await _chatService.removeReaction(chatId, messageId, emoji);
    } catch (e) {
      _setError('Error removing reaction: ${e.toString()}');
    }
  }

  // ── Disappearing messages ─────────────────────────────────────

  Future<void> setDisappearingMessages(String chatId, int seconds) async {
    try {
      await _chatService.setDisappearingMessages(chatId, seconds);
    } catch (e) {
      _setError('Error setting disappearing messages: ${e.toString()}');
    }
  }

  // ── Search messages ───────────────────────────────────────────

  Future<List<MessageModel>> searchMessages(
      String chatId, String query) async {
    try {
      return await _chatService.searchMessages(chatId, query);
    } catch (e) {
      _setError('Error searching messages: ${e.toString()}');
      return [];
    }
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }
}
