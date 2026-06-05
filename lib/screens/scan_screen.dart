import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import 'crop_screen.dart';

enum _ScanPhase { idle, processing, result }
enum _ImageView { original, processed }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Camera ─────────────────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  final _picker = ImagePicker();

  // ── Real-time OCR ──────────────────────────────────────────────────────
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  Timer? _ocrTimer;
  bool _isOcrRunning = false;
  double _confidence = 0.0;       // 0.0 – 1.0
  int _textBlockCount = 0;        // jumlah blok teks terdeteksi
  bool _hasTextInFrame = false;   // apakah ada teks di frame

  // ── Processing state ───────────────────────────────────────────────────
  _ScanPhase _phase = _ScanPhase.idle;
  _ImageView _imageView = _ImageView.original;
  String _processingStep = '';
  File? _originalFile;
  File? _grayscaleFile;
  File? _thresholdFile;
  ParsedReceipt? _ocrResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ocrTimer?.cancel();
    _textRecognizer.close();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopRealtimeOcr();
      _cameraCtrl?.dispose();
      if (mounted) setState(() => _isCameraReady = false);
    } else if (state == AppLifecycleState.resumed && !_isCameraReady) {
      _initCamera();
    }
  }

  // ── Pick image ──────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    _processImage(File(picked.path));
  }

  // ── Processing pipeline ─────────────────────────────────────────────────
  Future<void> _processImage(File file) async {
    setState(() {
      _phase = _ScanPhase.processing;
      _originalFile = file;
      _processingStep = 'Konversi grayscale...';
    });

    try {
      // Step 1: Grayscale
      final grayFile = await ImageProcessingService.convertToGrayscale(file);
      if (!mounted) return;
      setState(() {
        _grayscaleFile = grayFile;
        _processingStep = 'Binary thresholding...';
      });

      // Step 2: Threshold
      final threshFile = await ImageProcessingService.applyThreshold(grayFile);
      if (!mounted) return;
      setState(() {
        _thresholdFile = threshFile;
        _processingStep = 'Menjalankan OCR...';
      });

      final imageForOcr = file;

      debugPrint('OCR input file path: ${imageForOcr.path}');
      final result = await OcrService.processImage(imageForOcr);
      if (!mounted) return;

      setState(() {
        _ocrResult = result;
        _phase = _ScanPhase.result;
        _imageView = _ImageView.original;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal memproses gambar: $e');
      setState(() => _phase = _ScanPhase.idle);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Camera init ────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras[0],
      );

      final ctrl = CameraController(
        camera,
        ResolutionPreset.medium, // medium cukup untuk OCR, hemat baterai
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await ctrl.initialize();
      // Pastikan flash mati — tidak auto-nyala meski gelap
      await ctrl.setFlashMode(FlashMode.off);
      // Aktifkan continuous auto-focus agar selalu tajam
      await ctrl.setFocusMode(FocusMode.auto);
      if (!mounted) return;

      _cameraCtrl = ctrl;
      setState(() => _isCameraReady = true);

      // Mulai real-time OCR setelah kamera siap
      _startRealtimeOcr();
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  // ── Real-time OCR (tiap 1.5 detik) ────────────────────────────────────

  void _startRealtimeOcr() {
    _ocrTimer?.cancel();
    // Interval 2.5 detik — cukup untuk OCR + kamera re-focus sebelum frame berikutnya
    _ocrTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _runOcrOnFrame();
    });
  }

  void _stopRealtimeOcr() {
    _ocrTimer?.cancel();
    _ocrTimer = null;
  }

  Future<void> _runOcrOnFrame() async {
    if (_isOcrRunning || _isCapturing) return;
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;

    _isOcrRunning = true;
    String? tempPath;
    try {
      // Gunakan takePicture tapi dengan resolusi medium agar tidak ganggu AF
      final xfile = await _cameraCtrl!.takePicture();
      tempPath = xfile.path;
      final inputImage = InputImage.fromFilePath(tempPath);
      final result = await _textRecognizer.processImage(inputImage);

      final confidence = _computeConfidence(result);
      final blockCount = result.blocks.length;

      if (mounted) {
        setState(() {
          _confidence = confidence;
          _textBlockCount = blockCount;
          _hasTextInFrame = blockCount > 0;
        });
      }
    } catch (_) {
      // Skip frame ini
    } finally {
      // Hapus temp file
      if (tempPath != null) {
        try { File(tempPath).deleteSync(); } catch (_) {}
      }
      // Trigger re-focus setelah OCR selesai
      try {
        if (_cameraCtrl != null && _cameraCtrl!.value.isInitialized) {
          await _cameraCtrl!.setFocusMode(FocusMode.auto);
        }
      } catch (_) {}
      _isOcrRunning = false;
    }
  }

  /// Hitung confidence 0.0–1.0 dari RecognizedText
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

    // Fallback: estimasi dari jumlah karakter terbaca
    final charCount = text.text.length;
    return (charCount / 200.0).clamp(0.0, 1.0);
  }

  // ── Capture ────────────────────────────────────────────────────────────

  Future<void> _captureImage() async {
    if (!_isCameraReady || _isCapturing || _cameraCtrl == null) return;

    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();
    _stopRealtimeOcr(); // pause OCR saat capturing

    try {
      final image = await _cameraCtrl!.takePicture();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CropScreen(imageFile: File(image.path)),
        ),
      );
    } catch (e) {
      debugPrint('❌ Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        _startRealtimeOcr(); // resume OCR
      }
    }
  }

  Future<void> _pickFromGallery() async {
    _stopRealtimeOcr();
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (!mounted) {
      _startRealtimeOcr();
      return;
    }
    if (picked == null) {
      _startRealtimeOcr();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CropScreen(imageFile: File(picked.path))),
    );
    if (mounted) _startRealtimeOcr();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraReady && _cameraCtrl != null
          ? _buildLiveView()
          : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memulai kamera...',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveView() {
    // Gunakan SafeArea untuk seluruh konten UI, tapi biarkan kamera full bleed
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 1. Camera preview — full bleed, tidak distorsi ──
        _buildPreview(),

        // ── 2. Vignette gradient ──
        _buildVignette(),

        // ── 3. Guide overlay ──
        LayoutBuilder(
          builder: (_, constraints) => CustomPaint(
            painter: _ScanGuidePainter(
              screenSize: Size(constraints.maxWidth, constraints.maxHeight),
              confidence: _confidence,
              hasText: _hasTextInFrame,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        ),

        // ── 4. Top bar — mulai dari bawah status bar ──
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          child: _buildTopBar(),
        ),

        // ── 5. Confidence badge ──
        _buildConfidenceBadge(),

        // ── 6. Bottom controls ──
        _buildBottomControls(),
      ],
    );
  }

  // ── Camera preview — full bleed, cover, tidak gepeng ─────────────────

  Widget _buildPreview() {
    final ctrl = _cameraCtrl!;
    final previewSize = ctrl.value.previewSize!;
    // Sensor Android landscape: previewSize.width > previewSize.height
    // Untuk portrait: aspect ratio portrait = previewSize.width / previewSize.height

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // Ukuran "asli" sesuai sensor — FittedBox.cover akan scale agar memenuhi layar
          width: previewSize.height,   // lebar portrait = tinggi sensor
          height: previewSize.width,  // tinggi portrait = lebar sensor
          child: CameraPreview(ctrl),
        ),
      ),
    );
  }

  // ── Vignette gradient ──────────────────────────────────────────────────

  Widget _buildVignette() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.65),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.70),
            ],
            stops: const [0.0, 0.22, 0.65, 1.0],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Label
          Text(
            'ReceiptSync',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          // Info blok teks
          if (_hasTextInFrame)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.text_fields_rounded, color: Colors.white60, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '$_textBlockCount blok teks',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Confidence badge ───────────────────────────────────────────────────

  Widget _buildConfidenceBadge() {
    // Hitung posisi Y: sedikit di atas tengah (sama dengan guide frame)
    return Positioned(
      bottom: 130,
      left: 0,
      right: 0,
      child: Center(
        child: _ConfidencePill(
          confidence: _confidence,
          hasText: _hasTextInFrame,
        ),
      ),
    );
  }

  // ── Bottom controls ────────────────────────────────────────────────────

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 28,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Galeri
            _CircleIconButton(
              onTap: _pickFromGallery,
              size: 54,
              tooltip: 'Galeri',
              child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
            ),

            // Capture
            _CaptureButton(isCapturing: _isCapturing, onTap: _captureImage),

            // Placeholder simetri
            const SizedBox(width: 54, height: 54),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Guide Overlay Painter
// ════════════════════════════════════════════════════════════════════════════

class _ScanGuidePainter extends CustomPainter {
  final Size screenSize;
  final double confidence;
  final bool hasText;

  _ScanGuidePainter({
    required this.screenSize,
    required this.confidence,
    required this.hasText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Frame: 86% lebar layar, tinggi proporsional struk (1:1.5)
    final frameW = w * 0.86;
    final frameH = frameW * 1.48;
    final left = (w - frameW) / 2;
    // Posisi tengah sedikit ke atas (48% height)
    final top = h * 0.44 - frameH / 2;
    final right = left + frameW;
    final bottom = top + frameH;
    const radius = Radius.circular(16);
    final rrect = RRect.fromLTRBR(left, top, right, bottom, radius);

    // ── Dark overlay ──
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = Colors.black.withOpacity(0.52));

    // ── Border warna sesuai status ──
    final borderColor = _frameColor();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── Corner L-shape handles ──
    const cLen = 28.0;
    const cW = 4.0;
    const r = 16.0;
    final cp = Paint()
      ..color = borderColor
      ..strokeWidth = cW
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(left + r, top), Offset(left + r + cLen, top), cp);
    canvas.drawLine(Offset(left, top + r), Offset(left, top + r + cLen), cp);
    // Top-right
    canvas.drawLine(Offset(right - r, top), Offset(right - r - cLen, top), cp);
    canvas.drawLine(Offset(right, top + r), Offset(right, top + r + cLen), cp);
    // Bottom-left
    canvas.drawLine(Offset(left + r, bottom), Offset(left + r + cLen, bottom), cp);
    canvas.drawLine(Offset(left, bottom - r), Offset(left, bottom - r - cLen), cp);
    // Bottom-right
    canvas.drawLine(Offset(right - r, bottom), Offset(right - r - cLen, bottom), cp);
    canvas.drawLine(Offset(right, bottom - r), Offset(right, bottom - r - cLen), cp);
  }

  Color _frameColor() {
    if (!hasText) return Colors.white;
    if (confidence >= 0.75) return const Color(0xFF4CAF50); // hijau
    if (confidence >= 0.45) return const Color(0xFFFFB300); // kuning
    return Colors.white;
  }

  @override
  bool shouldRepaint(_ScanGuidePainter old) =>
      old.confidence != confidence || old.hasText != hasText;
}

