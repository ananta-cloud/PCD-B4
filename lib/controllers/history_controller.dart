import 'package:flutter/foundation.dart';
import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';

/// Controller untuk HistoryScreen — mengelola daftar struk dan pengelompokan.
class HistoryController extends ChangeNotifier {
  List<Receipt> _receipts = [];

  /// Daftar semua struk
  List<Receipt> get receipts => _receipts;

  /// Jumlah struk yang belum disinkronkan
  int get pendingCount => ReceiptRepository.pendingCount;

  /// Struk dikelompokkan berdasarkan hari (Today, Yesterday, N Days Ago)
  Map<String, List<Receipt>> get grouped {
    final now = DateTime.now();
    final Map<String, List<Receipt>> g = {};
    for (final r in _receipts) {
      final diff = now.difference(r.scannedAt).inDays;
      final label = diff == 0 ? 'Today' : diff == 1 ? 'Yesterday' : '$diff Days Ago';
      g.putIfAbsent(label, () => []).add(r);
    }
    return g;
  }

  /// Muat ulang daftar struk dari Hive database
  void loadReceipts() {
    _receipts = ReceiptRepository.getAll();
    notifyListeners();
  }
}
