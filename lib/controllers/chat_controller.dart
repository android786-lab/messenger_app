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
  bool _isLoading = false;
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
  List<MessageModel> get messages => _messages;
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
      String imageUrl = await _storageService.uploadChatImage(imageFile);

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
        String audioUrl = await _storageService.uploadVoiceMessage(audioFile);

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

  // Listen to chat messages
  void listenToChatMessages(String chatId) {
    // Cancel existing subscription before creating a new one
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService
        .getChatMessages(chatId)
        .listen(
          (messages) {
            _messages = messages;
            notifyListeners();
          },
          onError: (error) {
            _setError('Error loading messages: ${error.toString()}');
          },
        );
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
      String fileUrl = await _storageService.uploadFile(file);

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

  // Download file
  Future<void> downloadFile(String url, String fileName) async {
    try {
      // TODO: Implement file download using url_launcher
      // For now, just open the URL in browser
      // await launchUrl(Uri.parse(url));
      developer.log('Download file: $fileName from $url');
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

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }
}
