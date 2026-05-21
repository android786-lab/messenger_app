import 'dart:io';

/// Upload progress callback: 0.0 – 1.0
typedef UploadProgressCallback = void Function(double progress);

/// Abstraction for chat/profile media storage (Supabase implementation).
abstract class MediaStorageRepository {
  Future<String> uploadProfileImage({
    required String userId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  Future<String> uploadChatImage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  Future<String> uploadVoiceMessage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  Future<String> uploadChatFile({
    required String chatId,
    required File file,
    required String extension,
    UploadProgressCallback? onProgress,
  });

  Future<String> uploadVideoMessage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  Future<void> deleteByPublicUrl(String url);
}
