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

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  // ── Controller ──────────────────────────────────────────────────────────
  late final DetailController _ctrl;

  // ── Animasi (tetap di View) ─────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = DetailController(receipt: widget.receipt);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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
        content: Text(
          'Data tidak dapat dipulihkan.',
          style: AppTextStyles.bodyMd(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorContainer,
              foregroundColor: AppColors.onErrorContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _ctrl.deleteReceipt();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.receipt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Struk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: const Text('Hapus'),
                        onTap: () {
                          Navigator.pop(context);
                          _onDelete();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.share_outlined),
                        title: const Text('Bagikan'),
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Fitur bagikan belum tersedia'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.storefront,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  r.merchantName ?? 'Unknown Merchant',
                  style: AppTextStyles.headlineMd(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  r.formattedDate,
                  style: AppTextStyles.bodyMd(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.formattedTime,
                  style: AppTextStyles.bodyMd(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                // Receipt details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Receipt ID', style: AppTextStyles.bodyMd()),
                    Expanded(
                      child: Text(
                        r.id,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodyMd(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount', style: AppTextStyles.bodyMd()),
                    Text(r.formattedAmount, style: AppTextStyles.bodyMd()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Confidence', style: AppTextStyles.bodyMd()),
                    Text(r.confidencePercent, style: AppTextStyles.bodyMd()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status', style: AppTextStyles.bodyMd()),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: r.isSynced
                            ? AppColors.tertiaryContainer
                            : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.isSynced ? 'Synced' : 'Pending',
                        style: AppTextStyles.label(
                          color: r.isSynced
                              ? AppColors.onTertiaryContainer
                              : AppColors.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL', style: AppTextStyles.headlineMd()),
                    Text(
                      r.formattedAmount,
                      style: AppTextStyles.headlineMd(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _onDelete(),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorContainer,
                      foregroundColor: AppColors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