// ════════════════════════════════════════════════════════════════════════════
//  Confidence Pill Widget
// ════════════════════════════════════════════════════════════════════════════

class _ConfidencePill extends StatelessWidget {
  final double confidence;
  final bool hasText;

  const _ConfidencePill({required this.confidence, required this.hasText});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();

    // Label & warna berdasarkan kondisi
    final String label;
    final Color color;
    final IconData icon;

    if (!hasText) {
      label = 'Arahkan ke struk';
      color = Colors.white60;
      icon = Icons.crop_free_rounded;
    } else if (pct >= 75) {
      label = 'Siap scan · $pct%';
      color = const Color(0xFF4CAF50);
      icon = Icons.check_circle_outline_rounded;
    } else if (pct >= 45) {
      label = 'Mendeteksi · $pct%';
      color = const Color(0xFFFFB300);
      icon = Icons.radio_button_checked_rounded;
    } else {
      label = 'Kualitas rendah · $pct%';
      color = Colors.redAccent;
      icon = Icons.warning_amber_rounded;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.5), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Progress bar (hanya tampil kalau ada teks)
        if (hasText) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: confidence.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Capture Button
// ════════════════════════════════════════════════════════════════════════════

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;
  const _CaptureButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: AnimatedScale(
        scale: isCapturing ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
            // Inner circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isCapturing ? 50 : 62,
              height: isCapturing ? 50 : 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCapturing
                    ? Colors.white.withOpacity(0.45)
                    : Colors.white,
              ),
              child: isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black45,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Circle Icon Button
// ════════════════════════════════════════════════════════════════════════════

class _CircleIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Widget child;
  final String? tooltip;

  const _CircleIconButton({
    required this.onTap,
    required this.size,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
