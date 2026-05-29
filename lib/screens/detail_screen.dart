import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class DetailScreen extends StatelessWidget {
  // Menerima data struk dalam bentuk Map (JSON)
  final Map<String, dynamic> receiptData;

  const DetailScreen({super.key, required this.receiptData});

  @override
  Widget build(BuildContext context) {
    // Ekstrak data dengan nilai fallback (jaga-jaga jika null)
    final storeName = receiptData['storeName'] ?? 'Unknown Merchant';
    final totalAmount = receiptData['totalAmount'] ?? 0;
    
    // Format Tanggal
    DateTime scanDate;
    if (receiptData['scanDate'] is DateTime) {
      scanDate = receiptData['scanDate'];
    } else {
      scanDate = DateTime.tryParse(receiptData['scanDate']?.toString() ?? '') ?? DateTime.now();
    }
    
    // Bikin format tanggal cantik (misal: 22/5/2026 - 14:30)
    final dateString = "${scanDate.day}/${scanDate.month}/${scanDate.year} - ${scanDate.hour}:${scanDate.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Struk'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            // Efek bayangan ringan agar terlihat seperti kartu/struk
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                storeName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                dateString,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              const Divider(thickness: 2), // Garis pemisah
              
              const SizedBox(height: 16),
              
              // ----------------------------------------------------
              // PERBAIKAN 1: Baris Item (Menggunakan Expanded)
              // ----------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  const Expanded(
                    child: Text('1x Item Pembelanjaan', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Text('Rp $totalAmount', style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              
              const Divider(thickness: 2), 
              
              const SizedBox(height: 16),
              
              // ----------------------------------------------------
              // PERBAIKAN 2: Baris TOTAL (Menggunakan Expanded)
              // ----------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Rp $totalAmount',
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primary
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Tombol Tambahan (Opsional)
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur cetak/bagikan belum tersedia')),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text('Bagikan Struk'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}