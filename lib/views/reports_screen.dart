import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../services/mock_receipt_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final total = MockReceiptService.totalSpending;
    final scanned = MockReceiptService.totalScanned;
    final syncProgress = MockReceiptService.syncProgress;
    final pending = MockReceiptService.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReceiptSync'),
        leading: IconButton(icon: const Icon(Icons.settings_outlined, size: 22, color: AppColors.onSurfaceVariant), onPressed: () {}),
        actions: [IconButton(icon: const Icon(Icons.manage_accounts_outlined, size: 22, color: AppColors.onSurfaceVariant), onPressed: () {})],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Page title
          Text('Reports Overview', style: AppTextStyles.headlineXl()),
          const SizedBox(height: 6),
          Text('Your scanning and spending statistics for this month.', style: AppTextStyles.bodyMd()),
          const SizedBox(height: 24),

          // Total spending card
          _StatCard(
            label: 'TOTAL SPENDING',
            icon: Icons.credit_card_outlined,
            iconColor: AppColors.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_formatAmount(total), style: AppTextStyles.numericDisplay()),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.trending_down, color: AppColors.secondary, size: 18),
                const SizedBox(width: 4),
                Text('12% less than last month', style: AppTextStyles.label(color: AppColors.secondary)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),

          // Receipts scanned card
          _StatCard(
            label: 'RECEIPTS SCANNED',
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.tertiary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$scanned', style: AppTextStyles.numericDisplay()),
              const SizedBox(height: 6),
              Text('Across ${(scanned * 0.1).ceil()} different merchants', style: AppTextStyles.bodyMd()),
            ]),
          ),
          const SizedBox(height: 12),

          // Cloud sync progress
          _StatCard(
            label: 'CLOUD SYNC PROGRESS',
            trailing: Text('${(syncProgress * 100).toStringAsFixed(0)}%', style: AppTextStyles.bodyLg()),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: syncProgress,
                  minHeight: 8,
                  backgroundColor: AppColors.outlineVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              if (pending > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.sync_problem_outlined, color: AppColors.syncStatusPending, size: 16),
                  const SizedBox(width: 6),
                  Text('$pending receipts waiting for connection', style: AppTextStyles.label(color: AppColors.syncStatusPending)),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // Quick settings
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                child: Align(alignment: Alignment.centerLeft, child: Text('QUICK SETTINGS', style: AppTextStyles.labelCaps())),
              ),
              _SettingsTile(
                icon: Icons.wifi_off_outlined,
                label: 'Offline Mode',
                trailing: Switch(
                  value: false,
                  onChanged: (_) {},
                  activeThumbColor: AppColors.primary,
                  inactiveThumbColor: AppColors.outlineVariant,
                ),
              ),
              const Divider(color: AppColors.outlineVariant, height: 1, indent: 20, endIndent: 20),
              _SettingsTile(
                icon: Icons.person_outline,
                label: 'Account',
                trailing: const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                onTap: () {},
              ),
              const SizedBox(height: 8),
            ]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    final f = amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;

  const _StatCard({required this.label, required this.child, this.icon, this.iconColor, this.trailing});

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
          Expanded(child: Text(label, style: AppTextStyles.labelCaps())),
          if (icon != null) Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.label, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
      title: Text(label, style: GoogleFonts.inter(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w400)),
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
