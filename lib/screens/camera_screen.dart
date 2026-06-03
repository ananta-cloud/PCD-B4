import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'crop_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _cameraCtrl;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Gunakan back camera (index 0)
      final camera = widget.cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => widget.cameras[0],
      );

      _cameraCtrl = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraCtrl.initialize();

      if (!mounted) return;
      setState(() => _isCameraReady = true);
    } catch (e) {
      print("❌ Error inisialisasi camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal membuka kamera: $e")));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final image = await _cameraCtrl.takePicture();
      final file = File(image.path);

      if (!mounted) return;

      // Go to crop screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (ctx) => CropScreen(imageFile: file)),
      );
    } catch (e) {
      print("❌ Error capture: $e");
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengambil foto: $e")));
      }
    }
  }

  @override
  void dispose() {
    _cameraCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text("Membuka Kamera...", style: GoogleFonts.spaceMono()),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Scan Receipt",
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
          // Camera preview
          CameraPreview(_cameraCtrl),

          // Guide rectangle overlay
          Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
            child: Stack(
              children: [
                // Dark overlay outside the guide
                CustomPaint(painter: GuidePainter(), size: Size.infinite),

                // Guide text
                Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: Text(
                    "Posisikan struk di dalam frame",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tap untuk foto",
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Guide painter untuk rectangle dengan dark overlay di luar
class GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Definisikan guide rectangle (center, 80% width, 60% height)
    final guideWidth = size.width * 0.85;
    final guideHeight = size.height * 0.65;
    final guideLeft = (size.width - guideWidth) / 2;
    final guideTop = (size.height - guideHeight) / 2;

    final guideRect = Rect.fromLTWH(
      guideLeft,
      guideTop,
      guideWidth,
      guideHeight,
    );

    // Dark overlay
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(guideRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.4));

    // Guide rectangle border (bright rectangle)
    canvas.drawRect(
      guideRect,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    // Corner markers
    const cornerLen = 25.0;
    const cornerWidth = 4.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(
      guideRect.topLeft,
      guideRect.topLeft.translate(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.topLeft,
      guideRect.topLeft.translate(0, cornerLen),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      guideRect.topRight,
      guideRect.topRight.translate(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.topRight,
      guideRect.topRight.translate(0, cornerLen),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      guideRect.bottomLeft,
      guideRect.bottomLeft.translate(cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.bottomLeft,
      guideRect.bottomLeft.translate(0, -cornerLen),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      guideRect.bottomRight,
      guideRect.bottomRight.translate(-cornerLen, 0),
      cornerPaint,
    );
    canvas.drawLine(
      guideRect.bottomRight,
      guideRect.bottomRight.translate(0, -cornerLen),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(GuidePainter oldDelegate) => false;
}
