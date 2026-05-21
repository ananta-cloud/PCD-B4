import '../models/receipt.dart';

/// Fake in-memory data — replace with Hive in production
class MockReceiptRepository {
  static final List<Receipt> _receipts = [
    Receipt(
      id: '1',
      userId: 'user_001',
      totalAmount: 142500,
      confidenceScore: 0.85,
      scannedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isSynced: false,
      merchantName: 'Hardware Store',
    ),
    Receipt(
      id: '2',
      userId: 'user_001',
      totalAmount: 12000,
      confidenceScore: 0.92,
      scannedAt: DateTime.now().subtract(const Duration(hours: 8)),
      isSynced: false,
      merchantName: 'Coffee Roasters',
    ),
    Receipt(
      id: '3',
      userId: 'user_001',
      totalAmount: 45990,
      confidenceScore: 0.78,
      scannedAt: DateTime.now().subtract(const Duration(hours: 5)),
      isSynced: false,
      merchantName: 'Office Supplies',
    ),
    Receipt(
      id: '4',
      userId: 'user_001',
      totalAmount: 89200,
      confidenceScore: 0.95,
      scannedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      isSynced: true,
      merchantName: 'Groceries',
    ),
    Receipt(
      id: '5',
      userId: 'user_001',
      totalAmount: 310000,
      confidenceScore: 0.88,
      scannedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      isSynced: true,
      merchantName: 'Client Dinner',
    ),
    Receipt(
      id: '6',
      userId: 'user_001',
      totalAmount: 55000,
      confidenceScore: 0.81,
      scannedAt: DateTime.now().subtract(const Duration(days: 2, hours: 10)),
      isSynced: true,
      merchantName: 'Minimarket',
    ),
  ];

  static List<Receipt> getAll() => List.from(_receipts);

  static int get pendingCount =>
      _receipts.where((r) => !r.isSynced).length;

  static double get totalSpending =>
      _receipts.fold(0, (sum, r) => sum + r.totalAmount);

  static int get totalScanned => _receipts.length;

  static double get syncProgress {
    final synced = _receipts.where((r) => r.isSynced).length;
    return synced / _receipts.length;
  }

  static void addReceipt(Receipt receipt) {
    _receipts.insert(0, receipt);
  }

  static void deleteReceipt(String id) {
    _receipts.removeWhere((r) => r.id == id);
  }
}
