import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission (needed for video recording)
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request both camera and microphone permissions at once
  static Future<Map<String, bool>> requestAllPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    return {
      'camera': cameraStatus.isGranted,
      'microphone': micStatus.isGranted,
    };
  }
}
