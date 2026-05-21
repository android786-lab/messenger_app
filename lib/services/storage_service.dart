import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_dependencies.dart';
import '../core/constants/app_constants.dart';
import '../repositories/media_storage_repository.dart';

/// Facade for media pick/compress + Supabase upload.
/// Firebase Storage is no longer used for new uploads.
class StorageService {
  StorageService({MediaStorageRepository? mediaRepository})
      : _media = mediaRepository ?? AppDependencies.instance.mediaRepository;

  final MediaStorageRepository _media;
  final ImagePicker _imagePicker = ImagePicker();

  Future<File?> _compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final target = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        target,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
      );
      if (result != null) return File(result.path);
    } catch (e) {
      developer.log('Image compress fallback: $e');
    }
    return file;
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      final file = File(picked.path);
      final size = await file.length();
      if (size > AppConstants.maxImageSize) {
        throw Exception('Image size too large. Maximum size is 5MB.');
      }
      return _compressImage(file);
    } catch (e) {
      throw Exception('Error picking image: ${e.toString()}');
    }
  }

  Future<File?> pickImageFromCamera() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.camera);
      if (picked == null) return null;
      final file = File(picked.path);
      final size = await file.length();
      if (size > AppConstants.maxImageSize) {
        throw Exception('Image size too large. Maximum size is 5MB.');
      }
      return _compressImage(file);
    } catch (e) {
      throw Exception('Error taking photo: ${e.toString()}');
    }
  }

  Future<String> uploadProfilePicture(
    File imageFile, {
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    final compressed = await _compressImage(imageFile) ?? imageFile;
    return _media.uploadProfileImage(
      userId: userId,
      file: compressed,
      onProgress: onProgress,
    );
  }

  Future<String> uploadChatImage(
    File imageFile, {
    required String chatId,
    void Function(double progress)? onProgress,
  }) async {
    final compressed = await _compressImage(imageFile) ?? imageFile;
    return _media.uploadChatImage(
      chatId: chatId,
      file: compressed,
      onProgress: onProgress,
    );
  }

  Future<String> uploadVoiceMessage(
    File audioFile, {
    required String chatId,
    void Function(double progress)? onProgress,
  }) async {
    return _media.uploadVoiceMessage(
      chatId: chatId,
      file: audioFile,
      onProgress: onProgress,
    );
  }

  Future<String> uploadFile(
    File file, {
    required String chatId,
    void Function(double progress)? onProgress,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    return _media.uploadChatFile(
      chatId: chatId,
      file: file,
      extension: ext,
      onProgress: onProgress,
    );
  }

  Future<void> deleteFile(String downloadUrl) async {
    await _media.deleteByPublicUrl(downloadUrl);
  }

  Future<String> getTemporaryPath() async {
    final tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  String createAudioFilePath() {
    return '${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<File?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedFileTypes,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        if (fileSize > AppConstants.maxFileSize) {
          throw Exception('File size too large. Maximum size is 10MB.');
        }
        return file;
      }
    } catch (e) {
      throw Exception('Error picking file: ${e.toString()}');
    }
    return null;
  }

  Map<String, String> getFileInfo(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final fileExtension = file.path.split('.').last.toLowerCase();
    final fileSize = file.lengthSync();
    return {
      'name': fileName,
      'extension': fileExtension,
      'size': _formatFileSize(fileSize),
    };
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'ppt':
      case 'pptx':
        return '📋';
      case 'txt':
      case 'rtf':
        return '📄';
      case 'zip':
      case 'rar':
      case '7z':
        return '📦';
      case 'mp3':
      case 'wav':
      case 'flac':
        return '🎵';
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'mkv':
        return '🎬';
      default:
        return '📎';
    }
  }
}
