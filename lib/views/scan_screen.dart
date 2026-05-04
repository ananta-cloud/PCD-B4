import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../services/mock_receipt_service.dart';

enum _ScanState { scanning, detected }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  late final AnimationController _scanLineCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _successCtrl;
  late final Animation<double> _scanLineAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _successAnim;

  _ScanState _state = _ScanState.scanning;
  double _confidence = 0.0;
  double _extractedAmount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _successCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scanLineAnim = Tween<double>(begin: 0.05, end: 0.95).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _successAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    _simulateScan();
  }

  void _simulateScan() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final rng = Random();
    final conf = 0.75 + rng.nextDouble() * 0.20;
    final amount = (50000 + rng.nextInt(200) * 1000).toDouble();
    setState(() { _confidence = conf; _extractedAmount = amount; _state = _ScanState.detected; });
    _successCtrl.forward();
    HapticFeedback.mediumImpact();
  }

  void _saveReceipt() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    MockReceiptService.addReceipt(Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'user_001',
      totalAmount: _extractedAmount,
      confidenceScore: _confidence,
      scannedAt: DateTime.now(),
      merchantName: 'Unknown Merchant',
    ));
    HapticFeedback.heavyImpact();
    if (!mounted) return;
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
    setState(() { _state = _ScanState.scanning; _confidence = 0; _extractedAmount = 0; _isSaving = false; });
    _successCtrl.reset();
    _simulateScan();
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _glowCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  bool get _isDetected => _state == _ScanState.detected;
  Color get _boxColor => _isDetected ? AppColors.successGlint : AppColors.boundingBoxDefault;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera bg with grid
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            color: _isDetected ? const Color(0xFF001A0A) : const Color(0xFF080A12),
            child: CustomPaint(painter: _GridPainter(isDetected: _isDetected)),
          ),
          // Dark overlay gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                stops: const [0, 0.2, 0.65, 1],
              ),
            ),
          ),
          // Bounding box + scan line
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            const hPad = 36.0, topPad = 120.0, botPad = 220.0;
            final boxW = w - hPad * 2;
            final boxH = h - topPad - botPad;
            return AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) => Stack(children: [
                Positioned(
                  left: hPad, top: topPad, width: boxW, height: boxH,
                  child: CustomPaint(painter: _BoundingBoxPainter(color: _boxColor, glowIntensity: _glowAnim.value, isDetected: _isDetected)),
                ),
                if (!_isDetected)
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (context, child) => Positioned(
                      left: hPad + 2, top: topPad + boxH * _scanLineAnim.value, width: boxW - 4, height: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            AppColors.primary.withValues(alpha: 0.7),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            );
          }),
          // Top bar + badge
          SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _IconBtn(icon: Icons.settings_outlined, onTap: () {}),
                const Spacer(),
                Text('ReceiptSync', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                const Spacer(),
                _IconBtn(icon: Icons.manage_accounts_outlined, onTap: () {}),
              ]),
            ),
            const SizedBox(height: 16),
            Center(child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _isDetected ? AppColors.successGlint.withValues(alpha: 0.15) : AppColors.surfaceContainerHigh.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _isDetected ? AppColors.successGlint.withValues(alpha: 0.8) : AppColors.outlineVariant, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isDetected ? Icons.check_circle_outline : Icons.radar, color: _isDetected ? AppColors.successGlint : AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  _isDetected ? '${(_confidence * 100).toStringAsFixed(0)}% CONFIDENCE — VALID' : 'SCANNING...',
                  style: AppTextStyles.labelCaps(color: _isDetected ? AppColors.successGlint : AppColors.primary),
                ),
              ]),
            )),
          ])),
          // Bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.only(left: 36, right: 36, bottom: 80),
              decoration: BoxDecoration(
                color: _isDetected ? AppColors.surfaceContainerHigh.withValues(alpha: 0.95) : AppColors.surfaceContainerHigh.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isDetected ? AppColors.successGlint.withValues(alpha: 0.3) : AppColors.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('EXTRACTED TOTAL', style: AppTextStyles.labelCaps()),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _successAnim,
                  builder: (context, child) => Transform.scale(
                    scale: _isDetected ? 0.9 + 0.1 * _successAnim.value : 1,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isDetected ? _formatAmount(_extractedAmount) : '—',
                      style: AppTextStyles.numericDisplay(color: _isDetected ? AppColors.onSurface : AppColors.outline),
                    ),
                  ),
                ),
                if (_isDetected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveReceipt,
                      icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSecondaryContainer)) : const Icon(Icons.save_alt_rounded),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Struk', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final f = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }
}

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
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(8));
    if (isDetected) {
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
