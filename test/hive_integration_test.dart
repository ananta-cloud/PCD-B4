import 'package:flutter_test/flutter_test.dart';
import 'package:smart_receipt_scanner/models/receipt.dart';
import 'package:smart_receipt_scanner/models/user.dart';
import 'package:smart_receipt_scanner/repositories/receipt_repository.dart';
import 'package:smart_receipt_scanner/repositories/user_repository.dart';
import 'package:smart_receipt_scanner/repositories/settings_repository.dart';
import 'package:smart_receipt_scanner/services/hive_utils.dart';

/// Integration test untuk memverifikasi Hive implementation lengkap
///
/// Test scenarios:
/// 1. Save & retrieve receipts
/// 2. Filter receipts by date
/// 3. Calculate statistics
/// 4. Sync mechanism
/// 5. User management
/// 6. Settings persistence
void main() {
  group('Hive Implementation Integration Tests', () {
    test('Receipt CRUD operations work correctly', () async {
      // CREATE: Buat receipt baru
      final receipt = Receipt(
        id: 'test_receipt_1',
        userId: 'test_user_1',
        totalAmount: 150000,
        confidenceScore: 0.95,
        scannedAt: DateTime.now(),
        isSynced: false,
      );

      await ReceiptRepository.addReceipt(receipt);

      // READ: Ambil receipt yang baru disimpan
      final retrieved = ReceiptRepository.getById('test_receipt_1');
      expect(retrieved, isNotNull);
      expect(retrieved!.totalAmount, equals(150000));

      // UPDATE: Ubah status synced
      final updated = receipt.copyWith(isSynced: true);
      await ReceiptRepository.updateReceipt(updated);
      final retrievedUpdated = ReceiptRepository.getById('test_receipt_1');
      expect(retrievedUpdated!.isSynced, isTrue);

      // DELETE: Hapus receipt
      await ReceiptRepository.deleteReceipt('test_receipt_1');
      final deleted = ReceiptRepository.getById('test_receipt_1');
      expect(deleted, isNull);
    });

    test('Receipt filtering and statistics work correctly', () async {
      // Setup: Simpan beberapa receipts dengan berbagai tanggal
      final now = DateTime.now();
      final receipts = [
        Receipt(
          id: 'r1',
          userId: 'user1',
          totalAmount: 100000,
          confidenceScore: 0.9,
          scannedAt: now,
          isSynced: true,
        ),
        Receipt(
          id: 'r2',
          userId: 'user1',
          totalAmount: 200000,
          confidenceScore: 0.85,
          scannedAt: now.subtract(const Duration(days: 1)),
          isSynced: false,
        ),
        Receipt(
          id: 'r3',
          userId: 'user2',
          totalAmount: 150000,
          confidenceScore: 0.92,
          scannedAt: now.subtract(const Duration(days: 7)),
          isSynced: true,
        ),
      ];

      for (var r in receipts) {
        await ReceiptRepository.addReceipt(r);
      }

      // Test filtering
      final pending = ReceiptRepository.getPending();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('r2'));

      final user1Receipts = ReceiptRepository.getByUserId('user1');
      expect(user1Receipts.length, equals(2));

      // Test statistics
      expect(ReceiptRepository.totalScanned, equals(3));
      expect(ReceiptRepository.totalSpending, equals(450000));
      expect(ReceiptRepository.pendingCount, equals(1));
      expect(ReceiptRepository.averageAmount, closeTo(150000, 0.01));
      expect(ReceiptRepository.syncProgress, closeTo(0.667, 0.01));
    });

    test('User management works correctly', () async {
      final userRepo = UserRepository();

      // CREATE: Tambah user baru
      final user = User(
        id: 'test_user',
        email: 'test@example.com',
        name: 'Test User',
        createdAt: DateTime.now(),
        isLoggedIn: true,
      );

      await userRepo.addUser(user);

      // READ: Ambil user
      final retrieved = userRepo.getUser('test_user');
      expect(retrieved, isNotNull);
      expect(retrieved!.email, equals('test@example.com'));
      expect(retrieved.isLoggedIn, isTrue);

      // Test login status
      expect(userRepo.hasLoggedInUser(), isTrue);

      // UPDATE: Change login status
      final updated = user.copyWith(isLoggedIn: false);
      await userRepo.updateUser(updated);

      final retrievedUpdated = userRepo.getUser('test_user');
      expect(retrievedUpdated!.isLoggedIn, isFalse);
    });

    test('Settings persistence works correctly', () async {
      // TEST: Dapatkan settings (harus ada default)
      final settings = SettingsRepository.getSettings();
      expect(settings, isNotNull);

      // TEST: Set dark mode
      await SettingsRepository.setDarkMode(true);
      expect(SettingsRepository.isDarkMode(), isTrue);

      // TEST: Update language
      await SettingsRepository.setLanguage('id');
      expect(SettingsRepository.getLanguage(), equals('id'));

      // TEST: Set confidence threshold
      await SettingsRepository.setConfidenceThreshold(0.8);
      expect(SettingsRepository.getConfidenceThreshold(), equals(0.8));
    });

    test('Sync mechanism works correctly', () async {
      // Setup: Buat receipt dengan isSynced=false
      final receipt = Receipt(
        id: 'sync_test_r1',
        userId: 'sync_user',
        totalAmount: 50000,
        confidenceScore: 0.88,
        scannedAt: DateTime.now(),
        isSynced: false,
      );

      await ReceiptRepository.addReceipt(receipt);

      // Verify pending count
      expect(ReceiptRepository.pendingCount, greaterThan(0));

      // Run sync
      final syncedCount = await HiveUtils.syncPending();
      expect(syncedCount, greaterThan(0));

      // Verify all marked as synced
      final allReceipts = ReceiptRepository.getAll();
      for (var r in allReceipts) {
        expect(r.isSynced, isTrue);
      }
    });

    test('Date filtering works correctly', () async {
      // Setup: Create receipts for different dates
      final today = DateTime.now();
      final receipts = [
        Receipt(
          id: 'date_test_1',
          userId: 'user',
          totalAmount: 100000,
          confidenceScore: 0.9,
          scannedAt: today,
        ),
        Receipt(
          id: 'date_test_2',
          userId: 'user',
          totalAmount: 150000,
          confidenceScore: 0.85,
          scannedAt: today.subtract(const Duration(days: 3)),
        ),
        Receipt(
          id: 'date_test_3',
          userId: 'user',
          totalAmount: 120000,
          confidenceScore: 0.92,
          scannedAt: today.subtract(const Duration(days: 8)),
        ),
      ];

      for (var r in receipts) {
        await ReceiptRepository.addReceipt(r);
      }

      // Test date filtering by date range
      final byDateRange = ReceiptRepository.getByDateRange(
        today.subtract(const Duration(days: 7)),
        today,
      );
      expect(byDateRange.length, greaterThanOrEqualTo(2));
    });

    test('Pagination works correctly', () async {
      // Setup: Create multiple receipts
      final now = DateTime.now();
      for (int i = 0; i < 15; i++) {
        final receipt = Receipt(
          id: 'page_test_$i',
          userId: 'user',
          totalAmount: 100000 + (i * 10000),
          confidenceScore: 0.85 + (i * 0.01),
          scannedAt: now.subtract(Duration(hours: i)),
        );
        await ReceiptRepository.addReceipt(receipt);
      }

      // Test pagination
      final page1 = ReceiptRepository.paginate(0, 5);
      expect(page1.length, equals(5));

      final page2 = ReceiptRepository.paginate(1, 5);
      expect(page2.length, equals(5));

      final page3 = ReceiptRepository.paginate(2, 5);
      expect(page3.length, greaterThan(0));
    });

    tearDown(() async {
      // Cleanup: Hapus semua test data
      await ReceiptRepository.deleteAllReceipts();
      final userRepo = UserRepository();
      await userRepo.deleteAllUsers();
    });
  });
}
