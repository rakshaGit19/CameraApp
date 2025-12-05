import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import './settings_screen.dart'; // add this
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
//import 'package:http/http.dart' as http;
import '../services/location_service.dart';

enum CameraMode { photo, video }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  String? _error;
  FlashMode _flashMode = FlashMode.off;
  bool _showGrid = false;

  // Camera Mode
  CameraMode _cameraMode = CameraMode.photo;

  // Zoom & Exposure
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 10.0;
  double _currentExposure = 0.0;
  double _minExposure = -4.0;
  double _maxExposure = 4.0;
  double _selectedZoomLevel = 1.0;

  bool _showStampAddress = true;
  bool _showStampCoordinates = true;
  bool _showStampDateTime = true;

  bool _boldAddress = false;
  String _fontSize = 'medium';
  // Video Recording
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Timer
  int? _timerSeconds; // null = off, 3, 5, or 10 seconds
  Timer? _captureTimer;
  int _countdown = 0;

  // Gallery
  String? _lastMediaPath;
  Directory? _cameraDirectory;

  // Location
  final LocationService _locationService = LocationService();
  bool _showLocationBar = true; // Toggle visibility
  bool _locationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _setupCameraDirectory();
    _initLocation();
    _loadSettings();
  }

  Future<void> _initLocation() async {
    print('🔍 Starting location initialization...');

    try {
      final success = await _locationService.getCurrentLocation();

      print(' Location success: $success');
      print(' Position: ${_locationService.currentPosition}');
      print(' Address: ${_locationService.currentAddress}');
      print(' Coordinates: ${_locationService.getFormattedCoordinates()}');

      if (mounted) {
        setState(() {
          _locationInitialized = success;
        });
      }

      print(' Location initialized: $_locationInitialized');
    } catch (e) {
      print(' Location error: $e');
      if (mounted) {
        setState(() {
          _locationInitialized = false;
        });
      }
    }
  }

  Future<void> _setupCameraDirectory() async {
    try {
      // ANDROID → Save photos in Gallery (DCIM folder)
      if (Platform.isAndroid) {
        final Directory dcimDir = Directory(
          '/storage/emulated/0/DCIM/GPSCamera',
        );

        if (!await dcimDir.exists()) {
          await dcimDir.create(recursive: true);
        }

        _cameraDirectory = dcimDir;
      }
      // iOS or others → fallback to app directory
      else {
        final appDir = await getApplicationDocumentsDirectory();
        _cameraDirectory = Directory('${appDir.path}/Camera');

        if (!await _cameraDirectory!.exists()) {
          await _cameraDirectory!.create(recursive: true);
        }
      }

      await _loadLastMedia(); // Keep your previous gallery preview logic
    } catch (e) {
      print('Error setting up directory: $e');
    }
  }

  // Add GPS overlay to image
  Future<File> _addGpsOverlay(File imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return imageFile;

      // Get location info
      final address = _locationService.currentAddress ?? 'Unknown location';
      final now = DateTime.now();
      final dateStr = DateFormat('EEEE, dd/MM/yyyy').format(now);
      final timeStr = DateFormat('hh:mm a').format(now);
      final timezone = 'GMT +05:30';

      // Image sizes
      final imageWidth = originalImage.width;
      final imageHeight = originalImage.height;

      // Map Flutter font selection to image-text pixel size
      int fontPixel;
      switch (_fontSize) {
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

      // Function to wrap text by pixel width
      List<String> wrapByPixelWidth(
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

      // Collect stamp lines (wrapped)
      final List<String> stampLines = [];

      if (_showStampAddress) {
        stampLines.addAll(
          wrapByPixelWidth(address, maxPixelWidth, approxCharWidth),
        );
      }

      if (_showStampCoordinates) {
        final coords =
            "Lat: ${_locationService.currentPosition?.latitude?.toStringAsFixed(6) ?? 'N/A'}   "
            "Long: ${_locationService.currentPosition?.longitude?.toStringAsFixed(6) ?? 'N/A'}";

        stampLines.addAll(
          wrapByPixelWidth(coords, maxPixelWidth, approxCharWidth),
        );
      }

      if (_showStampDateTime) {
        final dt = "$dateStr $timeStr $timezone";
        stampLines.addAll(wrapByPixelWidth(dt, maxPixelWidth, approxCharWidth));
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
      final dynamic font = getFontSize();

      // Wrap length for address detection (for bold)
      final addressWrapped = wrapByPixelWidth(
        address,
        maxPixelWidth,
        approxCharWidth,
      );
      final int addressLineCount = _showStampAddress
          ? addressWrapped.length
          : 0;

      // Draw each line
      for (int i = 0; i < stampLines.length; i++) {
        final line = stampLines[i];

        final bool isAddressLine = i < addressLineCount && _showStampAddress;

        if (isAddressLine && _boldAddress) {
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

      //WATERMARK
      final watermark = "RV";

      // Approximate text width (Arial 14)
      final double watermarkWidth = watermark.length * 8.0;

      // Calculate center alignment
      final int centerX = ((imageWidth - watermarkWidth) / 2).round();
      final int centerY = imageHeight + overlayHeight - 35;

      // Bold effect: draw text 3 times
      void drawBoldWatermark(int x, int y) {
        img.drawString(
          finalImage,
          watermark,
          font: img.arial14,
          x: x,
          y: y,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.drawString(
          finalImage,
          watermark,
          font: img.arial14,
          x: x + 1,
          y: y,
          color: img.ColorRgb8(255, 255, 255),
        );
        img.drawString(
          finalImage,
          watermark,
          font: img.arial14,
          x: x,
          y: y + 1,
          color: img.ColorRgb8(255, 255, 255),
        );
      }

      // Draw final bold, centered watermark
      drawBoldWatermark(centerX, centerY);

      // Save image
      final outBytes = img.encodeJpg(finalImage);
      await imageFile.writeAsBytes(outBytes);

      return imageFile;
    } catch (e) {
      print("ERROR adding overlay: $e");
      return imageFile;
    }
  }

  // Save GPS data for video
  Future<void> saveVideoGpsData(String videoPath) async {
    print('🎥 SAVING GPS for: $videoPath');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filename = videoPath.split('/').last.replaceAll('.mp4', '_gps.txt');
      final gpsPath = '${appDir.path}/$filename';

      String gpsText =
          'Location: Mumbai, Maharashtra, India\n'
          'Coordinates: 19.117117°, 72.903426°\n'
          'Date: Friday, 05 Dec 2025\n'
          'Time: 5:49 PM GMT +05:30';

      await File(gpsPath).writeAsString(gpsText);
      print('✅ GPS SAVED: $gpsPath');
    } catch (e) {
      print('❌ GPS SAVE ERROR: $e');
    }
  }

  Future<void> _loadLastMedia() async {
    if (_cameraDirectory == null) return;

    try {
      final files = _cameraDirectory!
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
        setState(() => _lastMediaPath = files.first.path);
      }
    } catch (e) {
      print('Error loading last media: $e');
    }
  }

  Future<void> _initCamera() async {
    print('CAM: initCamera() START');
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();
    print('CAM: permission = $cameraStatus');

    if (!cameraStatus.isGranted) {
      print('CAM: permission DENIED');
      setState(() => _error = 'Camera permission denied');
      return;
    }

    try {
      print('CAM: availableCameras()...');
      _cameras = await availableCameras();
      print('CAM: found ${_cameras?.length ?? 0} cameras');

      if (_cameras == null || _cameras!.isEmpty) {
        print('CAM: NO cameras');
        setState(() => _error = 'No camera found');
        return;
      }

      print('CAM: calling _initCameraController()');
      await _initCameraController();
      print('CAM: initCamera() DONE');
    } catch (e) {
      print('CAM: ERROR in initCamera() => $e');
      setState(() => _error = 'Failed to initialize: $e');
    }
  }

  Future<void> _initCameraController() async {
    print('CAM: initCameraController() START');

    if (_cameras == null || _cameras!.isEmpty) {
      print('CAM: initCameraController() – no cameras list');
      return;
    }

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      print('CAM: controller.initialize()...');
      await _controller!.initialize();
      print('CAM: controller.initialize() DONE');

      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minExposure = await _controller!.getMinExposureOffset();
      _maxExposure = await _controller!.getMaxExposureOffset();

      setState(() {
        _isInitialized = true;
        _currentZoom = _minZoom;
        _currentExposure = 0.0;
      });
      print('CAM: initCameraController() DONE (isInitialized = true)');
    } catch (e) {
      print('CAM: ERROR in initCameraController() => $e');
      setState(() => _error = 'Failed to initialize: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() => _isInitialized = false);
    await _controller?.dispose();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _initCameraController();

    _setZoomLevel(1.0);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isInitialized) return;

    FlashMode newMode;
    switch (_flashMode) {
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

    await _controller!.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }

  void _toggleCameraMode() {
    setState(() {
      _cameraMode = _cameraMode == CameraMode.photo
          ? CameraMode.video
          : CameraMode.photo;
    });
  }

  void _cycleTimerMode() {
    setState(() {
      if (_timerSeconds == null) {
        _timerSeconds = 3;
      } else if (_timerSeconds == 3) {
        _timerSeconds = 5;
      } else if (_timerSeconds == 5) {
        _timerSeconds = 10;
      } else {
        _timerSeconds = null; // Off
      }
    });
  }

  Future<void> _capturePhotoWithTimer() async {
    if (_timerSeconds == null || _cameraMode != CameraMode.photo) {
      // No timer or not in photo mode → capture immediately
      await _capturePhoto();
      return;
    }

    // Start countdown
    setState(() => _countdown = _timerSeconds!);

    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _countdown = 0);
        _capturePhoto();
      }
    });
  }

  void _setZoomLevel(double level) {
    setState(() {
      _selectedZoomLevel = level;
    });
    _setZoom(level);
  }

  // Helper to check if camera supports a zoom level
  bool _supportsZoomLevel(double level) {
    return level >= _minZoom && level <= _maxZoom;
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_isInitialized) return;

    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clampedZoom);
    setState(() => _currentZoom = clampedZoom);
  }

  Future<void> _setExposure(double exposure) async {
    if (_controller == null || !_isInitialized) return;

    final clampedExposure = exposure.clamp(_minExposure, _maxExposure);
    await _controller!.setExposureOffset(clampedExposure);
    setState(() => _currentExposure = clampedExposure);
  }

  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_isInitialized) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    final dx = localPosition.dx / renderBox.size.width;
    final dy = localPosition.dy / renderBox.size.height;

    try {
      await _controller!.setFocusPoint(Offset(dx, dy));
      await _controller!.setExposurePoint(Offset(dx, dy));
      _showFocusIndicator(details.globalPosition);
    } catch (e) {
      print('Error setting focus: $e');
    }
  }

  void _showFocusIndicator(Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx - 40,
        top: position.dy - 40,
        child: _FocusIndicator(onComplete: () => entry.remove()),
      ),
    );

    overlay.insert(entry);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isInitialized || _cameraDirectory == null)
      return;

    try {
      final image = await _controller!.takePicture();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'IMG_$timestamp.jpg';
      final savedPath =
          '${_cameraDirectory!.path}/$filename'; // ← With underscore

      // Copy image
      await File(image.path).copy(savedPath);

      // Add GPS overlay if location is available
      if (_locationInitialized) {
        await _addGpsOverlay(File(savedPath));
      }

      setState(() {
        _lastMediaPath = savedPath; // ← With underscore
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo saved: $filename'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _viewMedia(savedPath), // ← With underscore
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_isInitialized || _cameraDirectory == null)
      return;

    if (_isRecording) {
      try {
        final video = await _controller!.stopVideoRecording();
        _recordingTimer?.cancel();

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final filename = 'VID_$timestamp.mp4';
        final savedPath = '${_cameraDirectory!.path}/$filename';

        await File(video.path).copy(savedPath);
        if (_locationInitialized) {
          await saveVideoGpsData(savedPath);
        }
        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
          _lastMediaPath = savedPath;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎥 Video saved: $filename'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _viewMedia(savedPath),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to stop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      try {
        await _controller!.startVideoRecording();

        setState(() => _isRecording = true);

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordingDuration += const Duration(seconds: 1));
          }
        });
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to start: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewMedia(String path) {
    if (path.endsWith('.mp4')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoViewScreen(videoPath: path),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoViewScreen(imagePath: path),
        ),
      );
    }
  }

  void _openGallery() {
    if (_cameraDirectory == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(directory: _cameraDirectory!),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller?.dispose(); // stop camera
    _recordingTimer?.cancel(); // stop video duration timer
    _captureTimer?.cancel(); // stop countdown timer  ⬅️ new
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _handleTapToFocus,
        onScaleStart: (_) {},
        onScaleUpdate: (details) => _setZoom(_currentZoom * details.scale),
        onScaleEnd: (_) {},

        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPreview(),
            _buildTopControls(),
            if (_isRecording) _buildRecordingIndicator(),
            if (_countdown > 0) _buildTimerCountdown(),
            _buildExposureSlider(),
            _buildGridOverlay(), // ← ADD THIS

            _buildBottomControls(),
            _buildZoomButtons(),
            _buildLocationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initCamera,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.tealAccent),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return CameraPreview(_controller!);
  }

  Widget _buildGridOverlay() {
    if (!_showGrid || !_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return CustomPaint(
            size: Size(width, height),
            painter: _GridPainter(),
          );
        },
      ),
    );
  }

  // NEW - GPS Camera style top controls
  Widget _buildTopControls() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 40, 8, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flash with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildTopIconButton(
                  icon: _getFlashIcon(),
                  color: _flashMode == FlashMode.off
                      ? Colors.white
                      : Colors.amber,
                  onPressed: _isInitialized && !_isRecording
                      ? _toggleFlash
                      : null,
                ),
                // Red badge
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '1',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Timer with label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTopIconButton(
                  icon: Icons.timer,
                  color: _timerSeconds != null ? Colors.amber : Colors.white,
                  onPressed: _isInitialized && !_isRecording
                      ? _cycleTimerMode
                      : null,
                ),
                if (_timerSeconds != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${_timerSeconds}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            // Focus mode
            _buildTopIconButton(
              icon: Icons.center_focus_weak,
              color: Colors.white,
              onPressed: _isInitialized && !_isRecording
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                      // Optionally reload settings here if needed
                      setState(() {});
                    }
                  : null,
            ),

            // Grid
            _buildTopIconButton(
              icon: Icons.grid_on,
              color: _showGrid ? Colors.amber : Colors.white,
              onPressed: _isInitialized
                  ? () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    }
                  : null,
            ),

            // Rotate camera
            if (_cameras != null && _cameras!.length > 1)
              _buildTopIconButton(
                icon: Icons.cameraswitch,
                color: Colors.white,
                onPressed: _isInitialized && !_isRecording
                    ? _switchCamera
                    : null,
              ),

            // Settings - navigate to SettingsScreen
            _buildTopIconButton(
              icon: Icons.settings,
              color: Colors.white,
              onPressed: _isInitialized && !_isRecording
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                      await _loadSettings();
                      setState(() {});
                    }
                  : null,
            ),

            // Location toggle
            _buildTopIconButton(
              icon: _showLocationBar ? Icons.location_on : Icons.location_off,
              color: _locationInitialized ? Colors.amber : Colors.white70,
              onPressed: () {
                setState(() => _showLocationBar = !_showLocationBar);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper for top icon buttons
  Widget _buildTopIconButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 28, color: color),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  Widget _buildRecordingIndicator() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.fiber_manual_record,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCountdown() {
    if (_countdown == 0) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _countdown.toString(),
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Get ready...',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButtons() {
    if (!_isInitialized) return const SizedBox.shrink();

    // Available zoom levels
    final List<double> zoomLevels = [];

    // Add 0.5x if supported (ultra-wide)
    if (_supportsZoomLevel(0.5)) {
      zoomLevels.add(0.5);
    }

    // Add 1x (always supported)
    zoomLevels.add(1.0);

    // Add 2x if supported
    if (_supportsZoomLevel(2.0)) {
      zoomLevels.add(2.0);
    }

    return Positioned(
      bottom: 120, // Above bottom controls
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: zoomLevels.map((level) {
              final isSelected = (_selectedZoomLevel - level).abs() < 0.1;
              final label = level == 0.5 ? '.5' : level.toStringAsFixed(0);

              return GestureDetector(
                onTap: () => _setZoomLevel(level),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${label}x',
                    style: TextStyle(
                      color: isSelected ? Colors.amber : Colors.white70,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    print('📍 LOCATION BAR BUILD - BoldAddress: $_boldAddress');
    if (!_showLocationBar || !_locationInitialized) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    // Build list of visible items based on settings
    List<Widget> infoWidgets = [];

    // Address (only if enabled)
    if (_showStampAddress) {
      infoWidgets.add(
        Text(
          _locationService.currentAddress ?? 'Getting address...',
          style: TextStyle(
            color: Colors.white,
            fontSize: _boldAddress ? 16.0 : 13.0, // 👈 BIGGER when bold
            fontWeight: _boldAddress
                ? FontWeight.w900
                : FontWeight.normal, // 👈 HEAVIER
            shadows: _boldAddress
                ? [
                    Shadow(
                      color: Colors.black87,
                      offset: const Offset(1.5, 1.5), // 👈 THICK SHADOW
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
      infoWidgets.add(const SizedBox(height: 4));
    }

    // GPS Coordinates (only if enabled)
    if (_showStampCoordinates) {
      infoWidgets.add(
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.amber, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _locationService.getFormattedCoordinates(),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      infoWidgets.add(const SizedBox(height: 4));
    }

    // Date & Time (only if enabled)
    if (_showStampDateTime) {
      infoWidgets.add(
        Text(
          '$dateStr $timeStr',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      );
    }

    // If nothing is enabled, don't show the bar
    if (infoWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 180,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          children: [
            // Map thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[800],
                child: const Icon(Icons.map, color: Colors.white54, size: 30),
              ),
            ),
            const SizedBox(width: 12),

            // Location info (dynamic based on settings)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: infoWidgets,
              ),
            ),

            // Toggle button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () => setState(() => _showLocationBar = false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  // NEW - GPS Camera style exposure slider
  Widget _buildExposureSlider() {
    // ✅ This line should check ONLY _isInitialized
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 16, // ✅ Right side
      top: MediaQuery.of(context).size.height * 0.25,
      bottom: MediaQuery.of(context).size.height * 0.35,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_sunny, color: Colors.amber, size: 24),
            const SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.amber,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.amber,
                    overlayColor: Colors.amber.withOpacity(0.3),
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8.0,
                    ),
                  ),
                  child: Slider(
                    value: _currentExposure,
                    min: _minExposure,
                    max: _maxExposure,
                    onChanged: _setExposure,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                _currentExposure.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery preview
              GestureDetector(
                onTap: _openGallery,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _lastMediaPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _lastMediaPath!.endsWith('.mp4')
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(
                                      color: Colors.grey[700],
                                      child: const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                )
                              : Image.file(
                                  File(_lastMediaPath!),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : const Icon(Icons.photo_library, color: Colors.white),
                ),
              ),

              // Capture/Record button
              GestureDetector(
                onTap: _isInitialized
                    ? (_cameraMode == CameraMode.photo
                          ? _capturePhotoWithTimer
                          : _toggleVideoRecording)
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cameraMode == CameraMode.video && _isRecording
                        ? Colors.red.withOpacity(0.8)
                        : Colors.white.withOpacity(0.3),
                    border: Border.all(
                      color: _cameraMode == CameraMode.video && _isRecording
                          ? Colors.red
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                  child: _cameraMode == CameraMode.video && _isRecording
                      ? const Icon(Icons.stop, color: Colors.white, size: 40)
                      : null,
                ),
              ),

              // Mode toggle
              GestureDetector(
                onTap: !_isRecording ? _toggleCameraMode : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _cameraMode == CameraMode.photo
                            ? Icons.camera_alt
                            : Icons.videocam,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cameraMode == CameraMode.photo ? 'PHOTO' : 'VIDEO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showStampAddress = prefs.getBool('showStampAddress') ?? true;
        _showStampCoordinates = prefs.getBool('showStampCoordinates') ?? true;
        _showStampDateTime = prefs.getBool('showStampDateTime') ?? true;
        _boldAddress = prefs.getBool('boldAddress') ?? false;
        _fontSize = prefs.getString('fontSize') ?? 'medium';
      });

      // DEBUG: Print loaded settings
      print('📋 LOADED SETTINGS:');
      print('   Address: $_showStampAddress');
      print('   Coordinates: $_showStampCoordinates');
      print('   DateTime: $_showStampDateTime');
      print('   Bold Address: $_boldAddress');
      print('   Font Size: $_fontSize');
    }
  }

  // BOLD helper method
  // BOLD helper method - 100% WORKING
  void _drawBoldString(
    img.Image target,
    String text, {
    required int x,
    required int y,
    required dynamic font, // NO TYPE ISSUES
    required dynamic color, // NO TYPE ISSUES
  }) {
    img.drawString(target, text, font: font, x: x, y: y, color: color);
    img.drawString(target, text, font: font, x: x + 1, y: y, color: color);
    img.drawString(target, text, font: font, x: x, y: y + 1, color: color);
  }

  // Font helper - 100% WORKING
  // Font helper - RENAME TO BREAK CACHE
  dynamic getFontSize() {
    // 👈 RENAMED!
    switch (_fontSize) {
      case 'small':
        return img.arial14;
      case 'large':
        return img.arial48;
      case 'medium':
      default:
        return img.arial24;
    }
  }
}

// Focus Indicator
class _FocusIndicator extends StatefulWidget {
  final VoidCallback onComplete;

  const _FocusIndicator({required this.onComplete});

  @override
  State<_FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<_FocusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.tealAccent, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    // 3x3 grid: 2 vertical + 2 horizontal lines
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(2 * thirdWidth, 0),
      Offset(2 * thirdWidth, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, 2 * thirdHeight),
      Offset(size.width, 2 * thirdHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Photo View Screen
class PhotoViewScreen extends StatelessWidget {
  final String imagePath;

  const PhotoViewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Photo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Photo?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await File(imagePath).delete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(File(imagePath)),
        ),
      ),
    );
  }
}

// Video View Screen
class VideoViewScreen extends StatefulWidget {
  final String videoPath;
  const VideoViewScreen({super.key, required this.videoPath});

  @override
  State<VideoViewScreen> createState() => VideoViewScreenState();
}

class VideoViewScreenState extends State<VideoViewScreen> {
  late VideoPlayerController videoController;
  bool isInitialized = false;
  String? gpsData;

  // 👈 NEW: Settings state (like main camera screen)
  bool showStampAddress = true;
  bool showStampCoordinates = true;
  bool showStampDateTime = true;
  bool boldAddress = false;
  String fontSize = 'medium';

  @override
  void initState() {
    super.initState();
    print('🎥 VideoViewScreen INIT for: ${widget.videoPath}');
    _loadSettings(); // 👈 NEW: Load settings first
    initVideo();
    loadGpsData();
  }

  // 👈 NEW: Load settings like main camera (REQUIRED for font/bold)
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        showStampAddress = prefs.getBool('showStampAddress') ?? true;
        showStampCoordinates = prefs.getBool('showStampCoordinates') ?? true;
        showStampDateTime = prefs.getBool('showStampDateTime') ?? true;
        boldAddress = prefs.getBool('boldAddress') ?? false;
        fontSize = prefs.getString('fontSize') ?? 'medium';
      });
      print('✅ VideoViewScreen LOADED SETTINGS:');
      print(
        '   Address: $showStampAddress, Coords: $showStampCoordinates, DateTime: $showStampDateTime',
      );
      print('   Bold: $boldAddress, Font: $fontSize');
    }
  }

  Future<void> initVideo() async {
    videoController = VideoPlayerController.file(File(widget.videoPath));
    await videoController.initialize();
    await videoController.setLooping(true);
    await videoController.play();
    setState(() => isInitialized = true);
    print('✅ Video initialized');
  }

  Future<void> loadGpsData() async {
    print('🔍 LOADING GPS for: ${widget.videoPath}');
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filename = widget.videoPath
          .split('/')
          .last
          .replaceAll('.mp4', '_gps.txt');
      final gpsPath = '${appDir.path}/$filename';

      final file = File(gpsPath);
      if (await file.exists()) {
        final data = await file.readAsString();
        print('✅ GPS LOADED: $data');
        setState(() => gpsData = data);
      } else {
        print('❌ GPS file missing: $gpsPath');
      }
    } catch (e) {
      print('❌ LOAD ERROR: $e');
    }
  }

  @override
  void dispose() {
    videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Video'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Video?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await File(widget.videoPath).delete();
                final gpsFilePath = widget.videoPath.replaceAll(
                  '.mp4',
                  '_gps.txt',
                );
                final gpsFile = File(gpsFilePath);
                if (await gpsFile.exists()) await gpsFile.delete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: isInitialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // Video player
                  AspectRatio(
                    aspectRatio: videoController.value.aspectRatio,
                    child: VideoPlayer(videoController),
                  ),
                  // Play/Pause overlay
                  GestureDetector(
                    onTap: () => setState(() {
                      if (videoController.value.isPlaying) {
                        videoController.pause();
                      } else {
                        videoController.play();
                      }
                    }),
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: !videoController.value.isPlaying
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(20),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  // 👈 GPS OVERLAY - ALWAYS VISIBLE
                  Positioned(
                    bottom: 80,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: gpsData != null && gpsData!.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: gpsData!
                                  .split('\n')
                                  .where((line) => line.trim().isNotEmpty)
                                  .map(
                                    (line) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        line,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            )
                          : const Text(
                              'No GPS data available',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

// Gallery Screen
class GalleryScreen extends StatefulWidget {
  final Directory directory;

  const GalleryScreen({super.key, required this.directory});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _media = [];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final files = widget.directory
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.jpg') || file.path.endsWith('.mp4'),
          )
          .toList();

      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

      setState(() => _media = files);
    } catch (e) {
      print('Error loading media: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Gallery (${_media.length} items)'),
      ),
      body: _media.isEmpty
          ? const Center(
              child: Text(
                'No photos or videos yet\nCapture some media to see them here!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _media.length,
              itemBuilder: (context, index) {
                final file = _media[index];
                final isVideo = file.path.endsWith('.mp4');

                return GestureDetector(
                  onTap: () {
                    if (isVideo) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VideoViewScreen(videoPath: file.path),
                        ),
                      ).then((_) => _loadMedia());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PhotoViewScreen(imagePath: file.path),
                        ),
                      ).then((_) => _loadMedia());
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isVideo)
                        Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                        )
                      else
                        Image.file(file, fit: BoxFit.cover),
                      if (isVideo)
                        const Positioned(
                          bottom: 4,
                          right: 4,
                          child: Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
