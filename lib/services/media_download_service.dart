import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MediaDownloadResult {
  final bool success;
  final bool savedDirectly;
  final bool openedShareSheet;
  final String? filePath;

  const MediaDownloadResult({
    required this.success,
    this.savedDirectly = false,
    this.openedShareSheet = false,
    this.filePath,
  });
}

class MediaDownloadService {
  MediaDownloadService._();

  static Future<MediaDownloadResult> saveImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const MediaDownloadResult(success: false);
      }

      final ext = _resolveExtension(
        uri.path,
        response.headers['content-type'],
      );
      final filename = 'militant_${DateTime.now().millisecondsSinceEpoch}.$ext';

      if (!kIsWeb && Platform.isAndroid) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          final file = File('${downloadsDir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes, flush: true);
          return MediaDownloadResult(
            success: true,
            savedDirectly: true,
            filePath: file.path,
          );
        } catch (e) {
          debugPrint('[MediaDownload] Direct Download write failed: $e');
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$filename');
          await tempFile.writeAsBytes(response.bodyBytes, flush: true);
          await Share.shareXFiles([XFile(tempFile.path)]);
          return MediaDownloadResult(
            success: true,
            openedShareSheet: true,
            filePath: tempFile.path,
          );
        }
      }

      final targetDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final file = File('${targetDir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return MediaDownloadResult(
        success: true,
        savedDirectly: true,
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('[MediaDownload] Failed: $e');
      return const MediaDownloadResult(success: false);
    }
  }

  static String _resolveExtension(String path, String? contentType) {
    final ct = (contentType ?? '').toLowerCase();
    if (ct.contains('png')) return 'png';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('gif')) return 'gif';
    if (ct.contains('jpeg') || ct.contains('jpg')) return 'jpg';

    final lower = path.toLowerCase();
    for (final ext in ['png', 'webp', 'gif', 'jpeg', 'jpg']) {
      if (lower.endsWith('.$ext')) return ext == 'jpeg' ? 'jpg' : ext;
    }
    return 'jpg';
  }
}
