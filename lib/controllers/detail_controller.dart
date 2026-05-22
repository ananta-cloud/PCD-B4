import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../repositories/mock_receipt_repository.dart';

/// Controller untuk DetailScreen — mengelola aksi pada satu struk.
class DetailController extends ChangeNotifier {
  final Receipt receipt;

  DetailController({required this.receipt});

  /// Hapus struk dari repository. Returns true jika berhasil.
  bool deleteReceipt() {
    MockReceiptRepository.deleteReceipt(receipt.id);
    return true;
  }
}
