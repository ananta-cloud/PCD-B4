import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../controllers/scan_controller.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  final _picker = ImagePicker();

  // ── Controller (state + logika bisnis) ──────────────────────────────────
  late final ScanController _ctrl;

  // ── Animasi (tetap di View karena butuh TickerProvider) ─────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _resultCtrl;
  late final Animation<double> _resultAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = ScanController();
    _ctrl.addListener(_onControllerChanged);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  /// Rebuild UI saat controller state berubah
  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ── View Actions (UI side-effects only) ─────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;
    try {
      await _ctrl.processImage(File(picked.path));
      if (!mounted) return;
      _resultCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      _showError('Gagal memproses gambar: $e');
    }
  }

  void _onSave() async {
    final success = await _ctrl.saveReceipt();
    if (!mounted) return;
    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: AppColors.secondary),
          const SizedBox(width: 8),
          Text('Struk tersimpan!', style: GoogleFonts.inter(color: AppColors.onSurface)),
        ]),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _resultCtrl.reset();
      _ctrl.resetScan();
    }
  }

  void _onReset() {
    _resultCtrl.reset();
    _ctrl.resetScan();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: AppColors.onErrorContainer)),
      backgroundColor: AppColors.errorContainer,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            color: _ctrl.isDetected ? const Color(0xFF001A0A) : const Color(0xFF080A12),
            child: CustomPaint(painter: _GridPainter(isDetected: _ctrl.isDetected)),
          ),
          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                stops: const [0, 0.2, 0.65, 1],
              ),
            ),
          ),
          // Top bar
          SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildTopBar(),
            const SizedBox(height: 12),
            Center(child: _buildStatusBadge()),
          ])),
          // Center image area
          Positioned(
            left: 36, top: 160, right: 36, bottom: 260,
            child: _buildImageArea(),
          ),
          // Image view tabs (result only)
          if (_ctrl.phase == ScanPhase.result)
            Positioned(
              left: 36, right: 36, bottom: 230,
              child: _buildImageTabs(),
            ),
          // Bottom panel
          Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _IconBtn(icon: Icons.settings_outlined, onTap: () {}),
        const Spacer(),
        Text('ReceiptSync', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        const Spacer(),
        _IconBtn(icon: Icons.manage_accounts_outlined, onTap: () {}),
      ]),
    );
  }

  // ── Status Badge ────────────────────────────────────────────────────────
  Widget _buildStatusBadge() {
    final String label;
    final Color color;
    final IconData icon;

    switch (_ctrl.phase) {
      case ScanPhase.idle:
        label = 'SIAP MEMINDAI';
        color = AppColors.primary;
        icon = Icons.camera_alt_outlined;
      case ScanPhase.processing:
        label = 'MEMPROSES...';
        color = AppColors.syncStatusPending;
        icon = Icons.hourglass_top_rounded;
      case ScanPhase.result:
        final conf = (_ctrl.ocrResult?.confidence ?? 0) * 100;
        label = '${conf.toStringAsFixed(0)}% CONFIDENCE — ${_ctrl.isDetected ? "VALID" : "LOW"}';
        color = _ctrl.isDetected ? AppColors.successGlint : AppColors.error;
        icon = _ctrl.isDetected ? Icons.check_circle_outline : Icons.warning_amber_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.labelCaps(color: color)),
      ]),
    );
  }

  // ── Image Area ──────────────────────────────────────────────────────────
  Widget _buildImageArea() {
    switch (_ctrl.phase) {
      case ScanPhase.idle:
        return _buildIdleGuide();
      case ScanPhase.processing:
        return _buildProcessingView();
      case ScanPhase.result:
        return _buildResultImage();
    }
  }

  Widget _buildIdleGuide() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => CustomPaint(
        painter: _BoundingBoxPainter(
          color: AppColors.boundingBoxDefault,
          glowIntensity: _pulseAnim.value,
          isDetected: false,
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Arahkan kamera ke struk\natau pilih dari galeri', textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant.withValues(alpha: 0.6))),
          ]),
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return Stack(children: [
      if (_ctrl.originalFile != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(_ctrl.originalFile!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
      Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
            const SizedBox(height: 16),
            Text(_ctrl.processingStep, style: AppTextStyles.label(color: AppColors.primary)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildResultImage() {
    final file = _ctrl.displayedImage;
    if (file == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _resultAnim,
      builder: (context, child) => Transform.scale(
        scale: 0.95 + 0.05 * _resultAnim.value,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _ctrl.isDetected ? AppColors.successGlint : AppColors.error,
              width: 2,
            ),
            boxShadow: _ctrl.isDetected ? [
              BoxShadow(color: AppColors.successGlint.withValues(alpha: 0.3), blurRadius: 16),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          ),
        ),
      ),
    );
  }

  // ── Image Tabs ──────────────────────────────────────────────────────────
  Widget _buildImageTabs() {
    return Row(children: [
      _tabButton('Original', ImageViewType.original),
      const SizedBox(width: 6),
      _tabButton('Grayscale', ImageViewType.grayscale),
      const SizedBox(width: 6),
      _tabButton('Threshold', ImageViewType.threshold),
    ]);
  }

  Widget _tabButton(String label, ImageViewType view) {
    final active = _ctrl.imageView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => _ctrl.setImageView(view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryContainer.withValues(alpha: 0.3) : AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: AppTextStyles.labelCaps(color: active ? AppColors.primary : AppColors.onSurfaceVariant)),
        ),
      ),
    );
  }

  // ── Bottom Panel ────────────────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _ctrl.isDetected ? AppColors.successGlint.withValues(alpha: 0.3) : AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: _ctrl.phase == ScanPhase.idle ? _buildIdleActions() :
             _ctrl.phase == ScanPhase.processing ? _buildProcessingInfo() :
             _buildResultPanel(),
    );
  }

  Widget _buildIdleActions() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('PILIH SUMBER GAMBAR', style: AppTextStyles.labelCaps()),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _actionButton(Icons.camera_alt_rounded, 'Kamera', () => _pickImage(ImageSource.camera))),
        const SizedBox(width: 12),
        Expanded(child: _actionButton(Icons.photo_library_rounded, 'Galeri', () => _pickImage(ImageSource.gallery))),
      ]),
    ]);
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppColors.onPrimaryContainer, size: 20),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer)),
        ]),
      ),
    );
  }

  Widget _buildProcessingInfo() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: Text(_ctrl.processingStep, style: AppTextStyles.bodyMd(color: AppColors.onSurface))),
    ]);
  }

  Widget _buildResultPanel() {
    final result = _ctrl.ocrResult;
    if (result == null) return const SizedBox();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_ctrl.hasItems) ...[
                Text('ITEM BELANJA', style: AppTextStyles.labelCaps()),
                const SizedBox(height: 8),
                ...result.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.name, style: AppTextStyles.bodyMd(color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(
                        '${item.qty} x ${_ctrl.formatAmount(item.unitPrice)}',
                        style: AppTextStyles.label(color: AppColors.onSurfaceVariant),
                      ),
                      Text(_ctrl.formatAmount(item.totalPrice), style: AppTextStyles.label(color: AppColors.onSurface)),
                    ]),
                  ]),
                )),
                Divider(color: AppColors.outlineVariant.withValues(alpha: 0.5), height: 16),
              ],
              if (result.subtotal > 0)
                _summaryRow('Subtotal', _ctrl.formatAmount(result.subtotal)),
              _summaryRow(
                'TOTAL',
                result.isValid ? _ctrl.formatAmount(result.total) : 'Tidak ditemukan',
                isBold: true,
                color: result.isValid ? AppColors.onSurface : AppColors.error,
              ),
              if (result.hasCashPayment) ...[
                Divider(color: AppColors.outlineVariant.withValues(alpha: 0.5), height: 16),
                _summaryRow('Tunai', _ctrl.formatAmount(result.cash!)),
                if (result.change != null && result.change! > 0)
                  _summaryRow('Kembali', _ctrl.formatAmount(result.change!)),
              ],
              if (result.rawText.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showOcrDetail(result.rawText),
                  child: Row(children: [
                    const Icon(Icons.article_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Lihat teks OCR lengkap', style: AppTextStyles.label(color: AppColors.primary)),
                  ]),
                ),
              ],
              if (!_ctrl.hasItems && !result.isValid) ...[
                const SizedBox(height: 8),
                Text('Tidak ada item terdeteksi.\nCoba foto ulang dengan pencahayaan lebih baik.',
                  style: AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _ctrl.isSaving ? null : _onSave,
              icon: _ctrl.isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSecondaryContainer))
                  : const Icon(Icons.save_alt_rounded, size: 18),
              label: Text(_ctrl.isSaving ? 'Menyimpan...' : 'Simpan', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryContainer,
                foregroundColor: AppColors.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _onReset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Scan Lagi', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: isBold
          ? AppTextStyles.bodyLg(color: color ?? AppColors.onSurface).copyWith(fontWeight: FontWeight.w700)
          : AppTextStyles.bodyMd(color: AppColors.onSurfaceVariant)),
        Text(value, style: isBold
          ? AppTextStyles.bodyLg(color: color ?? AppColors.onSurface).copyWith(fontWeight: FontWeight.w700)
          : AppTextStyles.bodyMd(color: color ?? AppColors.onSurface)),
      ]),
    );
  }

  void _showOcrDetail(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('HASIL OCR', style: AppTextStyles.labelCaps()),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Text(text, style: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.onSurface, height: 1.6)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDetected;
  _GridPainter({required this.isDetected});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = (isDetected ? AppColors.successGlint : AppColors.primary).withValues(alpha: 0.05)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 32) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint); }
    for (double y = 0; y < size.height; y += 32) { canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); }
  }
  @override
  bool shouldRepaint(_GridPainter old) => old.isDetected != isDetected;
}

