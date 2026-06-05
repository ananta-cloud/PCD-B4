import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanController extends ChangeNotifier {
  // ── State Variables ──
  CameraController? _cameraCtrl;
  CameraController? get cameraCtrl => _cameraCtrl;

  bool _isCameraReady = false;
  bool get isCameraReady => _isCameraReady;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  double _confidence = 0.0;
  double get confidence => _confidence;

  int _textBlockCount = 0;
  int get textBlockCount => _textBlockCount;

  bool _hasTextInFrame = false;
  bool get hasTextInFrame => _hasTextInFrame;

  // ── Services ──
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Timer? _ocrTimer;
  bool _isOcrRunning = false;

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

      startRealtimeOcr();
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  void startRealtimeOcr() {
    _ocrTimer?.cancel();
    _ocrTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _runOcrOnFrame();
    });
  }

  void stopRealtimeOcr() {
    _ocrTimer?.cancel();
    _ocrTimer = null;
  }

  Future<void> _runOcrOnFrame() async {
    if (_isOcrRunning || _isCapturing) return;
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;

    _isOcrRunning = true;
    String? tempPath;
    try {
      final xfile = await _cameraCtrl!.takePicture();
      tempPath = xfile.path;
      final inputImage = InputImage.fromFilePath(tempPath);
      final result = await _textRecognizer.processImage(inputImage);

      _confidence = _computeConfidence(result);
      _textBlockCount = result.blocks.length;
      _hasTextInFrame = _textBlockCount > 0;
      notifyListeners();
    } catch (_) {
      // Ignore errors in real-time processing
    } finally {
      if (tempPath != null) {
        try { File(tempPath).deleteSync(); } catch (_) {}
      }
      try {
        if (_cameraCtrl != null && _cameraCtrl!.value.isInitialized) {
          await _cameraCtrl!.setFocusMode(FocusMode.auto);
        }
      } catch (_) {}
      _isOcrRunning = false;
    }
  }

  double _computeConfidence(RecognizedText text) {
    if (text.blocks.isEmpty) return 0.0;
    double total = 0;
    int count = 0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        for (final el in line.elements) {
          final c = el.confidence;
          if (c != null) {
            total += c;
            count++;
          }
        }
      }
    }
    if (count > 0) return (total / count).clamp(0.0, 1.0);
    final charCount = text.text.length;
    return (charCount / 200.0).clamp(0.0, 1.0);
  }

  Future<File?> captureImage() async {
    if (!_isCameraReady || _isCapturing || _cameraCtrl == null) return null;

    _isCapturing = true;
    notifyListeners();
    stopRealtimeOcr();

    try {
      final image = await _cameraCtrl!.takePicture();
      return File(image.path);
    } catch (e) {
      debugPrint('❌ Capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
      notifyListeners();
      startRealtimeOcr();
    }
  }

  @override
  void dispose() {
    stopRealtimeOcr();
    _textRecognizer.close();
    _cameraCtrl?.dispose();
    super.dispose();
  }
}
