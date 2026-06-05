import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../controllers/crop_controller.dart';
import 'ocr_preview_screen.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;
  const CropScreen({super.key, required this.imageFile});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

// BARIS INI SEBELUMNYA HILANG:
class _CropScreenState extends State<CropScreen> {
  final _cropController = CropController();

  @override
  void initState() {
    super.initState();
    _cropController.init(widget.imageFile);
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _processCrop() async {
    final result = await _cropController.processCrop();
    if (result != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrPreviewScreen(
            croppedFile: result.croppedFile,
            parsedReceipt: result.parsedReceipt,
          ),
        ),
      );
    } else if (mounted && _cropController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cropController.errorMessage!)),
      );
      _cropController.clearError();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cropController,
      builder: (context, _) {
        if (_cropController.isLoading || _cropController.originalImage == null) {
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
                    onPanStart: (d) => _cropController.onPanStart(d, containerSize),
                    onPanUpdate: (d) => _cropController.onPanUpdate(d, containerSize),
                    onPanEnd: _cropController.onPanEnd,
                    child: CustomPaint(
                      painter: CropOverlayPainter(
                        imageSize: Size(
                          _cropController.originalImage!.width.toDouble(),
                          _cropController.originalImage!.height.toDouble(),
                        ),
                        cropTopLeft: _cropController.cropTopLeft,
                        cropSize: _cropController.cropSize,
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
                  if (!_cropController.isProcessing)
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
                  if (_cropController.isProcessing)
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
                              _cropController.processingStep,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                ], // Penutup children dari Stack
              );
            }, // Penutup builder dari LayoutBuilder
          ),
        );
      }, // Penutup builder dari ListenableBuilder
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────

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