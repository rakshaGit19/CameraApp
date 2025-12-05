import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraControllerManager {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;

  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 10.0;
  double _currentExposure = 0.0;
  double _minExposure = -4.0;
  double _maxExposure = 4.0;

  FlashMode _flashMode = FlashMode.off;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  List<CameraDescription>? get cameras => _cameras;
  FlashMode get flashMode => _flashMode;
  double get currentZoom => _currentZoom;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get currentExposure => _currentExposure;
  double get minExposure => _minExposure;
  double get maxExposure => _maxExposure;

  Future<void> initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No camera found');
      }
      await initializeCameraController();
    } catch (e) {
      throw Exception('Failed to initialize cameras: $e');
    }
  }

  Future<void> initializeCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    _controller = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    await _controller!.initialize();

    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _minExposure = await _controller!.getMinExposureOffset();
    _maxExposure = await _controller!.getMaxExposureOffset();

    _isInitialized = true;
    _currentZoom = _minZoom;
    _currentExposure = 0.0;
  }

  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    _isInitialized = false;
    await _controller?.dispose();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await initializeCameraController();
  }

  Future<void> toggleFlash() async {
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
    _flashMode = newMode;
  }

  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_isInitialized) return;

    final clampedZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clampedZoom);
    _currentZoom = clampedZoom;
  }

  Future<void> setExposure(double exposure) async {
    if (_controller == null || !_isInitialized) return;

    final clampedExposure = exposure.clamp(_minExposure, _maxExposure);
    await _controller!.setExposureOffset(clampedExposure);
    _currentExposure = clampedExposure;
  }

  Future<void> setFocusAndExposurePoint(Offset point) async {
    if (_controller == null || !_isInitialized) return;

    try {
      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);
    } catch (e) {
      print('Error setting focus: $e');
    }
  }

  Future<String> takePicture() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }

    final image = await _controller!.takePicture();
    return image.path;
  }

  Future<void> startVideoRecording() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }
    await _controller!.startVideoRecording();
  }

  Future<String> stopVideoRecording() async {
    if (_controller == null || !_isInitialized) {
      throw Exception('Camera not initialized');
    }
    final video = await _controller!.stopVideoRecording();
    return video.path;
  }

  void dispose() {
    _controller?.dispose();
  }
}
