import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ScanController extends ChangeNotifier {
  // ── State Variables ──
  CameraController? _cameraCtrl;
  CameraController? get cameraCtrl => _cameraCtrl;

  bool _isCameraReady = false;
  bool get isCameraReady => _isCameraReady;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  // Realtime OCR dinonaktifkan — selalu 0 / false
  double get confidence => 0.0;
  int get textBlockCount => 0;
  bool get hasTextInFrame => false;

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras[0],
      );

      final ctrl = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();
      await ctrl.setFlashMode(FlashMode.off);
      await ctrl.setFocusMode(FocusMode.auto);

      _cameraCtrl = ctrl;
      _isCameraReady = true;
      notifyListeners();
      // Realtime OCR dinonaktifkan — hemat memori
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  /// No-op — realtime OCR dinonaktifkan.
  void startRealtimeOcr() {}

  /// No-op — realtime OCR dinonaktifkan.
  void stopRealtimeOcr() {}

  Future<File?> captureImage() async {
    if (!_isCameraReady || _isCapturing || _cameraCtrl == null) return null;

    _isCapturing = true;
    notifyListeners();

    try {
      final image = await _cameraCtrl!.takePicture();
      return File(image.path);
    } catch (e) {
      debugPrint('❌ Capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    super.dispose();
  }
}
