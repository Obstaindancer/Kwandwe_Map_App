import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Handles extracting the bundled MBTiles file from the APK
/// to device storage on first launch.
///
/// The MBTiles file lives in android/app/src/main/assets/tiles/
/// and is bundled raw into the APK. On first launch this service
/// copies it to the app's documents directory so flutter_map_mbtiles
/// can read it as a regular file.
class TileLoaderService {
  static const String _assetPath = 'Assets/tiles/kwandwe_2024.mbtiles';
  static const String _fileName = 'kwandwe_2024.mbtiles';

  /// Returns the path to the usable MBTiles file on device storage.
  /// Copies from APK assets if not already extracted.
  static Future<String> getOrExtractTilePath({
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetFile = File('${dir.path}/$_fileName');

    // Already extracted — verify it's not a corrupted/partial extraction
    if (await targetFile.exists()) {
      final stat = await targetFile.stat();
      if (stat.size > 120000000) { // Should be ~121MB
        return targetFile.path;
      } else {
        // It's partially extracted (malformed DB). Delete and start over.
        await targetFile.delete();
      }
    }

    // First launch — copy from APK assets to device storage
    try {
      final byteData = await rootBundle.load(_assetPath);
      final bytes = byteData.buffer.asUint8List();

      // Write in chunks so we can report progress for large files
      final sink = targetFile.openWrite();
      const chunkSize = 1024 * 1024; // 1MB chunks
      int written = 0;

      while (written < bytes.length) {
        final end = (written + chunkSize).clamp(0, bytes.length);
        sink.add(bytes.sublist(written, end));
        written = end;
        onProgress?.call(written / bytes.length);
        // Yield to the event loop so the UI progress bar can update
        // and we don't overwhelm the memory buffer
        await Future.delayed(const Duration(milliseconds: 10));
      }

      await sink.flush();
      await sink.close();

      return targetFile.path;
    } catch (e) {
      throw TileLoadException(
        'Could not extract map file from APK: $e\n'
        'Make sure kwandwe_2024.mbtiles is in '
        'android/app/src/main/assets/tiles/',
      );
    }
  }

  /// Deletes the extracted tile file — forces re-extraction on next launch.
  /// Use this when a new map version is bundled in an updated APK.
  static Future<void> clearExtractedTile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_fileName');
    if (await file.exists()) await file.delete();
  }

  /// Returns true if the tile file has already been extracted.
  static Future<bool> isExtracted() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName').exists();
  }
}

class TileLoadException implements Exception {
  final String message;
  const TileLoadException(this.message);

  @override
  String toString() => 'TileLoadException: $message';
}
