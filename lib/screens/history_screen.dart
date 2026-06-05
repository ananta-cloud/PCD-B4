import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import 'detail_screen.dart';
import '../repositories/receipt_repository.dart';
import '../services/hive_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Kita menggunakan Future agar bisa dipakai oleh FutureBuilder
  late Future<List<Receipt>> _receiptsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _receiptsFuture = Future.value(ReceiptRepository.getAll());
    });
  }

  // Fungsi untuk mengelompokkan data berdasarkan hari
  Map<String, List<Receipt>> _groupData(List<Receipt> receipts) {
    final now = DateTime.now();
    final Map<String, List<Receipt>> g = {};

    for (final r in receipts) {
      final diff = now.difference(r.scannedAt).inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
          ? 'Yesterday'
          : '$diff Days Ago';
      g.putIfAbsent(label, () => []).add(r);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ReceiptRepository.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReceiptSync'),
        leading: _iconBtn(Icons.settings_outlined, () {}),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppColors.primary,
        child: FutureBuilder<List<Receipt>>(
          future: _receiptsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Terjadi kesalahan: ${snapshot.error}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data ?? [];

            if (data.isEmpty) {
              return ListView(
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Text("Belum ada riwayat scan."),
                    ),
                  ),
                ],
              );
            }

            final groupedData = _groupData(data);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (pendingCount > 0) ...[
                  _SyncBanner(pendingCount: pendingCount, onSyncDone: _load),
                  const SizedBox(height: 20),
                ],
                ...groupedData.entries.map(
                  (entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: AppTextStyles.headlineMd()),
                      const SizedBox(height: 12),
                      ...entry.value.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReceiptCard(
                            receipt: r,
                            onTap: () async {
                              // NAVIGASI KE DETAIL SCREEN DAN PASSING DATA 'r'
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailScreen(receipt: r),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            );
          },
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

class _SyncBanner extends StatefulWidget {
  final int pendingCount;
  final VoidCallback onSyncDone;
  const _SyncBanner({required this.pendingCount, required this.onSyncDone});

  @override
  State<_SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<_SyncBanner> {
  bool _isSyncing = false;

  Future<void> _doSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    await HiveUtils.syncPending();
    if (mounted) {
      setState(() => _isSyncing = false);
      widget.onSyncDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: AppColors.syncStatusPending, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.syncStatusPending.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: AppColors.syncStatusPending,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Hive Database',
                  style: AppTextStyles.label(color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.pendingCount} items pending sync',
                  style: AppTextStyles.label(
                    color: AppColors.syncStatusPending,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _isSyncing ? null : _doSync,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHighest,
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'SYNC\nNOW',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  // Menerima Receipt object untuk dirender
  final Receipt receipt;
  final VoidCallback onTap;

  const _ReceiptCard({required this.receipt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final merchantName = receipt.merchantName ?? "Unknown";
    final formattedAmount = receipt.formattedAmount;
    final isSynced = receipt.isSynced;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedAmount, style: AppTextStyles.headlineMd()),
                  const SizedBox(height: 4),
                  Text(merchantName, style: AppTextStyles.bodyMd()),
                ],
              ),
            ),
            _SyncChip(isSynced: isSynced),
          ],
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final bool isSynced;
  const _SyncChip({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final color = isSynced
        ? AppColors.onSurfaceVariant
        : AppColors.syncStatusPending;
    final bg = isSynced
        ? AppColors.surfaceContainerHighest
        : AppColors.syncStatusPending.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done_outlined : Icons.schedule,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isSynced ? 'Synced' : 'Pending',
            style: AppTextStyles.label(color: color),
          ),
        ],
      ),
    );
  }
}
