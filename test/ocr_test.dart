import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

// Pastikan import ini sesuai dengan nama project Anda
import 'package:smart_receipt_scanner/services/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OcrService Dataset Test di Perangkat Asli', () {
    test('Memproses gambar 0.jpg sampai 19.jpg dari Assets', () async {
      print('\n==================================================');
      print('🚀 MENYIAPKAN GAMBAR DARI ASSETS KE MEMORI HP...');
      
      // Dapatkan folder sementara (Cache) di HP Android
      final tempDir = await getTemporaryDirectory();
      int successCount = 0;
      
      // Karena kita tahu jumlah filenya ada 20 (0.jpg sampai 19.jpg)
      int totalImages = 20; 

      print('Memulai pengujian $totalImages gambar...');
      print('==================================================\n');

      // Looping langsung dari angka 0 sampai 19
      for (int i = 0; i < totalImages; i++) {
        final fileName = '$i.jpg'; // Format: 0.jpg, 1.jpg, dst.
        final assetPath = 'lib/models/datasets/images/$fileName';
        
        print('📷 Menganalisis: $fileName ...');

        try {
          // Salin file dari Asset ke memori penyimpanan HP
          final byteData = await rootBundle.load(assetPath);
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(byteData.buffer.asUint8List());

          // Jalankan fungsi dari OcrService
          final parsedReceipt = await OcrService.processImage(file);

          // Tampilkan hasil heuristik / parsing
          print('   ↳ Total Harga : Rp ${parsedReceipt.total}');
          print('   ↳ Subtotal    : Rp ${parsedReceipt.subtotal}');
          print('   ↳ Cash/Tunai  : Rp ${parsedReceipt.cash ?? '-'}');
          print('   ↳ Kembalian   : Rp ${parsedReceipt.change ?? '-'}');
          print('   ↳ Jumlah Item : ${parsedReceipt.items.length}');
          
          if (parsedReceipt.items.isNotEmpty) {
            print('   ↳ Contoh Item : ${parsedReceipt.items.first.name} (Rp ${parsedReceipt.items.first.totalPrice})');
          }
          
          successCount++;
        } catch (e) {
          print('   ❌ Gagal memproses file $fileName: Pastikan file ini ada di pubspec.yaml');
          // e.toString() disembunyikan agar log tidak terlalu panjang, tapi bisa Anda tambahkan jika perlu
        }
        print('--------------------------------------------------');
      }

      print('\n==================================================');
      print('✅ PENGUJIAN SELESAI');
      print('Berhasil memproses: $successCount / $totalImages gambar');
      print('==================================================\n');
    });
  });
}