import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../services/mock_receipt_service.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Receipt> _receipts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _receipts = MockReceiptService.getAll());

  // Group by day
  Map<String, List<Receipt>> get _grouped {
    final now = DateTime.now();
    final Map<String, List<Receipt>> g = {};
    for (final r in _receipts) {
      final diff = now.difference(r.scannedAt).inDays;
      final label = diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : '$diff Days Ago';
      g.putIfAbsent(label, () => []).add(r);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final pending = MockReceiptService.pendingCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReceiptSync'),
        actions: [_iconBtn(Icons.manage_accounts_outlined, () {})],
        leading: _iconBtn(Icons.settings_outlined, () {}),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Pending sync banner
            if (pending > 0) ...[
              _SyncBanner(pendingCount: pending),
              const SizedBox(height: 20),
            ],
            // Grouped list
            ..._grouped.entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: AppTextStyles.headlineMd()),
                const SizedBox(height: 12),
                ...entry.value.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReceiptCard(
                    receipt: r,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(receipt: r)));
                      _load();
                    },
                  ),
                )),
                const SizedBox(height: 12),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
      onPressed: onTap,
    );
  }
}

class _SyncBanner extends StatelessWidget {
  final int pendingCount;
  const _SyncBanner({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppColors.syncStatusPending, width: 4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.syncStatusPending.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.cloud_upload_outlined, color: AppColors.syncStatusPending, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Local Hive Database', style: AppTextStyles.label(color: AppColors.onSurface)),
          const SizedBox(height: 2),
          Text('$pendingCount items pending sync', style: AppTextStyles.label(color: AppColors.syncStatusPending)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHighest,
            foregroundColor: AppColors.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('SYNC\nNOW', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onTap;
  const _ReceiptCard({required this.receipt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(receipt.formattedAmount, style: AppTextStyles.headlineMd()),
            const SizedBox(height: 4),
            Text(
              '${receipt.merchantName ?? "Unknown"} • ${receipt.formattedTime}',
              style: AppTextStyles.bodyMd(),
            ),
          ])),
          _SyncChip(isSynced: receipt.isSynced),
        ]),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final bool isSynced;
  const _SyncChip({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final color = isSynced ? AppColors.onSurfaceVariant : AppColors.syncStatusPending;
    final bg = isSynced ? AppColors.surfaceContainerHighest : AppColors.syncStatusPending.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isSynced ? Icons.cloud_done_outlined : Icons.schedule, color: color, size: 14),
        const SizedBox(width: 6),
        Text(isSynced ? 'Synced' : 'Pending', style: AppTextStyles.label(color: color)),
      ]),
    );
  }
}
