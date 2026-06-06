import 'package:hive/hive.dart';
import '../models/receipt.dart';
import '../models/receipt_adapter.dart';
import '../services/mongo_service.dart';
import '../services/hive_service.dart';

/// Repository untuk akses data Receipt menggunakan Hive local database.
///
/// Menyediakan:
/// - Basic CRUD operations
/// - Advanced filtering & sorting
/// - Query statistics
/// - Batch operations
/// - Pagination support
class ReceiptRepository {
  /// Mendapatkan Hive box
  static Box<Receipt> get _box => HiveService.receiptsBox;
  static List<Receipt> get allReceipts => getAll();

  // ── CRUD Operations ────────────────────────────────────────────────────

  /// Simpan receipt baru ke database lokal
  static Future<void> addReceipt(Receipt receipt) async {
    await _box.put(receipt.id, receipt);
  }

  /// Simpan multiple receipts sekaligus
  static Future<void> addMultipleReceipts(List<Receipt> receipts) async {
    final map = {for (var r in receipts) r.id: r};
    await _box.putAll(map);
  }

  /// Ambil semua receipt, diurutkan dari terbaru
  static List<Receipt> getAll() {
    final receipts = _box.values.toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Ambil satu receipt berdasarkan ID
  static Receipt? getById(String id) {
    return _box.get(id);
  }

  /// Update receipt yang sudah ada
  static Future<void> updateReceipt(Receipt receipt) async {
    await _box.put(receipt.id, receipt);
  }

  /// Hapus receipt berdasarkan ID
  static Future<void> deleteReceipt(String id) async {
    await _box.delete(id);
  }

  /// Hapus multiple receipts
  static Future<void> deleteMultipleReceipts(List<String> ids) async {
    await _box.deleteAll(ids);
  }

  /// Hapus semua receipts
  static Future<void> deleteAllReceipts() async {
    await _box.clear();
  }

  // ── Filtering & Searching ──────────────────────────────────────────────

  /// Filter receipts berdasarkan kondisi
  static List<Receipt> filterBy({
    bool? isSynced,
    double? minAmount,
    double? maxAmount,
    double? minConfidence,
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    var receipts = _box.values.toList();

    // Filter by sync status
    if (isSynced != null) {
      receipts = receipts.where((r) => r.isSynced == isSynced).toList();
    }

    // Filter by amount
    if (minAmount != null) {
      receipts = receipts.where((r) => r.totalAmount >= minAmount).toList();
    }
    if (maxAmount != null) {
      receipts = receipts.where((r) => r.totalAmount <= maxAmount).toList();
    }

    // Filter by confidence
    if (minConfidence != null) {
      receipts = receipts
          .where((r) => r.confidenceScore >= minConfidence)
          .toList();
    }

    // Filter by user ID
    if (userId != null) {
      receipts = receipts.where((r) => r.userId == userId).toList();
    }

    // Filter by date range
    if (fromDate != null) {
      receipts = receipts.where((r) => r.scannedAt.isAfter(fromDate)).toList();
    }
    if (toDate != null) {
      final endOfDay = toDate.add(const Duration(days: 1));
      receipts = receipts.where((r) => r.scannedAt.isBefore(endOfDay)).toList();
    }

    // Sort by date (terbaru duluan)
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Cari receipts berdasarkan user ID
  static List<Receipt> getByUserId(String userId) {
    final receipts = _box.values.where((r) => r.userId == userId).toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Ambil receipts dari tanggal tertentu
  static List<Receipt> getByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final receipts = _box.values
        .where(
          (r) =>
              r.scannedAt.isAfter(startOfDay) && r.scannedAt.isBefore(endOfDay),
        )
        .toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Ambil receipts dalam range tanggal
  static List<Receipt> getByDateRange(DateTime startDate, DateTime endDate) {
    final endOfDay = endDate.add(const Duration(days: 1));
    final receipts = _box.values
        .where(
          (r) =>
              r.scannedAt.isAfter(startDate) && r.scannedAt.isBefore(endOfDay),
        )
        .toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Ambil receipts yang belum disinkronkan
  static List<Receipt> getPending() {
    final receipts = _box.values.where((r) => !r.isSynced).toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  /// Ambil receipts dengan confidence >= threshold
  static List<Receipt> getHighConfidence(double threshold) {
    final receipts = _box.values
        .where((r) => r.confidenceScore >= threshold)
        .toList();
    receipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return receipts;
  }

  // ── Pagination ─────────────────────────────────────────────────────────

  /// Ambil receipts dengan pagination
  ///
  /// [page] dimulai dari 0
  /// [pageSize] jumlah items per halaman
  static List<Receipt> paginate(int page, int pageSize) {
    final all = getAll();
    final start = page * pageSize;
    final end = (start + pageSize).clamp(0, all.length);

    if (start >= all.length) return [];
    return all.sublist(start, end);
  }

  // ── Statistics ────────────────────────────────────────────────────────

  /// Jumlah receipt yang belum disinkronkan
  static int get pendingCount => _box.values.where((r) => !r.isSynced).length;

  /// Total pengeluaran dari semua receipt
  static double get totalSpending =>
      _box.values.fold(0, (sum, r) => sum + r.totalAmount);

  /// Total jumlah receipt yang tersimpan
  static int get totalScanned => _box.length;

  /// Progress sinkronisasi (0.0 - 1.0)
  static double get syncProgress {
    if (_box.isEmpty) return 1.0;
    final synced = _box.values.where((r) => r.isSynced).length;
    return synced / _box.length;
  }

  /// Average amount per receipt
  static double get averageAmount {
    if (_box.isEmpty) return 0;
    return totalSpending / _box.length;
  }

  /// Average confidence score
  static double get averageConfidence {
    if (_box.isEmpty) return 0;
    final avgScore =
        _box.values.fold(0.0, (sum, r) => sum + r.confidenceScore) /
        _box.length;
    return avgScore;
  }

  /// Receipt dengan amount tertinggi
  static Receipt? getHighestAmountReceipt() {
    if (_box.isEmpty) return null;
    var highest = _box.values.first;
    for (final receipt in _box.values) {
      if (receipt.totalAmount > highest.totalAmount) {
        highest = receipt;
      }
    }
    return highest;
  }

  /// Receipt dengan amount terendah
  static Receipt? getLowestAmountReceipt() {
    if (_box.isEmpty) return null;
    var lowest = _box.values.first;
    for (final receipt in _box.values) {
      if (receipt.totalAmount < lowest.totalAmount) {
        lowest = receipt;
      }
    }
    return lowest;
  }

  /// Jumlah receipt per user
  static Map<String, int> getCountPerUser() {
    final map = <String, int>{};
    for (final receipt in _box.values) {
      map[receipt.userId] = (map[receipt.userId] ?? 0) + 1;
    }
    return map;
  }

  /// Total spending per user
  static Map<String, double> getTotalSpendingPerUser() {
    final map = <String, double>{};
    for (final receipt in _box.values) {
      map[receipt.userId] = (map[receipt.userId] ?? 0) + receipt.totalAmount;
    }
    return map;
  }

  /// Dapatkan comprehensive statistics
  static Map<String, dynamic> getStatistics() {
    return {
      'total_scanned': totalScanned,
      'total_spending': totalSpending,
      'average_amount': averageAmount,
      'pending_count': pendingCount,
      'sync_progress': syncProgress,
      'average_confidence': averageConfidence,
      'highest_amount': getHighestAmountReceipt()?.totalAmount,
      'lowest_amount': getLowestAmountReceipt()?.totalAmount,
    };
  }

  // ── Batch Operations ───────────────────────────────────────────────────

  /// Mark semua receipts sebagai synced
  static Future<void> markAllAsSynced() async {
    final updated = _box.values.map((r) => r.copyWith(isSynced: true)).toList();
    final map = {for (var r in updated) r.id: r};
    await _box.putAll(map);
  }

  /// Mark specific receipts sebagai synced
  static Future<void> markAsSynced(List<String> ids) async {
    for (final id in ids) {
      final receipt = _box.get(id);
      if (receipt != null) {
        await updateReceipt(receipt.copyWith(isSynced: true));
      }
    }
  }

  /// Print debug statistics
  static void printStats() {
    print('╔════════════════════════════════════════╗');
    print('║     RECEIPT REPOSITORY STATS           ║');
    print('╚════════════════════════════════════════╝');
    print('Total receipts: $totalScanned');
    print('Total spending: ${totalSpending.toStringAsFixed(2)}');
    print('Average per receipt: ${averageAmount.toStringAsFixed(2)}');
    print('Pending sync: $pendingCount');
    print('Sync progress: ${(syncProgress * 100).toStringAsFixed(1)}%');
    print(
      'Average confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%',
    );
  }

  static List<Receipt> getAllForCurrentUser() {
    final currentUserId = MongoService.currentUserId;
    if (currentUserId == null) return [];

    // Filter di sisi Hive (Local)
    final allReceipts = _box.values.toList();
    final userReceipts = allReceipts.where((r) => r.userId == currentUserId).toList();
    
    // Urutkan dari yang terbaru
    userReceipts.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return userReceipts;
  }
}
