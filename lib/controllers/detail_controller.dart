import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';

/// Controller untuk DetailScreen — mengelola aksi pada satu struk.
class DetailController extends ChangeNotifier {
  final Receipt receipt;

  DetailController({required this.receipt});

  /// Hapus struk dari Hive database dan file gambar terkait.
  /// Returns true jika berhasil.
  Future<bool> deleteReceipt() async {
    // Hapus file gambar jika ada
    if (receipt.imagePath != null) {
      final file = File(receipt.imagePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Hapus dari Hive
    await ReceiptRepository.deleteReceipt(receipt.id);
    return true;
  }
}
