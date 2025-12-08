import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import './settings_screen.dart';
import '../services/location_service.dart';
import '../providers/settings_provider.dart';
import '../providers/location_provider.dart';
import '../providers/camera_provider.dart';

enum CameraMode { photo, video }

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  // Local UI State for non-business logic
  int? _timerSeconds;
  Timer? _captureTimer;
  int _countdown = 0;
  bool _showGrid = false;
  bool _showLocationBar = true;
  CameraMode _cameraMode = CameraMode.photo;

  // To track status changes for SnackBar
  String? _lastStatusMessage;

  @override
  void dispose() {
    _captureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(CameraNotifier.provider);

    // Listen for status messages (side effects)
    ref.listen(CameraNotifier.provider, (previous, next) {
      if (next.statusMessage != null &&
          next.statusMessage != _lastStatusMessage) {
        _lastStatusMessage = next.statusMessage;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.statusMessage!),
              backgroundColor: Colors.green,
              action: next.lastMediaPath != null
                  ? SnackBarAction(
                      label: 'View',
                      textColor: Colors.white,
                      onPressed: () => _viewMedia(next.lastMediaPath!),
                    )
                  : null,
            ),
          );
        }
      }
      if (next.error != null && next.error != previous?.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
          );
        }
      }
    });

    // Loading / Error States
    if (cameraState.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                cameraState.error!,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Re-initialize logic?
                  // For now, simple re-build might triggers provider init again if disposed?
                  // Actually provider is alive. We might need a retry method in provider.
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!cameraState.isInitialized || cameraState.controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
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
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) => _handleTapToFocus(details, context),
        onScaleUpdate: (details) {
          ref
              .read(CameraNotifier.provider.notifier)
              .setZoom(cameraState.currentZoom * details.scale);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(cameraState.controller!),
            _buildTopControls(cameraState),
            if (cameraState.isRecording)
              _buildRecordingIndicator(cameraState.recordingDuration),
            if (_countdown > 0) _buildTimerCountdown(),
            _buildExposureSlider(cameraState),
            _buildGridOverlay(cameraState),
            _buildBottomControls(cameraState),
            _buildZoomButtons(cameraState),
            _buildLocationBar(),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTapToFocus(
    TapDownDetails details,
    BuildContext context,
  ) async {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPoint = renderBox.globalToLocal(details.globalPosition);
    final dx = localPoint.dx / renderBox.size.width;
    final dy = localPoint.dy / renderBox.size.height;

    await ref
        .read(CameraNotifier.provider.notifier)
        .setFocusPoint(Offset(dx, dy));

    _showFocusIndicator(context, details.globalPosition);
  }

  void _showFocusIndicator(BuildContext context, Offset position) {
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

  void _cycleTimerMode() {
    setState(() {
      if (_timerSeconds == null)
        _timerSeconds = 3;
      else if (_timerSeconds == 3)
        _timerSeconds = 5;
      else if (_timerSeconds == 5)
        _timerSeconds = 10;
      else
        _timerSeconds = null;
    });
  }

  void _toggleCameraMode() {
    setState(() {
      _cameraMode = _cameraMode == CameraMode.photo
          ? CameraMode.video
          : CameraMode.photo;
    });
  }

  Future<void> _capturePhotoWithTimer() async {
    if (_timerSeconds == null) {
      await ref.read(CameraNotifier.provider.notifier).takePhoto();
      return;
    }

    setState(() => _countdown = _timerSeconds!);
    _captureTimer?.cancel();
    _captureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _countdown = 0);
        ref.read(CameraNotifier.provider.notifier).takePhoto();
      }
    });
  }

  void _viewMedia(String path) {
    if (path.endsWith('.mp4')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoViewScreen(videoPath: path)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PhotoViewScreen(imagePath: path)),
      );
    }
  }

  Future<void> _openGallery() async {
    // Replicate directory logic since it is platform standard
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/DCIM/GPSCamera');
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dir = Directory('${appDir.path}/Camera');
    }

    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GalleryScreen(directory: dir!)),
      );
    }
  }

  // --- WIDGET BUILDERS ---

  Widget _buildTopControls(CameraState state) {
    final locationState = ref.watch(LocationNotifier.provider);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 40, 8, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flash
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildTopIconButton(
                  icon: _getFlashIcon(state.flashMode),
                  color: state.flashMode == FlashMode.off
                      ? Colors.white
                      : Colors.amber,
                  onPressed: !state.isRecording
                      ? () => ref
                            .read(CameraNotifier.provider.notifier)
                            .toggleFlash()
                      : null,
                ),
                // Dummy badge from original code (assuming logic wanted it)
                // Keeping it static 1 for now as per original code seems hardcoded
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
            // Timer
            Row(
              children: [
                _buildTopIconButton(
                  icon: Icons.timer,
                  color: _timerSeconds != null ? Colors.amber : Colors.white,
                  onPressed: !state.isRecording ? _cycleTimerMode : null,
                ),
                if (_timerSeconds != null)
                  Text(
                    '${_timerSeconds}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            // Settings Nav
            _buildTopIconButton(
              icon: Icons
                  .center_focus_weak, // Represents Settings/Focus mode entry in original
              color: Colors.white,
              onPressed: !state.isRecording
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    )
                  : null,
            ),
            // Grid
            _buildTopIconButton(
              icon: Icons.grid_on,
              color: _showGrid ? Colors.amber : Colors.white,
              onPressed: () => setState(() => _showGrid = !_showGrid),
            ),
            // Rotate
            if (state.cameras != null && state.cameras!.length > 1)
              _buildTopIconButton(
                icon: Icons.cameraswitch,
                color: Colors.white,
                onPressed: !state.isRecording
                    ? () => ref
                          .read(CameraNotifier.provider.notifier)
                          .switchCamera()
                    : null,
              ),
            // Settings
            _buildTopIconButton(
              icon: Icons.settings,
              color: Colors.white,
              onPressed: !state.isRecording
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    )
                  : null,
            ),
            // Location Toggle
            _buildTopIconButton(
              icon: _showLocationBar ? Icons.location_on : Icons.location_off,
              color: locationState.isInitialized
                  ? Colors.amber
                  : Colors.white70,
              onPressed: () =>
                  setState(() => _showLocationBar = !_showLocationBar),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildRecordingIndicator(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final durationText = '$minutes:$seconds';

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
                durationText,
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

  Widget _buildZoomButtons(CameraState state) {
    if (!state.isInitialized) return const SizedBox.shrink();

    // Check availability based on min/max zoom
    List<double> levels = [];
    if (state.minZoom <= 0.5) levels.add(0.5);
    levels.add(1.0);
    if (state.maxZoom >= 2.0) levels.add(2.0);

    return Positioned(
      bottom: 120,
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
            children: levels.map((level) {
              final isSelected = (state.currentZoom - level).abs() < 0.1;
              final label = level == 0.5 ? '.5' : level.toStringAsFixed(0);
              return GestureDetector(
                onTap: () =>
                    ref.read(CameraNotifier.provider.notifier).setZoom(level),
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

  Widget _buildExposureSlider(CameraState state) {
    if (!state.isInitialized) return const SizedBox.shrink();

    return Positioned(
      right: 16,
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
                    value: state.currentExposure,
                    min: state.minExposure,
                    max: state.maxExposure,
                    onChanged: (v) => ref
                        .read(CameraNotifier.provider.notifier)
                        .setExposure(v),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                state.currentExposure.toStringAsFixed(1),
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

  Widget _buildGridOverlay(CameraState state) {
    if (!_showGrid || !state.isInitialized) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }

  Widget _buildBottomControls(CameraState state) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery
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
                  child: state.lastMediaPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: state.lastMediaPath!.endsWith('.mp4')
                              ? const Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                )
                              : Image.file(
                                  File(state.lastMediaPath!),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : const Icon(Icons.photo_library, color: Colors.white),
                ),
              ),

              // Capture
              GestureDetector(
                onTap: state.isInitialized
                    ? () {
                        if (_cameraMode == CameraMode.photo) {
                          _capturePhotoWithTimer();
                        } else {
                          ref
                              .read(CameraNotifier.provider.notifier)
                              .toggleVideoRecording();
                        }
                      }
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cameraMode == CameraMode.video && state.isRecording
                        ? Colors.red.withOpacity(0.8)
                        : Colors.white.withOpacity(0.3),
                    border: Border.all(
                      color:
                          _cameraMode == CameraMode.video && state.isRecording
                          ? Colors.red
                          : Colors.white,
                      width: 4,
                    ),
                  ),
                  child: _cameraMode == CameraMode.video && state.isRecording
                      ? const Icon(Icons.stop, color: Colors.white, size: 40)
                      : null,
                ),
              ),

              // Mode Switch
              GestureDetector(
                onTap: !state.isRecording ? _toggleCameraMode : null,
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

  Widget _buildLocationBar() {
    final settings = ref.watch(SettingsNotifier.provider);
    final locationState = ref.watch(LocationNotifier.provider);

    if (!_showLocationBar || !locationState.isInitialized) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    // Get the selected font family
    TextStyle getTextStyle({
      required Color color,
      required double fontSize,
      FontWeight? fontWeight,
      List<Shadow>? shadows,
    }) {
      switch (settings.fontFamily) {
        case 'Montserrat':
          return GoogleFonts.montserrat(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
        case 'Playfair Display':
          return GoogleFonts.playfairDisplay(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
        case 'Poppins':
          return GoogleFonts.poppins(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
        case 'Inter':
          return GoogleFonts.inter(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
        case 'Raleway':
          return GoogleFonts.raleway(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
        default:
          return GoogleFonts.montserrat(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            shadows: shadows,
          );
      }
    }

    List<Widget> infoWidgets = [];
    if (settings.showStampAddress) {
      infoWidgets.add(
        Text(
          locationState.address ?? 'Getting address...',
          style: getTextStyle(
            color: Colors.white,
            fontSize: settings.boldAddress ? 16.0 : 13.0,
            fontWeight: settings.boldAddress
                ? FontWeight.w900
                : FontWeight.normal,
            shadows: settings.boldAddress
                ? const [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(1.5, 1.5),
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
    if (settings.showStampCoordinates) {
      infoWidgets.add(
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.amber, size: 12),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                locationState.formattedCoordinates ?? 'Getting location...',
                style: getTextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      infoWidgets.add(const SizedBox(height: 4));
    }
    if (settings.showStampDateTime) {
      infoWidgets.add(
        Text(
          '$dateStr  $timeStr',
          style: getTextStyle(color: Colors.white60, fontSize: 11),
        ),
      );
    }

    if (infoWidgets.isEmpty) return const SizedBox.shrink();

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: infoWidgets,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: () => setState(() => _showLocationBar = false),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFlashIcon(FlashMode mode) {
    switch (mode) {
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
}

// --- Helpers & Auxiliary Screens ---

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
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.tealAccent, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;
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
                builder: (_) => AlertDialog(
                  title: const Text('Delete?'),
                  content: const Text('Cannot undo.'),
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
class VideoViewScreen extends ConsumerStatefulWidget {
  final String videoPath;
  const VideoViewScreen({super.key, required this.videoPath});
  @override
  ConsumerState<VideoViewScreen> createState() => _VideoViewScreenState();
}

class _VideoViewScreenState extends ConsumerState<VideoViewScreen> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  String? _gpsData;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadGpsData();
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    await _videoController.initialize();
    await _videoController.setLooping(true);
    await _videoController.play();
    setState(() => _isInitialized = true);
  }

  Future<void> _loadGpsData() async {
    try {
      final videoFilename = widget.videoPath.split('/').last;
      final appDir = await getApplicationDocumentsDirectory();
      final appGpsPath =
          '${appDir.path}/${videoFilename.replaceAll('.mp4', '_gps.txt')}';
      final appFile = File(appGpsPath);
      if (await appFile.exists()) {
        final data = await appFile.readAsString();
        setState(() => _gpsData = data);
        return;
      }
      final dcimFile = File(widget.videoPath.replaceAll('.mp4', '_gps.txt'));
      if (await dcimFile.exists()) {
        final data = await dcimFile.readAsString();
        setState(() => _gpsData = data);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController.dispose();
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
                builder: (_) => AlertDialog(
                  title: const Text('Delete?'),
                  content: const Text('Cannot undo.'),
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
                final gpsFile = File(
                  widget.videoPath.replaceAll('.mp4', '_gps.txt'),
                );
                if (await gpsFile.exists()) await gpsFile.delete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: _isInitialized
            ? Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                  GestureDetector(
                    onTap: () => setState(
                      () => _videoController.value.isPlaying
                          ? _videoController.pause()
                          : _videoController.play(),
                    ),
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: !_videoController.value.isPlaying
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
                  if (_gpsData != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Builder(
                          builder: (context) {
                            final settings = ref.watch(
                              SettingsNotifier.provider,
                            );

                            // Map settings to font style
                            TextStyle getTextStyle() {
                              TextStyle baseStyle = const TextStyle(
                                color: Colors.white,
                              );

                              switch (settings.fontFamily) {
                                case 'Montserrat':
                                  baseStyle = GoogleFonts.montserrat(
                                    textStyle: baseStyle,
                                  );
                                  break;
                                case 'Playfair Display':
                                  baseStyle = GoogleFonts.playfairDisplay(
                                    textStyle: baseStyle,
                                  );
                                  break;
                                case 'Poppins':
                                  baseStyle = GoogleFonts.poppins(
                                    textStyle: baseStyle,
                                  );
                                  break;
                                case 'Inter':
                                  baseStyle = GoogleFonts.inter(
                                    textStyle: baseStyle,
                                  );
                                  break;
                                case 'Raleway':
                                  baseStyle = GoogleFonts.raleway(
                                    textStyle: baseStyle,
                                  );
                                  break;
                                default:
                                  baseStyle = GoogleFonts.montserrat(
                                    textStyle: baseStyle,
                                  );
                              }

                              // Map size
                              double fontSize;
                              switch (settings.fontSize) {
                                case 'small':
                                  fontSize = 12.0;
                                  break;
                                case 'large':
                                  fontSize = 20.0;
                                  break;
                                case 'medium':
                                default:
                                  fontSize = 16.0;
                                  break;
                              }

                              return baseStyle.copyWith(
                                fontSize: fontSize,
                                fontWeight: settings.boldAddress
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              );
                            }

                            return Text(_gpsData!, style: getTextStyle());
                          },
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Gallery (${_media.length})'),
      ),
      body: _media.isEmpty
          ? const Center(
              child: Text('No media', style: TextStyle(color: Colors.white70)),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isVideo
                          ? VideoViewScreen(videoPath: file.path)
                          : PhotoViewScreen(imagePath: file.path),
                    ),
                  ).then((_) => _loadMedia()),
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