class _BoundingBoxPainter extends CustomPainter {
  final Color color;
  final double glowIntensity;
  final bool isDetected;
  _BoundingBoxPainter({required this.color, required this.glowIntensity, required this.isDetected});
  @override
  void paint(Canvas canvas, Size size) {
    if (isDetected) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8));
      final glow = Paint()..color = color.withValues(alpha: 0.25 * glowIntensity)..strokeWidth = 8..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(rect, glow);
      final border = Paint()..color = color.withValues(alpha: glowIntensity)..strokeWidth = 2.5..style = PaintingStyle.stroke;
      canvas.drawRRect(rect, border);
    } else {
      const cornerLen = 28.0;
      final p = Paint()..color = color.withValues(alpha: 0.9)..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, cornerLen), const Offset(0, 0), p);
      canvas.drawLine(const Offset(0, 0), Offset(cornerLen, 0), p);
      canvas.drawLine(Offset(size.width - cornerLen, 0), Offset(size.width, 0), p);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLen), p);
      canvas.drawLine(Offset(0, size.height - cornerLen), Offset(0, size.height), p);
      canvas.drawLine(Offset(0, size.height), Offset(cornerLen, size.height), p);
      canvas.drawLine(Offset(size.width - cornerLen, size.height), Offset(size.width, size.height), p);
      canvas.drawLine(Offset(size.width, size.height - cornerLen), Offset(size.width, size.height), p);
    }
  }
  @override
  bool shouldRepaint(_BoundingBoxPainter old) => old.color != color || old.glowIntensity != glowIntensity || old.isDetected != isDetected;
}
