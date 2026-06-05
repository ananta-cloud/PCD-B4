import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';

enum _Phase { scanning, processing, result }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  // Camera
  CameraController? _camCtrl;
  bool _camReady = false;
  bool _analyzing = false;
  bool _autoScan = true;
  int _sensorOrientation = 0;
  int _textBlocks = 0;

  // State
  _Phase _phase = _Phase.scanning;
  String _step = '';
  File? _original;
  ParsedReceipt? _result;
  bool _saving = false;

  // Animations
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initCamera();
  }

  @override
  void dispose() {
    _camCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Camera Init ─────────────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) { _showError('Tidak ada kamera'); return; }
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      _sensorOrientation = back.sensorOrientation;
      _camCtrl = CameraController(back, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
      await _camCtrl!.initialize();
      if (!mounted) return;
      setState(() => _camReady = true);
      _startAutoScan();
    } catch (e) {
      _showError('Gagal inisialisasi kamera: $e');
    }
  }

  // ── Auto-Scan ───────────────────────────────────────────────────────────
  void _startAutoScan() {
    if (_camCtrl == null || !_camCtrl!.value.isInitialized) return;
    _autoScan = true;
    _camCtrl!.startImageStream((frame) {
      if (_analyzing || !_autoScan || _phase != _Phase.scanning) return;
      _analyzing = true;
      _analyzeFrame(frame);
    });
  }

  Future<void> _analyzeFrame(CameraImage frame) async {
    try {
      final blocks = await OcrService.analyzeFrameForText(frame, _sensorOrientation);
      if (!mounted) { _analyzing = false; return; }
      setState(() => _textBlocks = blocks);
      if (blocks >= 3) { await _autoCapture(); return; }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    _analyzing = false;
  }

  Future<void> _autoCapture() async {
    _autoScan = false;
    try { await _camCtrl?.stopImageStream(); } catch (_) {}
    try {
      final photo = await _camCtrl!.takePicture();
      HapticFeedback.mediumImpact();
      _processImage(File(photo.path));
    } catch (e) {
      _showError('Gagal capture: $e');
      _analyzing = false;
      _startAutoScan();
    }
  }

  Future<void> _manualCapture() async {
    if (_phase != _Phase.scanning) return;
    _autoScan = false;
    try { await _camCtrl?.stopImageStream(); } catch (_) {}
    try {
      final photo = await _camCtrl!.takePicture();
      HapticFeedback.mediumImpact();
      _processImage(File(photo.path));
    } catch (e) {
      _showError('Gagal capture: $e');
      _startAutoScan();
    }
  }

  Future<void> _pickGallery() async {
    _autoScan = false;
    try { await _camCtrl?.stopImageStream(); } catch (_) {}
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) { _startAutoScan(); return; }
    _processImage(File(picked.path));
  }

  // ── Pipeline ────────────────────────────────────────────────────────────
  Future<void> _processImage(File file) async {
    setState(() { _phase = _Phase.processing; _original = file; _step = 'Konversi grayscale...'; });
    try {
      await ImageProcessingService.processFullPipeline(file);
      if (!mounted) return;
      setState(() { _step = 'Menjalankan OCR...'; });

      final result = await OcrService.processImage(file);
      if (!mounted) return;
      setState(() { _result = result; _phase = _Phase.result; });
      HapticFeedback.heavyImpact();
    } catch (e) {
      _showError('Gagal memproses: $e');
      _resetToScanning();
    }
  }

  // ── Save / Reset ────────────────────────────────────────────────────────
  Future<void> _saveReceipt() async {
    if (_saving || _result == null) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await ReceiptRepository.addReceipt(Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(), userId: 'user_001',
      totalAmount: _result!.total, confidenceScore: _result!.confidence,
      scannedAt: DateTime.now(), merchantName: 'Scanned Receipt',
    ));
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle, color: AppColors.secondary), const SizedBox(width: 8),
        Text('Struk tersimpan!', style: GoogleFonts.inter(color: AppColors.onSurface))]),
      backgroundColor: AppColors.surfaceContainerHigh, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    setState(() => _saving = false);
    _resetToScanning();
  }

  void _resetToScanning() {
    setState(() { _phase = _Phase.scanning; _original = null; _result = null; _textBlocks = 0; });
    _analyzing = false;
    _startAutoScan();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: AppColors.onErrorContainer)),
      backgroundColor: AppColors.errorContainer, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  bool get _isDetected => _phase == _Phase.result && (_result?.confidence ?? 0) > 0.75;
  bool get _hasItems => _result != null && _result!.items.isNotEmpty;

  String _fmt(double amount) {
    final f = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Background
        Container(color: _isDetected ? const Color(0xFF001A0A) : const Color(0xFF080A12),
          child: CustomPaint(painter: _GridPainter(isDetected: _isDetected))),
        // Gradient
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          stops: const [0, 0.2, 0.65, 1]))),
        // Top bar + badge
        SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildTopBar(), const SizedBox(height: 12), Center(child: _buildBadge()),
        ])),
        // Center area
        Positioned(left: 24, top: 150, right: 24, bottom: 200,
          child: _buildCenterArea()),
        // Bottom panel
        Align(alignment: Alignment.bottomCenter, child: _buildBottom()),
      ]),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      _iconBtn(Icons.settings_outlined, () {}), const Spacer(),
      Text('ReceiptSync', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      const Spacer(), _iconBtn(Icons.manage_accounts_outlined, () {}),
    ]),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(width: 40, height: 40,
      decoration: BoxDecoration(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20)));

  // ── Badge ───────────────────────────────────────────────────────────────
  Widget _buildBadge() {
    final (String label, Color color, IconData icon) = switch (_phase) {
      _Phase.scanning => (_textBlocks > 0 ? 'TEKS TERDETEKSI ($_textBlocks)' : 'SCANNING...', AppColors.primary, Icons.camera_alt_outlined),
      _Phase.processing => ('MEMPROSES...', AppColors.syncStatusPending, Icons.hourglass_top_rounded),
      _Phase.result => ('${((_result?.confidence ?? 0) * 100).toStringAsFixed(0)}% — ${_isDetected ? "VALID" : "LOW"}',
        _isDetected ? AppColors.successGlint : AppColors.error, _isDetected ? Icons.check_circle_outline : Icons.warning_amber_rounded),
    };
    return AnimatedContainer(duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16), const SizedBox(width: 8),
        Text(label, style: AppTextStyles.labelCaps(color: color)),
      ]));
  }

  // ── Center Area ─────────────────────────────────────────────────────────
  Widget _buildCenterArea() {
    switch (_phase) {
      case _Phase.scanning: return _buildCameraPreview();
      case _Phase.processing: return _buildProcessingView();
      case _Phase.result: return _buildResultImage();
    }
  }

  Widget _buildCameraPreview() {
    return AnimatedBuilder(animation: _pulseAnim, builder: (ctx, _) =>
      CustomPaint(painter: _BoundingBoxPainter(color: _textBlocks > 0 ? AppColors.successGlint : AppColors.boundingBoxDefault,
        glowIntensity: _pulseAnim.value, isDetected: _textBlocks >= 3),
        child: ClipRRect(borderRadius: BorderRadius.circular(8),
          child: _camReady && _camCtrl != null
            ? CameraPreview(_camCtrl!)
            : const Center(child: CircularProgressIndicator(color: AppColors.primary)))));
  }

  Widget _buildProcessingView() => Stack(children: [
    if (_original != null) ClipRRect(borderRadius: BorderRadius.circular(8),
      child: Image.file(_original!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
    Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
        const SizedBox(height: 16), Text(_step, style: AppTextStyles.label(color: AppColors.primary)),
      ]))),
  ]);

  Widget _buildResultImage() {
    if (_original == null) return const SizedBox();
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isDetected ? AppColors.successGlint : AppColors.error, width: 2),
        boxShadow: _isDetected ? [BoxShadow(color: AppColors.successGlint.withValues(alpha: 0.3), blurRadius: 16)] : null),
      child: ClipRRect(borderRadius: BorderRadius.circular(6),
        child: Image.file(_original!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)));
  }

  // ── Bottom Panel ────────────────────────────────────────────────────────
  Widget _buildBottom() {
    return AnimatedContainer(duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      decoration: BoxDecoration(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDetected ? AppColors.successGlint.withValues(alpha: 0.3) : AppColors.outlineVariant)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: switch (_phase) {
        _Phase.scanning => _buildScanActions(),
        _Phase.processing => _buildProcessingInfo(),
        _Phase.result => _buildResultPanel(),
      });
  }

  Widget _buildScanActions() => Column(mainAxisSize: MainAxisSize.min, children: [
    Text('AUTO-SCAN AKTIF', style: AppTextStyles.labelCaps()),
    const SizedBox(height: 6),
    Text('Arahkan kamera ke struk — otomatis capture', textAlign: TextAlign.center,
      style: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant)),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: _actionBtn(Icons.camera_alt_rounded, 'Capture', _manualCapture)),
      const SizedBox(width: 12),
      Expanded(child: _actionBtn(Icons.photo_library_rounded, 'Galeri', _pickGallery)),
    ]),
  ]);

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: AppColors.onPrimaryContainer, size: 20), const SizedBox(width: 8),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer)),
      ])));

  Widget _buildProcessingInfo() => Row(children: [
    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
    const SizedBox(width: 12), Expanded(child: Text(_step, style: AppTextStyles.bodyMd(color: AppColors.onSurface))),
  ]);

  Widget _buildResultPanel() {
    final r = _result;
    if (r == null) return const SizedBox();
    return ConstrainedBox(constraints: const BoxConstraints(maxHeight: 320),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_hasItems) ...[
            Text('ITEM BELANJA', style: AppTextStyles.labelCaps()), const SizedBox(height: 8),
            ...r.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: AppTextStyles.bodyMd(color: AppColors.onSurface)), const SizedBox(height: 2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${item.qty} x ${_fmt(item.unitPrice)}', style: AppTextStyles.label(color: AppColors.onSurfaceVariant)),
                  Text(_fmt(item.totalPrice), style: AppTextStyles.label(color: AppColors.onSurface)),
                ]),
              ]))),
            Divider(color: AppColors.outlineVariant.withValues(alpha: 0.5), height: 16),
          ],
          if (r.subtotal > 0) _row('Subtotal', _fmt(r.subtotal)),
          _row('TOTAL', r.isValid ? _fmt(r.total) : 'Tidak ditemukan', bold: true, color: r.isValid ? AppColors.onSurface : AppColors.error),
          if (r.hasCashPayment) ...[
            Divider(color: AppColors.outlineVariant.withValues(alpha: 0.5), height: 16),
            _row('Tunai', _fmt(r.cash!)),
            if (r.change != null && r.change! > 0) _row('Kembali', _fmt(r.change!)),
          ],
          if (r.rawText.isNotEmpty) ...[const SizedBox(height: 10),
            GestureDetector(onTap: () => _showOcr(r.rawText),
              child: Row(children: [const Icon(Icons.article_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6), Text('Lihat teks OCR lengkap', style: AppTextStyles.label(color: AppColors.primary))])),
          ],
        ]))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: _saving ? null : _saveReceipt,
            icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryContainer, foregroundColor: AppColors.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _resetToScanning,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text('Scan Lagi', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14)),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.onSurface, side: const BorderSide(color: AppColors.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
        ]),
      ]));
  }

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: bold ? AppTextStyles.bodyLg(color: color ?? AppColors.onSurface).copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant)),
      Text(v, style: bold ? AppTextStyles.bodyLg(color: color ?? AppColors.onSurface).copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.bodyMd(color: color ?? AppColors.onSurface)),
    ]));

  void _showOcr(String text) => showModalBottomSheet(context: context,
    backgroundColor: AppColors.surfaceContainerHigh, isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.5, maxChildSize: 0.85,
      builder: (_, ctrl) => Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16), Text('HASIL OCR', style: AppTextStyles.labelCaps()), const SizedBox(height: 12),
          Expanded(child: SingleChildScrollView(controller: ctrl,
            child: Text(text, style: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.onSurface, height: 1.6)))),
        ]))));
}

