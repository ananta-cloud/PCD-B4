import '../models/receipt.dart';
import '../models/user.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/mongo_service.dart';
import 'hive_service.dart';

/// Utility class untuk operasi Hive yang sering digunakan
///
/// Menyediakan shortcut methods untuk operasi umum di aplikasi
/// Gunakan untuk simplify kode controller/screen
class HiveUtils {
  // ── Receipt Utils ───────────────────────────────────────────────────────

  /// Simpan receipt dan return ID
  static Future<String> saveReceipt({
    required String userId,
    required double totalAmount,
    required double confidenceScore,
    required DateTime scannedAt,
    String? merchantName,
    String? imagePath,
  }) async {
    final id = 'receipt_${DateTime.now().millisecondsSinceEpoch}';
    final receipt = Receipt(
      id: id,
      userId: userId,
      totalAmount: totalAmount,
      confidenceScore: confidenceScore,
      scannedAt: scannedAt,
      isSynced: false,
      imagePath: imagePath,
    );
    await ReceiptRepository.addReceipt(receipt);
    return id;
  }

  /// Get receipts dari bulan ini
  static List<Receipt> getThisMonthReceipts() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return ReceiptRepository.getByDateRange(startOfMonth, endOfMonth);
  }

  /// Get receipts dari minggu ini
  static List<Receipt> getThisWeekReceipts() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return ReceiptRepository.getByDateRange(startOfWeek, endOfWeek);
  }

  /// Get total spending bulan ini
  static double getThisMonthTotal() {
    final receipts = getThisMonthReceipts();
    return receipts.fold(0.0, (sum, r) => sum + r.totalAmount);
  }

  /// Get total spending minggu ini
  static double getThisWeekTotal() {
    final receipts = getThisWeekReceipts();
    return receipts.fold(0.0, (sum, r) => sum + r.totalAmount);
  }

  /// Get average daily spending bulan ini
  static double getThisMonthAverageDaily() {
    final total = getThisMonthTotal();
    final now = DateTime.now();
    return total / now.day;
  }

  /// Format spending dengan currency
  static String formatCurrency(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $formatted';
  }

  // ── User Utils ──────────────────────────────────────────────────────────

  /// Login user dan return user object
  static Future<User> loginUser({
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    final userRepo = UserRepository();

    // Check if user exists
    var user = userRepo.getUserByEmail(email);

    if (user == null) {
      // Create new user
      user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        name: name,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
        isLoggedIn: true,
      );
    } else {
      // Update existing user
      user = user.copyWith(isLoggedIn: true, lastLoginAt: DateTime.now());
    }

    await userRepo.addUser(user);
    return user;
  }

  /// Logout current user
  static Future<void> logoutCurrentUser() async {
    final userRepo = UserRepository();
    await userRepo.logoutAllUsers();
  }

  /// Get current logged in user
  static User? getCurrentUser() {
    final userRepo = UserRepository();
    return userRepo.getCurrentLoggedInUser();
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return getCurrentUser() != null;
  }

  // ── Settings Utils ──────────────────────────────────────────────────────

  /// Toggle dark mode
  static Future<void> toggleDarkMode() async {
    final isDark = SettingsRepository.isDarkMode();
    await SettingsRepository.setDarkMode(!isDark);
  }

  /// Toggle auto sync
  static Future<void> toggleAutoSync() async {
    final enabled = SettingsRepository.isAutoSyncEnabled();
    await SettingsRepository.setAutoSyncEnabled(!enabled);
  }

  /// Toggle notifications
  static Future<void> toggleNotifications() async {
    final enabled = SettingsRepository.isNotificationsEnabled();
    await SettingsRepository.setNotificationsEnabled(!enabled);
  }

  /// Set confidence threshold berdasarkan preset
  /// 'low' = 0.7, 'medium' = 0.8, 'high' = 0.9
  static Future<void> setConfidencePreset(String preset) async {
    final threshold = switch (preset) {
      'low' => 0.7,
      'high' => 0.9,
      _ => 0.8, // medium
    };
    await SettingsRepository.setConfidenceThreshold(threshold);
  }

  /// Get confidence preset name dari current threshold
  static String getConfidencePresetName() {
    final threshold = SettingsRepository.getConfidenceThreshold();
    if (threshold < 0.75) return 'Low';
    if (threshold < 0.85) return 'Medium';
    return 'High';
  }

  // ── Database Utils ──────────────────────────────────────────────────────

  /// Sync all pending receipts ke MongoDB (call this when internet is available)
  static Future<int> syncPending() async {
    final pending = ReceiptRepository.getPending();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    final syncedIds = <String>[];

    for (final receipt in pending) {
      try {
        final success = await MongoService.insertReceipt(
          receipt.totalAmount,
        );
        if (success) {
          syncedIds.add(receipt.id);
          syncedCount++;
        }
      } catch (_) {
        // Lewati receipt yang gagal, coba lagi nanti
      }
    }

    if (syncedIds.isNotEmpty) {
      await ReceiptRepository.markAsSynced(syncedIds);
    }

    return syncedCount;
  }

  /// Get database health status
  static Map<String, dynamic> getDatabaseStatus() {
    return {
      'is_initialized': HiveService.isInitialized,
      'receipts': ReceiptRepository.totalScanned,
      'pending_sync': ReceiptRepository.pendingCount,
      'sync_progress': ReceiptRepository.syncProgress,
      'total_spending': ReceiptRepository.totalSpending,
      'users': UserRepository().getTotalUsers(),
      'db_stats': HiveService.getDbStats(),
    };
  }

  /// Clear all local data (use with caution!)
  static Future<void> clearAllData() async {
    await HiveService.clearAllBoxes();
  }

  /// Export all data as JSON
  static Map<String, dynamic> exportData() {
    return HiveService.backupAllData();
  }

  // ── Quick Dashboard Data ────────────────────────────────────────────────

  /// Get quick stats untuk dashboard
  static Map<String, dynamic> getDashboardStats() {
    final receipts = ReceiptRepository.getStatistics();
    final thisMonth = getThisMonthTotal();
    final thisWeek = getThisWeekTotal();
    final synced =
        ReceiptRepository.totalScanned - ReceiptRepository.pendingCount;

    return {
      'total_spending': receipts['total_spending'],
      'this_month': thisMonth,
      'this_week': thisWeek,
      'average_per_receipt': receipts['average_amount'],
      'total_receipts': receipts['total_scanned'],
      'synced_receipts': synced,
      'pending_receipts': receipts['pending_count'],
      'sync_progress_percent': (receipts['sync_progress'] as double) * 100,
      'average_confidence_percent':
          (receipts['average_confidence'] as double) * 100,
    };
  }


  // ── Formatting Utils ────────────────────────────────────────────────────

  /// Format receipt untuk display
  static String formatReceiptDisplay(Receipt receipt) {
    return
        '${receipt.formattedAmount} • ${receipt.formattedDate}\n'
        'Confidence: ${receipt.confidencePercent}';
  }

  /// Format percentage
  static String formatPercent(double value, {int decimals = 1}) {
    return '${(value * 100).toStringAsFixed(decimals)}%';
  }

  /// Get confidence color/status
  static String getConfidenceStatus(double confidence) {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.8) return 'Good';
    if (confidence >= 0.7) return 'Fair';
    return 'Low';
  }

  // ── Validation Utils ────────────────────────────────────────────────────

  /// Validate receipt data
  static ({bool isValid, List<String> errors}) validateReceipt({
    required double totalAmount,
    required double confidenceScore,
    String? merchantName,
  }) {
    final errors = <String>[];

    if (totalAmount <= 0) {
      errors.add('Total amount harus lebih dari 0');
    }

    if (confidenceScore < 0 || confidenceScore > 1) {
      errors.add('Confidence score harus antara 0 dan 1');
    }

    if ((merchantName ?? '').isEmpty) {
      errors.add('Merchant name tidak boleh kosong');
    }

    return (isValid: errors.isEmpty, errors: errors);
  }

  /// Validate user data
  static ({bool isValid, List<String> errors}) validateUser({
    required String email,
    required String name,
  }) {
    final errors = <String>[];

    if (!email.contains('@')) {
      errors.add('Email format tidak valid');
    }

    if (name.isEmpty || name.length < 2) {
      errors.add('Nama harus minimal 2 karakter');
    }

    return (isValid: errors.isEmpty, errors: errors);
  }

  // ── Repair Utils ────────────────────────────────────────────────────────

  /// Fix inconsistent data (e.g., sync receipts marked as unsync)
  static Future<void> fixInconsistencies() async {
    final receipts = ReceiptRepository.getAll();

    for (final receipt in receipts) {
      // Fix any invalid data
      if (receipt.totalAmount < 0) {
        await ReceiptRepository.updateReceipt(receipt.copyWith(totalAmount: 0));
      }

      if (receipt.confidenceScore < 0 || receipt.confidenceScore > 1) {
        await ReceiptRepository.updateReceipt(
          receipt.copyWith(confidenceScore: 0.5),
        );
      }
    }
  }

  /// Print full database dump (debug only!)
  static void printFullDump() {
    print('\n╔════════════════════════════════════════╗');
    print('║        FULL DATABASE DUMP              ║');
    print('╚════════════════════════════════════════╝');

    print('\n[RECEIPTS]');
    final receipts = ReceiptRepository.getAll();
    if (receipts.length > 5) print('... and ${receipts.length - 5} more');

    print('\n[USERS]');
    final userRepo = UserRepository();
    final users = userRepo.getAllUsers();
    for (final u in users.take(3)) {
      print('- ${u.id}: ${u.name} (${u.email})');
    }

    print('\n[SETTINGS]');
    SettingsRepository.printSettings();

    print('\n[STATS]');
    HiveService.printDebugInfo();
  }
}
