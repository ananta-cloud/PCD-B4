import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/ocr_service.dart';
import 'ocr_preview_screen.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;
  const CropScreen({super.key, required this.imageFile});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  img.Image? _originalImage;
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

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw "Gagal decode image";

      setState(() {
        _originalImage = image;
        final w = image.width.toDouble();
        final h = image.height.toDouble();
        final cropW = w * 0.85;
        final cropH = h * 0.70;
        _cropTopLeft = Offset((w - cropW) / 2, (h - cropH) / 2);
        _cropSize = Size(cropW, cropH);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error load image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal load image: $e")));
        Navigator.pop(context);
      }
    }
  }

  // ── Koordinat helper ────────────────────────────────────────────────────

  /// Hitung scale dan offset gambar di layar (BoxFit.contain logic)
  ({double scale, double offsetX, double offsetY}) _getImageTransform(Size containerSize) {
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
    final t = _getImageTransform(containerSize);
    return Offset(
      (screenPos.dx - t.offsetX) / t.scale,
      (screenPos.dy - t.offsetY) / t.scale,
    );
  }

  // ── Drag handlers ────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails details, Size containerSize) {
    final imgPos = _screenToImage(details.globalPosition, containerSize);
    final t = _getImageTransform(containerSize);
    final hitRadius = 40.0 / t.scale; // 40px layar dikonversi ke image coords

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

  void _onPanUpdate(DragUpdateDetails details, Size containerSize) {
    if (_draggedCorner == null || _dragStart == null) return;

    final imgPos = _screenToImage(details.globalPosition, containerSize);
    final delta = imgPos - _dragStart!;
    final imgW = _originalImage!.width.toDouble();
    final imgH = _originalImage!.height.toDouble();

    setState(() {
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
    });
  }

  void _onPanEnd(DragEndDetails _) {
    _draggedCorner = null;
    _dragStart = null;
  }

  // ── Proses crop + OCR ────────────────────────────────────────────────────

  Future<void> _processCrop() async {
    setState(() {
      _isProcessing = true;
      _processingStep = 'Memproses crop...';
    });

    try {
      // 1. Crop gambar
      final croppedImg = img.copyCrop(
        _originalImage!,
        x: _cropTopLeft.dx.round().clamp(0, _originalImage!.width - 1),
        y: _cropTopLeft.dy.round().clamp(0, _originalImage!.height - 1),
        width: _cropSize.width.round().clamp(1, _originalImage!.width),
        height: _cropSize.height.round().clamp(1, _originalImage!.height),
      );

      // 2. Simpan ke temp file
      final tempPath =
          '${Directory.systemTemp.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(tempPath)
        ..writeAsBytesSync(img.encodeJpg(croppedImg, quality: 92));

      if (!mounted) return;
      setState(() => _processingStep = 'Menjalankan OCR...');

      // 3. OCR
      final parsedReceipt = await OcrService.processImage(croppedFile);

      if (!mounted) return;

      // 4. Ke halaman preview OCR — user konfirmasi sebelum simpan
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrPreviewScreen(
            croppedFile: croppedFile,
            parsedReceipt: parsedReceipt,
          ),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error process crop: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _originalImage == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text('Memuat gambar...', style: GoogleFonts.inter(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              // Gambar asli
              SizedBox.expand(
                child: Image.file(widget.imageFile, fit: BoxFit.contain),
              ),

              // Crop overlay dengan handle sudut
              GestureDetector(
                onPanStart: (d) => _onPanStart(d, containerSize),
                onPanUpdate: (d) => _onPanUpdate(d, containerSize),
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: CropOverlayPainter(
                    imageSize: Size(
                      _originalImage!.width.toDouble(),
                      _originalImage!.height.toDouble(),
                    ),
                    cropTopLeft: _cropTopLeft,
                    cropSize: _cropSize,
                    containerSize: containerSize,
                  ),
                  size: Size.infinite,
                ),
              ),

              // Instruksi atas
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Seret sudut untuk menyesuaikan area crop",
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ),
              ),

              // Tombol bawah
              if (!_isProcessing)
                Positioned(
                  bottom: 40,
                  left: 24,
                  right: 24,
                  child: Row(
                    children: [
                      // Batal
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Proses
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _processCrop,
                          icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                          label: Text(
                            'Proses & OCR',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Processing overlay
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _processingStep,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
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
    final scaleX = containerSize.width / imageSize.width;
    final scaleY = containerSize.height / imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledW = imageSize.width * scale;
    final scaledH = imageSize.height * scale;
    final offX = (containerSize.width - scaledW) / 2;
    final offY = (containerSize.height - scaledH) / 2;

    // Crop rect dalam koordinat layar
    final cropRect = Rect.fromLTWH(
      offX + cropTopLeft.dx * scale,
      offY + cropTopLeft.dy * scale,
      cropSize.width * scale,
      cropSize.height * scale,
    );

    // Dark overlay di luar crop
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlayPath, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Border crop
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 0.8;
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }

    // Handle sudut — lingkaran putih besar agar mudah di-tap
    const handleR = 12.0;
    final handleFill = Paint()..color = Colors.white;
    final handleBorder = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final corner in [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
    ]) {
      canvas.drawCircle(corner, handleR, handleFill);
      canvas.drawCircle(corner, handleR, handleBorder);
    }

    // Corner lines (L-shape accent)
    const cLen = 22.0;
    const cW = 3.5;
    final cp = Paint()
      ..color = AppColors.primary
      ..strokeWidth = cW
      ..style = PaintingStyle.stroke;

    canvas.drawLine(cropRect.topLeft.translate(handleR, 0), cropRect.topLeft.translate(handleR + cLen, 0), cp);
    canvas.drawLine(cropRect.topLeft.translate(0, handleR), cropRect.topLeft.translate(0, handleR + cLen), cp);

    canvas.drawLine(cropRect.topRight.translate(-handleR, 0), cropRect.topRight.translate(-handleR - cLen, 0), cp);
    canvas.drawLine(cropRect.topRight.translate(0, handleR), cropRect.topRight.translate(0, handleR + cLen), cp);

    canvas.drawLine(cropRect.bottomLeft.translate(handleR, 0), cropRect.bottomLeft.translate(handleR + cLen, 0), cp);
    canvas.drawLine(cropRect.bottomLeft.translate(0, -handleR), cropRect.bottomLeft.translate(0, -handleR - cLen), cp);

    canvas.drawLine(cropRect.bottomRight.translate(-handleR, 0), cropRect.bottomRight.translate(-handleR - cLen, 0), cp);
    canvas.drawLine(cropRect.bottomRight.translate(0, -handleR), cropRect.bottomRight.translate(0, -handleR - cLen), cp);
  }

  @override
  bool shouldRepaint(CropOverlayPainter old) =>
      old.cropTopLeft != cropTopLeft || old.cropSize != cropSize;
}