// ── Painters ──────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final bool isDetected;
  _GridPainter({required this.isDetected});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = (isDetected ? AppColors.successGlint : AppColors.primary).withValues(alpha: 0.05)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 32) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_GridPainter old) => old.isDetected != isDetected;
}

class _BoundingBoxPainter extends CustomPainter {
  final Color color; final double glowIntensity; final bool isDetected;
  _BoundingBoxPainter({required this.color, required this.glowIntensity, required this.isDetected});
  @override
  void paint(Canvas canvas, Size size) {
    if (isDetected) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8));
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.25 * glowIntensity)..strokeWidth = 8..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: glowIntensity)..strokeWidth = 2.5..style = PaintingStyle.stroke);
    } else {
      const c = 28.0;
      final p = Paint()..color = color.withValues(alpha: 0.9)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, c), Offset.zero, p); canvas.drawLine(Offset.zero, Offset(c, 0), p);
      canvas.drawLine(Offset(size.width - c, 0), Offset(size.width, 0), p); canvas.drawLine(Offset(size.width, 0), Offset(size.width, c), p);
      canvas.drawLine(Offset(0, size.height - c), Offset(0, size.height), p); canvas.drawLine(Offset(0, size.height), Offset(c, size.height), p);
      canvas.drawLine(Offset(size.width - c, size.height), Offset(size.width, size.height), p); canvas.drawLine(Offset(size.width, size.height - c), Offset(size.width, size.height), p);
    }
  }
  @override
  bool shouldRepaint(_BoundingBoxPainter old) => old.color != color || old.glowIntensity != glowIntensity || old.isDetected != isDetected;
}
