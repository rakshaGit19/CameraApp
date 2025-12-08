import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
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

  // --- GPS Overlay Logic with Custom Font Support ---

  Future<void> _addGpsOverlay(File imageFile) async {
    try {
      // Read original image
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return;

      // Get settings and location
      final settings = ref.read(SettingsNotifier.provider);
      final locationState = ref.read(LocationNotifier.provider);

      final address = locationState.address ?? 'Unknown location';
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE, dd/MM/yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      final timezone = 'GMT +05:30';

      // Build text lines based on settings
      List<String> textLines = [];
      if (settings.showStampAddress) textLines.add(address);
      if (settings.showStampCoordinates) {
        textLines.add(locationState.formattedCoordinates ?? 'N/A');
      }
      if (settings.showStampDateTime) {
        textLines.add('$dateStr $timeStr $timezone');
      }

      if (textLines.isEmpty) {
        // No overlay needed
        return;
      }

      // Create overlay image using Flutter rendering
      final overlayBytes = await _renderTextOverlay(
        textLines,
        originalImage.width,
        settings,
      );

      if (overlayBytes == null) {
        // Fallback to original method if rendering fails
        print('Custom font rendering failed, using fallback');
        return;
      }

      // Decode the rendered overlay
      final overlayImage = img.decodeImage(overlayBytes);
      if (overlayImage == null) return;

      // Combine original image with overlay
      final combinedHeight = originalImage.height + overlayImage.height;
      final combined = img.Image(
        width: originalImage.width,
        height: combinedHeight,
      );

      // Draw original image at top
      img.compositeImage(combined, originalImage, dstX: 0, dstY: 0);

      // Draw overlay at bottom
      img.compositeImage(
        combined,
        overlayImage,
        dstX: 0,
        dstY: originalImage.height,
      );

      // Save the combined image
      final outBytes = img.encodeJpg(combined);
      await imageFile.writeAsBytes(outBytes);
    } catch (e) {
      print("ERROR adding overlay: $e");
    }
  }

  // Render text overlay using Flutter's rendering engine with custom fonts
  Future<Uint8List?> _renderTextOverlay(
    List<String> textLines,
    int imageWidth,
    Settings settings,
  ) async {
    try {
      // Map font size setting to pixel size
      double fontSize;
      switch (settings.fontSize) {
        case 'small':
          fontSize = 14.0;
          break;
        case 'large':
          fontSize = 48.0;
          break;
        case 'medium':
        default:
          fontSize = 24.0;
          break;
      }

      // Get the appropriate Google Font
      TextStyle Function({TextStyle? textStyle}) fontGetter;
      switch (settings.fontFamily) {
        case 'Montserrat':
          fontGetter = GoogleFonts.montserrat;
          break;
        case 'Playfair Display':
          fontGetter = GoogleFonts.playfairDisplay;
          break;
        case 'Poppins':
          fontGetter = GoogleFonts.poppins;
          break;
        case 'Inter':
          fontGetter = GoogleFonts.inter;
          break;
        case 'Raleway':
          fontGetter = GoogleFonts.raleway;
          break;
        default:
          fontGetter = GoogleFonts.montserrat;
          break;
      }

      // Create text style
      final textStyle = fontGetter(
        textStyle: TextStyle(
          fontSize: fontSize,
          color: Colors.white,
          fontWeight: settings.boldAddress
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      );

      // Calculate overlay height
      final lineHeight = fontSize * 1.5;
      final padding = 20.0;
      final overlayHeight = (padding * 2 + textLines.length * lineHeight + 60)
          .toInt();

      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw black background
      final paint = Paint()..color = Colors.black;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, imageWidth.toDouble(), overlayHeight.toDouble()),
        paint,
      );

      // Draw white border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(
        Rect.fromLTRB(40, 10, imageWidth - 40.0, overlayHeight - 10.0),
        borderPaint,
      );

      // Draw text lines
      double yPosition = padding + 10;
      for (int i = 0; i < textLines.length; i++) {
        final textSpan = TextSpan(
          text: textLines[i],
          style: i == 0 && settings.boldAddress && settings.showStampAddress
              ? textStyle.copyWith(fontWeight: FontWeight.w900)
              : textStyle,
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        );

        textPainter.layout(maxWidth: imageWidth - 120.0);
        textPainter.paint(canvas, Offset(60, yPosition));

        yPosition += lineHeight;
      }

      // Draw watermark
      final watermarkStyle = GoogleFonts.montserrat(
        textStyle: const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );

      final watermarkSpan = TextSpan(text: 'RV', style: watermarkStyle);
      final watermarkPainter = TextPainter(
        text: watermarkSpan,
        textDirection: ui.TextDirection.ltr,
      );

      watermarkPainter.layout();
      final watermarkX = (imageWidth - watermarkPainter.width) / 2;
      final watermarkY = overlayHeight - 35.0;
      watermarkPainter.paint(canvas, Offset(watermarkX, watermarkY));

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(imageWidth, overlayHeight);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error rendering text overlay: $e');
      return null;
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
}
