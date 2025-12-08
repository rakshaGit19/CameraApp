import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import '../providers/settings_provider.dart';
import '../providers/location_provider.dart';

// --- STATE ---
class CameraState {
  final CameraController? controller;
  final List<CameraDescription>? cameras;
  final int selectedCameraIndex;
  final bool isInitialized;
  final bool isRecording;
  final Duration recordingDuration;
  final String? error;
  final FlashMode flashMode;
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final double currentExposure;
  final double minExposure;
  final double maxExposure;
  final String? lastMediaPath;

  // Custom Status for UI
  final String? statusMessage;

  const CameraState({
    this.controller,
    this.cameras,
    this.selectedCameraIndex = 0,
    this.isInitialized = false,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.error,
    this.flashMode = FlashMode.off,
    this.currentZoom = 1.0,
    this.minZoom = 1.0,
    this.maxZoom = 10.0,
    this.currentExposure = 0.0,
    this.minExposure = -4.0,
    this.maxExposure = 4.0,
    this.lastMediaPath,
    this.statusMessage,
  });

  CameraState copyWith({
    CameraController? controller,
    List<CameraDescription>? cameras,
    int? selectedCameraIndex,
    bool? isInitialized,
    bool? isRecording,
    Duration? recordingDuration,
    String? error,
    FlashMode? flashMode,
    double? currentZoom,
    double? minZoom,
    double? maxZoom,
    double? currentExposure,
    double? minExposure,
    double? maxExposure,
    String? lastMediaPath,
    String? statusMessage,
  }) {
    return CameraState(
      controller: controller ?? this.controller,
      cameras: cameras ?? this.cameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      isInitialized: isInitialized ?? this.isInitialized,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      error: error ?? this.error,
      flashMode: flashMode ?? this.flashMode,
      currentZoom: currentZoom ?? this.currentZoom,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      currentExposure: currentExposure ?? this.currentExposure,
      minExposure: minExposure ?? this.minExposure,
      maxExposure: maxExposure ?? this.maxExposure,
      lastMediaPath: lastMediaPath ?? this.lastMediaPath,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

// --- NOTIFIER ---
class CameraNotifier extends StateNotifier<CameraState> {
  final Ref ref;
  Timer? _recordingTimer;

  CameraNotifier(this.ref) : super(const CameraState()) {
    _initCamera();
  }

  // Provider definition
  static final provider = StateNotifierProvider<CameraNotifier, CameraState>((
    ref,
  ) {
    final notifier = CameraNotifier(ref);
    ref.onDispose(() {
      notifier.disposeController();
    });
    return notifier;
  });

  @override
  void dispose() {
    _recordingTimer?.cancel();
    state.controller?.dispose();
    super.dispose();
  }

  void disposeController() {
    _recordingTimer?.cancel();
    state.controller?.dispose();
  }

  Future<void> _initCamera() async {
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (!cameraStatus.isGranted) {
      state = state.copyWith(error: 'Camera permission denied');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(error: 'No camera found');
        return;
      }

      state = state.copyWith(cameras: cameras);
      await _initController(cameras[0]);
      await _loadLastMedia();
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final minExp = await controller.getMinExposureOffset();
      final maxExp = await controller.getMaxExposureOffset();

      state = state.copyWith(
        controller: controller,
        isInitialized: true,
        minZoom: minZoom,
        maxZoom: maxZoom,
        minExposure: minExp,
        maxExposure: maxExp,
        currentZoom: minZoom,
        currentExposure: 0.0,
        error: null, // Clear errors on success
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to initialize controller: $e');
    }
  }

  Future<void> switchCamera() async {
    if (state.cameras == null || state.cameras!.length < 2) return;

    final newIndex = (state.selectedCameraIndex + 1) % state.cameras!.length;
    await state.controller?.dispose(); // Dispose old before creating new

    state = state.copyWith(
      isInitialized: false,
      selectedCameraIndex: newIndex,
      controller: null, // Avoid using disposed controller
    );

    await _initController(state.cameras![newIndex]);
  }

  Future<void> toggleFlash() async {
    if (state.controller == null || !state.isInitialized) return;

    FlashMode newMode;
    switch (state.flashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        newMode = FlashMode.off;
        break;
    }

    await state.controller!.setFlashMode(newMode);
    state = state.copyWith(flashMode: newMode);
  }

  Future<void> setZoom(double zoom) async {
    if (state.controller == null || !state.isInitialized) return;
    final clamped = zoom.clamp(state.minZoom, state.maxZoom);
    await state.controller!.setZoomLevel(clamped);
    state = state.copyWith(currentZoom: clamped);
  }

  Future<void> setExposure(double exposure) async {
    if (state.controller == null || !state.isInitialized) return;
    final clamped = exposure.clamp(state.minExposure, state.maxExposure);
    await state.controller!.setExposureOffset(clamped);
    state = state.copyWith(currentExposure: clamped);
  }

  Future<void> setFocusPoint(Offset point) async {
    if (state.controller == null || !state.isInitialized) return;
    try {
      await state.controller!.setFocusPoint(point);
      await state.controller!.setExposurePoint(point);
    } catch (e) {
      print('Error setting focus: $e');
    }
  }

  Future<void> takePhoto() async {
    if (state.controller == null || !state.isInitialized) return;

    try {
      final image = await state.controller!.takePicture();
      final cameraDir = await _getCameraDirectory();

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'IMG_$timestamp.jpg';
      final savedPath = '${cameraDir.path}/$filename';

      await File(image.path).copy(savedPath);

      // GPS Overlay
      final locationState = ref.read(LocationNotifier.provider);
      if (locationState.isInitialized) {
        await _addGpsOverlay(File(savedPath));
      }

      state = state.copyWith(
        lastMediaPath: savedPath,
        statusMessage: 'Photo saved: $filename',
      );

      // Clear status message after a delay? Or let UI handle it.
      // For now, UI can listen to changes.
    } catch (e) {
      state = state.copyWith(error: 'Failed to capture photo: $e');
    }
  }

  Future<void> toggleVideoRecording() async {
    if (state.controller == null || !state.isInitialized) return;

    if (state.isRecording) {
      // STOP
      try {
        final video = await state.controller!.stopVideoRecording();
        _recordingTimer?.cancel();

        final cameraDir = await _getCameraDirectory();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filename = 'VID_$timestamp.mp4';
        final savedPath = '${cameraDir.path}/$filename';

        await File(video.path).copy(savedPath);

        final locationState = ref.read(LocationNotifier.provider);
        if (locationState.isInitialized) {
          await _saveVideoGpsData(savedPath);
        }

        state = state.copyWith(
          isRecording: false,
          recordingDuration: Duration.zero,
          lastMediaPath: savedPath,
          statusMessage: 'Video saved: $filename',
        );
      } catch (e) {
        state = state.copyWith(error: 'Failed to stop video: $e');
      }
    } else {
      // START
      try {
        await state.controller!.startVideoRecording();
        state = state.copyWith(
          isRecording: true,
          recordingDuration: Duration.zero,
        );

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          state = state.copyWith(
            recordingDuration:
                state.recordingDuration + const Duration(seconds: 1),
          );
        });
      } catch (e) {
        state = state.copyWith(error: 'Failed to start video: $e');
      }
    }
  }

  // --- Helper Methods ---

  // --- Helper Methods ---

  Future<Directory> _getCameraDirectory() async {
    if (Platform.isAndroid) {
      final dcimDir = Directory('/storage/emulated/0/DCIM/GPSCamera');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }
      return dcimDir;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/Camera');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  Future<void> _loadLastMedia() async {
    try {
      final dir = await _getCameraDirectory();
      if (!dir.existsSync()) return;

      final files = dir
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
          )
          .toList();

      if (files.isNotEmpty) {
        files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );
        state = state.copyWith(lastMediaPath: files.first.path);
      }
    } catch (e) {
      print('Error loading last media: $e');
    }
  }

  // --- GPS Overlay Logic ---

  Future<void> _addGpsOverlay(File imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      // Get location + settings from Riverpod
      final settings = ref.read(SettingsNotifier.provider);
      final locationState = ref.read(LocationNotifier.provider);

      final address = locationState.address ?? 'Unknown location';
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE, dd/MM/yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      final timezone = 'GMT +05:30';

      // Image sizes
      final imageWidth = originalImage.width;
      final imageHeight = originalImage.height;

      // Map Flutter font selection to image-text pixel size
      int fontPixel;
      switch (settings.fontSize) {
        case 'small':
          fontPixel = 14;
          break;
        case 'large':
          fontPixel = 48;
          break;
        case 'medium':
        default:
          fontPixel = 24;
          break;
      }

      // Approximate character width in pixels
      final double approxCharWidth = fontPixel * 0.55;

      // Max usable width inside the box (left + right padding = 60px each)
      final double maxPixelWidth = (imageWidth - 120).toDouble();

      // Collect stamp lines (wrapped)
      final List<String> stampLines = [];

      if (settings.showStampAddress) {
        stampLines.addAll(
          _wrapByPixelWidth(address, maxPixelWidth, approxCharWidth),
        );
      }

      if (settings.showStampCoordinates) {
        final coords = locationState.formattedCoordinates ?? 'N/A';
        stampLines.addAll(
          _wrapByPixelWidth(coords, maxPixelWidth, approxCharWidth),
        );
      }

      if (settings.showStampDateTime) {
        final dt = "$dateStr $timeStr $timezone";
        stampLines.addAll(
          _wrapByPixelWidth(dt, maxPixelWidth, approxCharWidth),
        );
      }

      // Each text line height based on selected font
      final int lineHeight = fontPixel + 12;

      // Total overlay box height
      final overlayHeight = (20 + stampLines.length * lineHeight + 60);

      // Create final image with bottom extension
      img.Image finalImage = img.Image(
        width: imageWidth,
        height: imageHeight + overlayHeight,
      );

      // Place original image at top
      img.compositeImage(finalImage, originalImage, dstX: 0, dstY: 0);

      // Draw black rectangle background
      img.fillRect(
        finalImage,
        x1: 0,
        y1: imageHeight,
        x2: imageWidth,
        y2: imageHeight + overlayHeight,
        color: img.ColorRgb8(0, 0, 0),
      );

      // Draw border with left-right padding
      img.drawRect(
        finalImage,
        x1: 40,
        y1: imageHeight + 10,
        x2: imageWidth - 40,
        y2: imageHeight + overlayHeight - 10,
        color: img.ColorRgb8(255, 255, 255),
        thickness: 2,
      );

      // Starting position for text
      int yPosition = imageHeight + 20;

      // Image font
      final dynamic font = _getFontSize(settings.fontSize);

      // Wrap length for address detection (for bold)
      final addressWrapped = _wrapByPixelWidth(
        address,
        maxPixelWidth,
        approxCharWidth,
      );
      final int addressLineCount = settings.showStampAddress
          ? addressWrapped.length
          : 0;

      // Draw each line
      for (int i = 0; i < stampLines.length; i++) {
        final line = stampLines[i];

        final bool isAddressLine =
            i < addressLineCount && settings.showStampAddress;

        if (isAddressLine && settings.boldAddress) {
          _drawBoldString(
            finalImage,
            line,
            x: 60,
            y: yPosition,
            font: font,
            color: img.ColorRgb8(255, 255, 255),
          );
        } else {
          img.drawString(
            finalImage,
            line,
            font: font,
            x: 60,
            y: yPosition,
            color: img.ColorRgb8(255, 255, 255),
          );
        }

        yPosition += lineHeight;
      }

      // WATERMARK
      final watermark = "RV";

      // Approximate text width (Arial 14)
      final double watermarkWidth = watermark.length * 8.0;

      // Calculate center alignment
      final int centerX = ((imageWidth - watermarkWidth) / 2).round();
      final int centerY = imageHeight + overlayHeight - 35;

      // Draw final bold, centered watermark
      _drawBoldString(
        finalImage,
        watermark,
        x: centerX,
        y: centerY,
        font: img.arial14,
        color: img.ColorRgb8(255, 255, 255),
      );

      // Save image
      final outBytes = img.encodeJpg(finalImage);
      await imageFile.writeAsBytes(outBytes);
    } catch (e) {
      print("ERROR adding overlay: $e");
    }
  }

  Future<void> _saveVideoGpsData(String videoPath) async {
    try {
      // Get settings and location from Riverpod
      final settings = ref.read(SettingsNotifier.provider);
      final locationState = ref.read(LocationNotifier.provider);

      // Extract just the filename
      final videoFilename = videoPath.split('/').last;

      // Save GPS to app directory (ALWAYS writable)
      final appDir = await getApplicationDocumentsDirectory();
      final gpsFilePath =
          '${appDir.path}/${videoFilename.replaceAll('.mp4', '_gps.txt')}';

      final address = locationState.address ?? 'Unknown location';
      final coords = locationState.formattedCoordinates ?? 'N/A';
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE, dd/MM/yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      final timezone = 'GMT +05:30';

      List<String> gpsLines = [];
      if (settings.showStampAddress) gpsLines.add('Location: $address');
      if (settings.showStampCoordinates) gpsLines.add('Coordinates: $coords');
      if (settings.showStampDateTime) {
        gpsLines.add('Date: $dateStr');
        gpsLines.add('Time: $timeStr $timezone');
      }

      if (gpsLines.isNotEmpty) {
        final gpsData = gpsLines.join('\n');
        await File(gpsFilePath).writeAsString(gpsData);
      }
    } catch (e) {
      print(' GPS SAVE ERROR: $e');
    }
  }

  // Defines wrapping logic
  List<String> _wrapByPixelWidth(
    String text,
    double maxPxWidth,
    double charWidth,
  ) {
    final words = text.split(' ');
    List<String> lines = [];
    String current = "";

    for (final word in words) {
      final test = current.isEmpty ? word : "$current $word";
      final testWidth = test.length * charWidth;

      if (testWidth <= maxPxWidth) {
        current = test;
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  dynamic _getFontSize(String size) {
    switch (size) {
      case 'small':
        return img.arial14;
      case 'large':
        return img.arial48;
      case 'medium':
      default:
        return img.arial24;
    }
  }

  void _drawBoldString(
    img.Image target,
    String text, {
    required int x,
    required int y,
    required dynamic font,
    required dynamic color,
  }) {
    img.drawString(target, text, font: font, x: x, y: y, color: color);
    img.drawString(target, text, font: font, x: x + 1, y: y, color: color);
    img.drawString(target, text, font: font, x: x, y: y + 1, color: color);
  }
}
