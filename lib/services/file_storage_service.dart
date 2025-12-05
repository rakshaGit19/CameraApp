import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class FileStorageService {
  Directory? _cameraDirectory;

  /// Get the camera directory
  Directory? get cameraDirectory => _cameraDirectory;

  /// Setup the camera directory where photos/videos will be saved
  Future<void> setupCameraDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cameraDirectory = Directory('${appDir.path}/Camera');

      // Create directory if it doesn't exist
      if (!await _cameraDirectory!.exists()) {
        await _cameraDirectory!.create(recursive: true);
      }
    } catch (e) {
      print('Error setting up directory: $e');
    }
  }

  /// Get the path of the most recently saved photo or video
  Future<String?> getLastMediaPath() async {
    if (_cameraDirectory == null) return null;

    try {
      final files = _cameraDirectory!
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
          )
          .toList();

      if (files.isNotEmpty) {
        // Sort by modification time (newest first)
        files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );
        return files.first.path;
      }
    } catch (e) {
      print('Error loading last media: $e');
    }
    return null;
  }

  /// Save a photo with timestamp filename
  Future<String> savePhoto(String imagePath) async {
    if (_cameraDirectory == null) {
      throw Exception('Camera directory not initialized');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'IMG_$timestamp.jpg';
    final savedPath = '${_cameraDirectory!.path}/$filename';

    await File(imagePath).copy(savedPath);
    return savedPath;
  }

  /// Save a video with timestamp filename
  Future<String> saveVideo(String videoPath) async {
    if (_cameraDirectory == null) {
      throw Exception('Camera directory not initialized');
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'VID_$timestamp.mp4';
    final savedPath = '${_cameraDirectory!.path}/$filename';

    await File(videoPath).copy(savedPath);
    return savedPath;
  }

  /// Extract filename from full path
  String getFilenameFromPath(String path) {
    return path.split('/').last;
  }
}
