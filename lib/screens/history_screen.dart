import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/receipt.dart';
import '../services/mongo_service.dart';
import 'detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Kita menggunakan Future agar bisa dipakai oleh FutureBuilder
  late Future<List<Map<String, dynamic>>> _receiptsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _receiptsFuture = MongoService.getReceiptHistory();
    });
  }

  // Fungsi untuk mengelompokkan data berdasarkan hari
  Map<String, List<Map<String, dynamic>>> _groupData(List<Map<String, dynamic>> rawData) {
    final now = DateTime.now();
    final Map<String, List<Map<String, dynamic>>> g = {};
    
    for (final r in rawData) {
      // Pastikan tipe data tanggal dari MongoDB di-handle dengan benar.
      // Jika di MongoDB disimpen sebagai string, parse dulu: DateTime.parse(r['scanDate'])
      // Jika disimpan sebagai Date di MongoDB, mungkin akan menjadi DateTime di Dart.
      DateTime scannedAt = r['scanDate'] is DateTime 
          ? r['scanDate'] 
          : (r['scanDate'] != null ? DateTime.tryParse(r['scanDate'].toString()) ?? now : now);

      final diff = now.difference(scannedAt).inDays;
      final label = diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : '$diff Days Ago';
      g.putIfAbsent(label, () => []).add(r);
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = 0; 

    return Scaffold(
      appBar: AppBar(
      title: const Text('ReceiptSync'),
      actions: [
        // TOMBOL INI HANYA UNTUK TESTING INSERT DATA
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green),
          tooltip: "Tambah Data Dummy ke MongoDB",
          onPressed: () async {
            // Tampilkan loading
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menyimpan data ke MongoDB...')));
            
            // Sengaja mock currentUserId agar bisa insert jika kamu lewati screen Login
            if(MongoService.currentUserId == null){
                MongoService.currentUserId = "user_test_123";
            }

            // Panggil fungsi insert
            bool success = await MongoService.insertReceipt("Toko ABC Dummy", 150000.0);
            
            if (success) {
              // Jika berhasil, panggil _load() untuk me-refresh layar
              _load();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Berhasil! Menarik data terbaru...')));
            }
          },
        ),
        _iconBtn(Icons.manage_accounts_outlined, () {}),
      ],
      leading: _iconBtn(Icons.settings_outlined, () {}),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        color: AppColors.primary,
        child: FutureBuilder<List<Map<String, dynamic>>>(
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
                      child: Text("Terjadi kesalahan: ${snapshot.error}", textAlign: TextAlign.center,),
                    ),
                  )
                ]
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
                  )
                ],
              );
            }

            final groupedData = _groupData(data);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [

                if (pendingCount > 0) ...[
                  _SyncBanner(pendingCount: pendingCount),
                  const SizedBox(height: 20),
                ],
                ...groupedData.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: AppTextStyles.headlineMd()),
                    const SizedBox(height: 12),
                    ...entry.value.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReceiptCard(
                        receiptData: r,
                        onTap: () async {
                          _load();
                        },
                      ),
                    )),
                    const SizedBox(height: 12),
                  ],
                )),
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

class _SyncBanner extends StatelessWidget {
  final int pendingCount;
  const _SyncBanner({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: AppColors.syncStatusPending, width: 4)),
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
  // Menerima map data langsung dari MongoDB untuk dirender
  final Map<String, dynamic> receiptData; 
  final VoidCallback onTap;
  
  const _ReceiptCard({required this.receiptData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final merchantName = receiptData['storeName'] ?? "Unknown";
    final amount = receiptData['totalAmount'] ?? 0;
    
    final formattedAmount = 'Rp $amount'; 
    
    final isSynced = receiptData['isSynced'] ?? true; 

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
            Text(formattedAmount, style: AppTextStyles.headlineMd()),
            const SizedBox(height: 4),
            Text(
              merchantName, 
              style: AppTextStyles.bodyMd(),
            ),
          ])),
          _SyncChip(isSynced: isSynced),
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