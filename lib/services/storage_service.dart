import 'dart:developer' as developer;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        // Check file size
        int fileSize = await imageFile.length();
        if (fileSize > AppConstants.maxImageSize) {
          throw Exception('Image size too large. Maximum size is 5MB.');
        }

        return imageFile;
      }
    } catch (e) {
      throw Exception('Error picking image: ${e.toString()}');
    }
    return null;
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        // Check file size
        int fileSize = await imageFile.length();
        if (fileSize > AppConstants.maxImageSize) {
          throw Exception('Image size too large. Maximum size is 5MB.');
        }

        return imageFile;
      }
    } catch (e) {
      throw Exception('Error taking photo: ${e.toString()}');
    }
    return null;
  }

  // Upload image to Firebase Storage
  Future<String> uploadImage(File imageFile, String path) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('$path/$fileName.jpg');

      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading image: ${e.toString()}');
    }
  }

  // Upload chat image
  Future<String> uploadChatImage(File imageFile) async {
    return await uploadImage(imageFile, AppConstants.chatImagesPath);
  }

  // Upload profile picture
  Future<String> uploadProfilePicture(File imageFile) async {
    return await uploadImage(imageFile, AppConstants.profilePicsPath);
  }

  // Upload voice message
  Future<String> uploadVoiceMessage(File audioFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child(
        '${AppConstants.voiceMessagesPath}/$fileName.m4a',
      );

      UploadTask uploadTask = ref.putFile(audioFile);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading voice message: ${e.toString()}');
    }
  }

  // Delete file from storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      developer.log('Error deleting file: $e');
    }
  }

  // Get temporary directory for audio recording
  Future<String> getTemporaryPath() async {
    Directory tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  // Create audio file path
  String createAudioFilePath() {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return '$timestamp.m4a';
  }

  // Pick file from device
  Future<File?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedFileTypes,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);

        // Check file size
        int fileSize = await file.length();
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

  // Upload file to Firebase Storage
  Future<String> uploadFile(File file) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      String fileExtension = file.path.split('.').last.toLowerCase();
      Reference ref = _storage.ref().child(
        '${AppConstants.filesPath}/$fileName.$fileExtension',
      );

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Error uploading file: ${e.toString()}');
    }
  }

  // Get file info (name, size, extension)
  Map<String, String> getFileInfo(File file) {
    String fileName = file.path.split('/').last;
    String fileExtension = file.path.split('.').last.toLowerCase();
    int fileSize = file.lengthSync();

    return {
      'name': fileName,
      'extension': fileExtension,
      'size': _formatFileSize(fileSize),
    };
  }

  // Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Get file icon based on extension
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
