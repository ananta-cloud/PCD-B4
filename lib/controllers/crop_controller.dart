import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../services/image_processing_service.dart';
import '../services/yolo_service.dart';
import '../services/ocr_service.dart';
import '../models/receipt.dart';

enum DraggedCorner { topLeft, topRight, bottomLeft, bottomRight, move }

class CropController extends ChangeNotifier {
  img.Image? _originalImage;
  img.Image? get originalImage => _originalImage;

  Offset _cropTopLeft = Offset.zero;
  Offset get cropTopLeft => _cropTopLeft;

  Size _cropSize = Size.zero;
  Size get cropSize => _cropSize;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _processingStep = '';
  String get processingStep => _processingStep;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DraggedCorner? _draggedCorner;
  Offset? _dragStart;

  Future<void> init(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw "Gagal decode image";

      _originalImage = image;
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      final cropW = w * 0.85;
      final cropH = h * 0.70;
      _cropTopLeft = Offset((w - cropW) / 2, (h - cropH) / 2);
      _cropSize = Size(cropW, cropH);
      
      // Init YOLO in background
      YoloService.init();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = "Gagal load image: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  ({double scale, double offsetX, double offsetY}) getImageTransform(Size containerSize) {
    if (_originalImage == null) return (scale: 1.0, offsetX: 0.0, offsetY: 0.0);
    final image = _originalImage!;
    final scaleX = containerSize.width / image.width;
    final scaleY = containerSize.height / image.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final scaledW = image.width * scale;
    final scaledH = image.height * scale;
    final offsetX = (containerSize.width - scaledW) / 2;
    final offsetY = (containerSize.height - scaledH) / 2;
    return (scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  Offset _screenToImage(Offset screenPos, Size containerSize) {
    final t = getImageTransform(containerSize);
    return Offset(
      (screenPos.dx - t.offsetX) / t.scale,
      (screenPos.dy - t.offsetY) / t.scale,
    );
  }

  void onPanStart(DragStartDetails details, Size containerSize) {
    final imgPos = _screenToImage(details.globalPosition, containerSize);
    final t = getImageTransform(containerSize);
    final hitRadius = 40.0 / t.scale;

    final rect = Rect.fromLTWH(
      _cropTopLeft.dx, _cropTopLeft.dy, _cropSize.width, _cropSize.height,
    );

    if ((imgPos - rect.topLeft).distance < hitRadius) {
      _draggedCorner = DraggedCorner.topLeft;
    } else if ((imgPos - rect.topRight).distance < hitRadius) {
      _draggedCorner = DraggedCorner.topRight;
    } else if ((imgPos - rect.bottomLeft).distance < hitRadius) {
      _draggedCorner = DraggedCorner.bottomLeft;
    } else if ((imgPos - rect.bottomRight).distance < hitRadius) {
      _draggedCorner = DraggedCorner.bottomRight;
    } else if (rect.contains(imgPos)) {
      _draggedCorner = DraggedCorner.move;
    }

    _dragStart = imgPos;
  }

  void onPanUpdate(DragUpdateDetails details, Size containerSize) {
    if (_draggedCorner == null || _dragStart == null || _originalImage == null) return;

    final imgPos = _screenToImage(details.globalPosition, containerSize);
    final delta = imgPos - _dragStart!;
    final imgW = _originalImage!.width.toDouble();
    final imgH = _originalImage!.height.toDouble();

    final rect = Rect.fromLTWH(
      _cropTopLeft.dx, _cropTopLeft.dy, _cropSize.width, _cropSize.height,
    );
    const minSize = 80.0;

    Rect newRect;
    switch (_draggedCorner!) {
      case DraggedCorner.topLeft:
        newRect = Rect.fromLTRB(
          (rect.left + delta.dx).clamp(0.0, rect.right - minSize),
          (rect.top + delta.dy).clamp(0.0, rect.bottom - minSize),
          rect.right,
          rect.bottom,
        );
      case DraggedCorner.topRight:
        newRect = Rect.fromLTRB(
          rect.left,
          (rect.top + delta.dy).clamp(0.0, rect.bottom - minSize),
          (rect.right + delta.dx).clamp(rect.left + minSize, imgW),
          rect.bottom,
        );
      case DraggedCorner.bottomLeft:
        newRect = Rect.fromLTRB(
          (rect.left + delta.dx).clamp(0.0, rect.right - minSize),
          rect.top,
          rect.right,
          (rect.bottom + delta.dy).clamp(rect.top + minSize, imgH),
        );
      case DraggedCorner.bottomRight:
        newRect = Rect.fromLTRB(
          rect.left,
          rect.top,
          (rect.right + delta.dx).clamp(rect.left + minSize, imgW),
          (rect.bottom + delta.dy).clamp(rect.top + minSize, imgH),
        );
      case DraggedCorner.move:
        final newLeft = (rect.left + delta.dx).clamp(0.0, imgW - rect.width);
        final newTop = (rect.top + delta.dy).clamp(0.0, imgH - rect.height);
        newRect = Rect.fromLTWH(newLeft, newTop, rect.width, rect.height);
    }

    _cropTopLeft = newRect.topLeft;
    _cropSize = newRect.size;
    _dragStart = imgPos;
    notifyListeners();
  }

  void onPanEnd(DragEndDetails _) {
    _draggedCorner = null;
    _dragStart = null;
  }

  Future<({File croppedFile, ParsedReceipt parsedReceipt})?> processCrop() async {
    if (_originalImage == null) return null;

    _isProcessing = true;
    _processingStep = 'Memproses crop...';
    notifyListeners();

    try {
      final croppedImg = img.copyCrop(
        _originalImage!,
        x: _cropTopLeft.dx.round().clamp(0, _originalImage!.width - 1),
        y: _cropTopLeft.dy.round().clamp(0, _originalImage!.height - 1),
        width: _cropSize.width.round().clamp(1, _originalImage!.width),
        height: _cropSize.height.round().clamp(1, _originalImage!.height),
      );

      final tempPath =
          '${Directory.systemTemp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(tempPath)
        ..writeAsBytesSync(img.encodeJpg(croppedImg, quality: 92));

      _processingStep = 'Konversi grayscale...';
      notifyListeners();
      final grayFile = await ImageProcessingService.convertToGrayscale(croppedFile);

      _processingStep = 'Binary thresholding...';
      notifyListeners();
      final threshFile = await ImageProcessingService.applyThreshold(grayFile);

      _processingStep = 'Mendeteksi area dengan AI YOLOv8...';
      notifyListeners();
      
      // YOLO bekerja jauh lebih baik dengan gambar asli (RGB) dibandingkan gambar hitam putih (threshold)
      // Karena gambar threshold membuang banyak detail tekstur/warna yang dibutuhkan model AI.
      final detections = await YoloService.detect(croppedFile);
      
      List<Rect> itemBoxes = [];
      Rect? totalBox;
      
      for (var d in detections) {
        if (d.label == 'item_belanja') {
          itemBoxes.add(d.boundingBox);
        } else if (d.label == 'total') {
          totalBox = d.boundingBox; // Assume the one with highest confidence or last detected
        }
      }

      _processingStep = 'Menjalankan OCR...';
      notifyListeners();

      final parsedReceipt = await OcrService.processImage(
        threshFile,
        itemBoxes: itemBoxes,
        totalBox: totalBox,
      );
      
      _isProcessing = false;
      notifyListeners();
      return (croppedFile: croppedFile, parsedReceipt: parsedReceipt);
    } catch (e) {
      _errorMessage = "Error process crop: $e";
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
