import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service upload avatar người dùng lên Supabase Storage và trả về public URL.
///
/// Flow:
/// 1. UI gọi [uploadAvatar(file, userId: ...)] với file ảnh đã pick từ
///    `image_picker`.
/// 2. File được upload vào bucket được cấu hình bởi
///    `SUPABASE_AVATAR_BUCKET` trong `.env.dev` (mặc định `avatars`),
///    với path `<userId>/<timestamp>.<ext>`.
/// 3. Trả về public URL — UI sẽ POST URL này về backend qua
///    `PATCH /profile { avatar_url }`.
///
/// Yêu cầu: `Supabase.initialize` đã được gọi trong `main()` và bucket
/// đã được set thành public read trong Supabase dashboard.
class AvatarStorageService {
  AvatarStorageService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  String get _bucket =>
      dotenv.env['SUPABASE_AVATAR_BUCKET']?.trim().isNotEmpty == true
          ? dotenv.env['SUPABASE_AVATAR_BUCKET']!.trim()
          : 'avatars';

  /// Upload file ảnh và trả về public URL.
  ///
  /// Throws [AvatarUploadException] khi upload thất bại (network, permission,
  /// bucket missing). UI nên wrap trong try/catch để show snackbar.
  Future<String> uploadAvatar({
    required File file,
    required String userId,
  }) async {
    try {
      final lastDot = file.path.lastIndexOf('.');
      final ext = lastDot >= 0 ? file.path.substring(lastDot + 1).toLowerCase() : '';
      final safeExt = ext.isEmpty ? 'jpg' : ext;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final objectPath = '$userId/$timestamp.$safeExt';

      final storage = _supabase.storage.from(_bucket);
      await storage.upload(
        objectPath,
        file,
        fileOptions: FileOptions(
          contentType: _contentTypeFor(safeExt),
          upsert: true,
        ),
      );

      // Sau khi upload thành công, dọn dẹp các avatar cũ trong folder user.
      // Best-effort: nếu xóa thất bại (network, RLS) cũng không fail upload.
      await _cleanupOldAvatars(userId: userId, keepObjectPath: objectPath);

      final publicUrl = storage.getPublicUrl(objectPath);
      // Cache-busting query param tránh CDN/HTTP cache giữ ảnh cũ.
      return '$publicUrl?v=$timestamp';
    } on StorageException catch (e) {
      debugPrint('[AvatarStorageService] StorageException: ${e.message}');
      throw AvatarUploadException(
        'Tải ảnh lên thất bại: ${e.message}',
        cause: e,
      );
    } catch (e) {
      debugPrint('[AvatarStorageService] Unexpected error: $e');
      throw AvatarUploadException(
        'Tải ảnh lên thất bại. Vui lòng thử lại.',
        cause: e,
      );
    }
  }

  /// Xóa các avatar cũ trong folder `<userId>/`, giữ lại file vừa upload.
  /// Được gọi sau mỗi lần upload thành công. Best-effort: lỗi không
  /// được throw lên UI để tránh chặn flow chính.
  Future<void> _cleanupOldAvatars({
    required String userId,
    required String keepObjectPath,
  }) async {
    try {
      final storage = _supabase.storage.from(_bucket);
      final files = await storage.list(path: userId);
      final pathsToDelete = files
          .map((f) => '$userId/${f.name}')
          .where((p) => p != keepObjectPath)
          .toList();
      if (pathsToDelete.isNotEmpty) {
        await storage.remove(pathsToDelete);
        debugPrint(
          '[AvatarStorageService] removed ${pathsToDelete.length} old avatar(s) for user $userId',
        );
      }
    } catch (e) {
      debugPrint('[AvatarStorageService] cleanup old avatars failed (non-fatal): $e');
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

class AvatarUploadException implements Exception {
  AvatarUploadException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AvatarUploadException: $message';
}
