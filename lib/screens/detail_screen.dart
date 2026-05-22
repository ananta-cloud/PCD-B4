import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../controllers/detail_controller.dart';

class DetailScreen extends StatefulWidget {
  final Receipt receipt;
  const DetailScreen({super.key, required this.receipt});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> with SingleTickerProviderStateMixin {
  // ── Controller ──────────────────────────────────────────────────────────
  late final DetailController _ctrl;

  // ── Animasi (tetap di View) ─────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = DetailController(receipt: widget.receipt);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── View Actions (UI side-effects) ──────────────────────────────────────
  void _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Struk?', style: AppTextStyles.headlineMd()),
        content: Text('Data tidak dapat dipulihkan.', style: AppTextStyles.bodyMd()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorContainer, foregroundColor: AppColors.onErrorContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Hapus', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _ctrl.deleteReceipt();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('ReceiptSync'),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _ReceiptImageCard(confidence: r.confidenceScore),
            const SizedBox(height: 16),
            _DetailCard(receipt: r),
            const SizedBox(height: 80),
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Amount'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  side: const BorderSide(color: AppColors.outlineVariant),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.errorContainer.withValues(alpha: 0.8),
                  foregroundColor: AppColors.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ReceiptImageCard extends StatelessWidget {
  final double confidence;
  const _ReceiptImageCard({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.successGlint.withValues(alpha: 0.5), width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF252830), Color(0xFF1A1C24)],
            ),
          ),
          child: CustomPaint(painter: _ReceiptTexturePainter()),
        ),
        Positioned(
          left: 40, top: 20, right: 40, bottom: 60,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.successGlint, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Positioned(
          top: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.successGlint.withValues(alpha: 0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, color: AppColors.successGlint, size: 14),
              const SizedBox(width: 6),
              Text(
                'OCR ${(confidence * 100).toStringAsFixed(0)}% CONF',
                style: AppTextStyles.labelCaps(color: AppColors.successGlint),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _ReceiptTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.onSurface.withValues(alpha: 0.04)..strokeWidth = 0.5;
    for (double y = 20; y < size.height - 20; y += 14) {
      final lineW = size.width * 0.5 + (size.width * 0.4 * ((y / size.height) % 1.0));
      final x0 = (size.width - lineW) / 2;
      canvas.drawLine(Offset(x0, y), Offset(x0 + lineW, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _DetailCard extends StatelessWidget {
  final Receipt receipt;
  const _DetailCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('EXTRACTED TOTAL', style: AppTextStyles.labelCaps()),
            const SizedBox(height: 4),
            Text(receipt.formattedAmount, style: AppTextStyles.numericDisplay()),
          ])),
          _SyncStatusPill(isSynced: receipt.isSynced),
        ]),
        const SizedBox(height: 16),
        const Divider(color: AppColors.outlineVariant, height: 1),
        const SizedBox(height: 16),
        _Row(label: 'Date', value: '${receipt.formattedDate} • ${receipt.formattedTime}'),
        const SizedBox(height: 12),
        _Row(label: 'Merchant', value: receipt.merchantName ?? 'Unknown'),
        const SizedBox(height: 12),
        _Row(label: 'Confidence', value: receipt.confidencePercent),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.bodyMd()),
      Text(value, style: AppTextStyles.bodyMd(color: AppColors.onSurface)),
    ]);
  }
}

class _SyncStatusPill extends StatelessWidget {
  final bool isSynced;
  const _SyncStatusPill({required this.isSynced});
  @override
  Widget build(BuildContext context) {
    final color = isSynced ? AppColors.onSurfaceVariant : AppColors.syncStatusPending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isSynced ? AppColors.surfaceContainerHighest : AppColors.syncStatusPending.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(isSynced ? 'Synced' : 'Pending Sync', style: AppTextStyles.label(color: color)),
      ]),
    );
  }
}
