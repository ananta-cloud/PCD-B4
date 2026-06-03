import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../services/ocr_service.dart';
import '../repositories/receipt_repository.dart';
import 'detail_screen.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;

  const CropScreen({super.key, required this.imageFile});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late img.Image _originalImage;
  late Offset _cropTopLeft;
  late Size _cropSize;

  bool _isLoading = true;
  bool _isProcessing = false;
  String _processingStep = '';

  DraggedCorner? _draggedCorner;
  Offset? _dragStart;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  void _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw "Gagal decode image";
      }

      setState(() {
        _originalImage = image;
        // Default crop: 80% width, 60% height, centered
        final w = _originalImage.width.toDouble();
        final h = _originalImage.height.toDouble();
        final cropW = w * 0.85;
        final cropH = h * 0.65;

        _cropTopLeft = Offset((w - cropW) / 2, (h - cropH) / 2);
        _cropSize = Size(cropW, cropH);
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error load image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal load image: $e")));
        Navigator.pop(context);
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final pos = renderBox.globalToLocal(details.globalPosition);

    // Calculate image scaling
    final containerSize = MediaQuery.of(context).size;
    final scaleX = containerSize.width / _originalImage.width;
    final scaleY = containerSize.height / _originalImage.height;
    final scale = min(scaleX, scaleY);

    final scaledWidth = _originalImage.width * scale;
    final scaledHeight = _originalImage.height * scale;
    final offsetX = (containerSize.width - scaledWidth) / 2;
    final offsetY = (containerSize.height - scaledHeight) / 2;

    // Convert screen coordinates to image coordinates
    final imageX = (pos.dx - offsetX) / scale;
    final imageY = (pos.dy - offsetY) / scale;

    // Check if we're dragging a corner or moving the whole box
    const cornerSize = 40.0;
    final rect = Rect.fromLTWH(
      _cropTopLeft.dx,
      _cropTopLeft.dy,
      _cropSize.width,
      _cropSize.height,
    );

    // Top-left
    if ((Offset(imageX, imageY) - rect.topLeft).distance < cornerSize / scale) {
      _draggedCorner = DraggedCorner.topLeft;
    }
    // Top-right
    else if ((Offset(imageX, imageY) - rect.topRight).distance <
        cornerSize / scale) {
      _draggedCorner = DraggedCorner.topRight;
    }
    // Bottom-left
    else if ((Offset(imageX, imageY) - rect.bottomLeft).distance <
        cornerSize / scale) {
      _draggedCorner = DraggedCorner.bottomLeft;
    }
    // Bottom-right
    else if ((Offset(imageX, imageY) - rect.bottomRight).distance <
        cornerSize / scale) {
      _draggedCorner = DraggedCorner.bottomRight;
    }
    // Move whole rect
    else if (rect.contains(Offset(imageX, imageY))) {
      _draggedCorner = DraggedCorner.move;
    }

    _dragStart = Offset(imageX, imageY);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedCorner == null || _dragStart == null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final pos = renderBox.globalToLocal(details.globalPosition);

    // Calculate image scaling
    final containerSize = MediaQuery.of(context).size;
    final scaleX = containerSize.width / _originalImage.width;
    final scaleY = containerSize.height / _originalImage.height;
    final scale = min(scaleX, scaleY);

    final scaledWidth = _originalImage.width * scale;
    final scaledHeight = _originalImage.height * scale;
    final offsetX = (containerSize.width - scaledWidth) / 2;
    final offsetY = (containerSize.height - scaledHeight) / 2;

    // Convert screen coordinates to image coordinates
    final imageX = (pos.dx - offsetX) / scale;
    final imageY = (pos.dy - offsetY) / scale;
    final delta = Offset(imageX, imageY) - _dragStart!;

    setState(() {
      final rect = Rect.fromLTWH(
        _cropTopLeft.dx,
        _cropTopLeft.dy,
        _cropSize.width,
        _cropSize.height,
      );

      late Rect newRect;

      switch (_draggedCorner!) {
        case DraggedCorner.topLeft:
          newRect = Rect.fromLTWH(
            (rect.left + delta.dx).clamp(0, rect.right - 50),
            (rect.top + delta.dy).clamp(0, rect.bottom - 50),
            (rect.width - delta.dx).clamp(50, rect.width + rect.left),
            (rect.height - delta.dy).clamp(50, rect.height + rect.top),
          );
        case DraggedCorner.topRight:
          newRect = Rect.fromLTWH(
            rect.left,
            (rect.top + delta.dy).clamp(0, rect.bottom - 50),
            (rect.width + delta.dx).clamp(50, _originalImage.width - rect.left),
            (rect.height - delta.dy).clamp(50, rect.height + rect.top),
          );
        case DraggedCorner.bottomLeft:
          newRect = Rect.fromLTWH(
            (rect.left + delta.dx).clamp(0, rect.right - 50),
            rect.top,
            (rect.width - delta.dx).clamp(50, rect.width + rect.left),
            (rect.height + delta.dy).clamp(
              50,
              _originalImage.height - rect.top,
            ),
          );
        case DraggedCorner.bottomRight:
          newRect = Rect.fromLTWH(
            rect.left,
            rect.top,
            (rect.width + delta.dx).clamp(50, _originalImage.width - rect.left),
            (rect.height + delta.dy).clamp(
              50,
              _originalImage.height - rect.top,
            ),
          );
        case DraggedCorner.move:
          newRect = rect.shift(delta);
          newRect = Rect.fromLTWH(
            newRect.left.clamp(0, _originalImage.width - rect.width),
            newRect.top.clamp(0, _originalImage.height - rect.height),
            newRect.width,
            newRect.height,
          );
      }

      _cropTopLeft = newRect.topLeft;
      _cropSize = newRect.size;
      _dragStart = Offset(imageX, imageY);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _draggedCorner = null;
    _dragStart = null;
  }

  Future<void> _processCrop() async {
    setState(() {
      _isProcessing = true;
      _processingStep = 'Memproses crop...';
    });

    try {
      // Crop image
      final croppedImg = img.copyCrop(
        _originalImage,
        x: _cropTopLeft.dx.toInt(),
        y: _cropTopLeft.dy.toInt(),
        width: _cropSize.width.toInt(),
        height: _cropSize.height.toInt(),
      );

      // Save cropped image
      final tempDir = await _getTempImagePath();
      final croppedFile = File(tempDir);
      croppedFile.writeAsBytesSync(img.encodeJpg(croppedImg));

      if (!mounted) return;

      setState(() {
        _processingStep = 'Ekstraksi teks (OCR)...';
      });

      // Extract text with OCR
      final parsedReceipt = await OcrService.processImage(croppedFile);

      if (!mounted) return;

      setState(() => _processingStep = 'Menyimpan hasil...');

      // Create receipt model
      final receipt = Receipt(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'user_1',
        totalAmount: parsedReceipt.total,
        confidenceScore: parsedReceipt.confidence,
        scannedAt: DateTime.now(),
        isSynced: false,
        merchantName: 'Scanned Receipt',
        imagePath: croppedFile.path,
      );

      // Save to repository
      await ReceiptRepository.addReceipt(receipt);

      if (!mounted) return;

      // Navigate to detail
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => DetailScreen(receipt: receipt)),
      );
    } catch (e) {
      print("❌ Error process crop: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<String> _getTempImagePath() async {
    final dir = await Directory.systemTemp.createTemp('receipt_scanner_');
    return '${dir.path}/cropped_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Loading image...',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Crop & Adjust",
          style: GoogleFonts.spaceMono(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Image display with gesture detection for dragging
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Stack(
              children: [
                // Base image
                Center(
                  child: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),
                // Crop overlay
                CustomPaint(
                  painter: CropOverlayPainter(
                    imageSize: Size(
                      _originalImage.width.toDouble(),
                      _originalImage.height.toDouble(),
                    ),
                    cropTopLeft: _cropTopLeft,
                    cropSize: _cropSize,
                    containerSize: MediaQuery.of(context).size,
                  ),
                  size: Size.infinite,
                ),
              ],
            ),
          ),

          // Guide text
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Text(
              "Drag corners atau area untuk adjust crop",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ),

          // Bottom controls
          if (!_isProcessing)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Batal",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Process button
                  GestureDetector(
                    onTap: _processCrop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        "Proses",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _processingStep,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum DraggedCorner { topLeft, topRight, bottomLeft, bottomRight, move }

class CropOverlayPainter extends CustomPainter {
  final Size imageSize;
  final Offset cropTopLeft;
  final Size cropSize;
  final Size containerSize;

  CropOverlayPainter({
    required this.imageSize,
    required this.cropTopLeft,
    required this.cropSize,
    required this.containerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate how the image is scaled to fit in the container
    final scaleX = containerSize.width / imageSize.width;
    final scaleY = containerSize.height / imageSize.height;
    final scale = min(scaleX, scaleY);

    final scaledWidth = imageSize.width * scale;
    final scaledHeight = imageSize.height * scale;
    final offsetX = (containerSize.width - scaledWidth) / 2;
    final offsetY = (containerSize.height - scaledHeight) / 2;

    // Scale crop rect to container coordinates
    final scaledCropTopLeft = Offset(
      offsetX + cropTopLeft.dx * scale,
      offsetY + cropTopLeft.dy * scale,
    );
    final scaledCropSize = Size(
      cropSize.width * scale,
      cropSize.height * scale,
    );

    final cropRect = Rect.fromLTWH(
      scaledCropTopLeft.dx,
      scaledCropTopLeft.dy,
      scaledCropSize.width,
      scaledCropSize.height,
    );

    // Dark overlay outside crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.5));

    // Crop rect border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Corner handles
    const cornerSize = 25.0;
    final cornerPaint = Paint()..color = Colors.white;

    _drawCornerHandle(canvas, cropRect.topLeft, cornerSize, cornerPaint);
    _drawCornerHandle(canvas, cropRect.topRight, cornerSize, cornerPaint);
    _drawCornerHandle(canvas, cropRect.bottomLeft, cornerSize, cornerPaint);
    _drawCornerHandle(canvas, cropRect.bottomRight, cornerSize, cornerPaint);
  }

  void _drawCornerHandle(Canvas canvas, Offset pos, double size, Paint paint) {
    canvas.drawCircle(pos, size / 2, paint);
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return oldDelegate.cropTopLeft != cropTopLeft ||
        oldDelegate.cropSize != cropSize;
  }
}

double min(double a, double b) => a < b ? a : b;
