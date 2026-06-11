import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Tambahkan import ini
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../repositories/receipt_repository.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import 'account_settings_screen.dart';
import '../services/pdf_service.dart';

// Ubah dari StatelessWidget → StatefulWidget
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // ── TAMBAHAN: State bulan yang dipilih ──────────────────────────────
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isExporting = false;

  void _changeMonth(int monthsToAdd) {
    final next = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + monthsToAdd,
    );
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    if (next.isAfter(now)) return; // Batasi maks bulan sekarang
    setState(() {
      _selectedMonth = next;
    });
  }
  // ────────────────────────────────────────────────────────────────────

  String _formatAmount(double amount) {
    final f = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }

  @override
  Widget build(BuildContext context) {
    // ── TAMBAHAN: Filter data berdasarkan bulan yang dipilih ────────────
    final allReceipts = ReceiptRepository.getAll().where((r) {
      return r.scannedAt.year == _selectedMonth.year &&
          r.scannedAt.month == _selectedMonth.month;
    }).toList();

    final total = allReceipts.fold(0.0, (sum, r) => sum + r.totalAmount);
    final scanned = allReceipts.length;
    // ────────────────────────────────────────────────────────────────────

    // Data ini tidak bergantung bulan, tetap dari repository global
    final syncProgress = ReceiptRepository.syncProgress;
    final pending = ReceiptRepository.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReceiptSync'),
        leading: IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final authCtrl = AuthController();
              await authCtrl.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Reports Overview', style: AppTextStyles.headlineXl()),
          const SizedBox(height: 6),

          // ── TAMBAHAN: Navigasi bulan ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: AppTextStyles.headlineMd(),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  // ── TAMBAHAN: null = tombol disabled jika sudah bulan ini ──
                  onPressed:
                      _selectedMonth.year == DateTime.now().year &&
                          _selectedMonth.month == DateTime.now().month
                      ? null
                      : () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // ─────────────────────────────────────────────────────────────
          const SizedBox(height: 8),

          // ── TAMBAHAN: Tombol Export PDF ────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isExporting || allReceipts.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        _isExporting = true;
                      });
                      try {
                        await PdfService.exportMonthlyRecap(
                          _selectedMonth,
                          allReceipts,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal export PDF: $e')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isExporting = false;
                          });
                        }
                      }
                    },
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _StatCard(
            label: 'TOTAL SPENDING',
            icon: Icons.credit_card_outlined,
            iconColor: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAmount(total),
                  style: AppTextStyles.numericDisplay(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Based on $scanned receipts',
                  style: AppTextStyles.bodyMd(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _StatCard(
            label: 'RECEIPTS SCANNED',
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.tertiary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$scanned', style: AppTextStyles.numericDisplay()),
                const SizedBox(height: 6),
                Text(
                  'Across ${(scanned * 0.1).ceil()} different merchants',
                  style: AppTextStyles.bodyMd(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _StatCard(
            label: 'CLOUD SYNC PROGRESS',
            trailing: Text(
              '${(syncProgress * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.bodyLg(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: syncProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.outlineVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                if (pending > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.sync_problem_outlined,
                        color: AppColors.syncStatusPending,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$pending receipts waiting for connection',
                        style: AppTextStyles.label(
                          color: AppColors.syncStatusPending,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'QUICK SETTINGS',
                      style: AppTextStyles.labelCaps(),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  label: 'Ganti Password',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AccountSettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// _StatCard dan _SettingsTile tidak berubah
class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  const _StatCard({
    required this.label,
    required this.child,
    this.icon,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.labelCaps())),
              if (icon != null)
                Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
