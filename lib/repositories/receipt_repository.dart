import 'package:hive/hive.dart';
import '../models/receipt.dart';

/// Repository untuk akses data Receipt menggunakan Hive local database.
///
/// API sengaja dibuat identik dengan MockReceiptRepository
/// agar migrasi controller minimal.
class ReceiptRepository {
  static const _boxName = 'receipts';

  /// Mendapatkan Hive box (harus sudah di-open di main.dart)
  static Box<Receipt> get _box => Hive.box<Receipt>(_boxName);

  // ── CRUD ────────────────────────────────────────────────────────────────

  /// Simpan receipt baru ke database lokal
  static Future<void> addReceipt(Receipt receipt) async {
    await _box.put(receipt.id, receipt);
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

  // ── Queries ─────────────────────────────────────────────────────────────

  /// Jumlah receipt yang belum disinkronkan
  static int get pendingCount =>
      _box.values.where((r) => !r.isSynced).length;

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
}
