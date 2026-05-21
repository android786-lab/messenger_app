import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/env_config.dart';
import '../core/constants/storage_buckets.dart';
import '../services/supabase_service.dart';
import 'media_storage_repository.dart';

class SupabaseMediaRepository implements MediaStorageRepository {
  SupabaseMediaRepository(this._supabase);

  final SupabaseService _supabase;
  final _uuid = const Uuid();
  static const _maxRetries = 3;

  SupabaseClient? get _client =>
      _supabase.isInitialized ? _supabase.client : null;

  void _ensureReady() {
    if (!EnvConfig.isSupabaseConfigured) {
      throw Exception(
        'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env',
      );
    }
    if (_client == null) {
      throw Exception('Supabase failed to initialize');
    }
  }

  Future<String> _upload({
    required String bucket,
    required File file,
    required String objectPath,
    UploadProgressCallback? onProgress,
  }) async {
    _ensureReady();
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        onProgress?.call(0.1);
        await _client!.storage.from(bucket).upload(
              objectPath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mime,
              ),
            );
        onProgress?.call(1.0);
        return _client!.storage.from(bucket).getPublicUrl(objectPath);
      } catch (e) {
        if (attempt == _maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw Exception('Upload failed after $_maxRetries attempts');
  }

  String _objectPath(String prefix, String ext) =>
      '$prefix/${_uuid.v4()}.$ext';

  String _fileExtension(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i + 1).toLowerCase();
  }

  @override
  Future<String> uploadProfileImage({
    required String userId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    final ext = _fileExtension(file.path);
    final path = _objectPath(userId, ext.isEmpty ? 'jpg' : ext);
    return _upload(
      bucket: StorageBuckets.profileImages,
      file: file,
      objectPath: path,
      onProgress: onProgress,
    );
  }

  @override
  Future<String> uploadChatImage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    final ext = _fileExtension(file.path);
    return _upload(
      bucket: StorageBuckets.chatImages,
      file: file,
      objectPath: _objectPath(chatId, ext.isEmpty ? 'jpg' : ext),
      onProgress: onProgress,
    );
  }

  @override
  Future<String> uploadVoiceMessage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _upload(
      bucket: StorageBuckets.voiceMessages,
      file: file,
      objectPath: _objectPath(chatId, 'm4a'),
      onProgress: onProgress,
    );
  }

  @override
  Future<String> uploadChatFile({
    required String chatId,
    required File file,
    required String extension,
    UploadProgressCallback? onProgress,
  }) async {
    return _upload(
      bucket: StorageBuckets.chatFiles,
      file: file,
      objectPath: _objectPath(chatId, extension),
      onProgress: onProgress,
    );
  }

  @override
  Future<String> uploadVideoMessage({
    required String chatId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    final ext = _fileExtension(file.path);
    return _upload(
      bucket: StorageBuckets.videoMessages,
      file: file,
      objectPath: _objectPath(chatId, ext.isEmpty ? 'mp4' : ext),
      onProgress: onProgress,
    );
  }

  @override
  Future<void> deleteByPublicUrl(String url) async {
    if (!EnvConfig.isSupabaseConfigured || _client == null) return;
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('object');
      if (bucketIndex < 0 || bucketIndex + 2 >= segments.length) return;
      final bucket = segments[bucketIndex + 2];
      final objectPath = segments.sublist(bucketIndex + 3).join('/');
      await _client!.storage.from(bucket).remove([objectPath]);
    } catch (_) {
      // Best-effort cleanup
    }
  }
}
