import '../models/receipt.dart';
import '../models/user.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/settings_repository.dart';

/// Demo Controller untuk menunjukkan penggunaan Hive dalam aplikasi
///
/// Ini adalah contoh bagaimana mengintegrasikan Hive repositories
/// dengan business logic controller
class HiveDemoController {
  // ── Repositories ────────────────────────────────────────────────────────
  final ReceiptRepository receiptRepo = ReceiptRepository();
  final UserRepository userRepo = UserRepository();

  // ── Callback untuk update UI ────────────────────────────────────────────
  Function? onDataChanged;
  Function? onError;

  // ════════════════════════════════════════════════════════════════════════
  // DEMO: Receipt Management
  // ════════════════════════════════════════════════════════════════════════

  /// Demo: Simpan receipt baru
  Future<void> demoAddReceipt() async {
    try {
      final receipt = Receipt(
        id: 'demo_receipt_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'demo_user_001',
        totalAmount: 125000.0,
        confidenceScore: 0.92,
        scannedAt: DateTime.now(),
        isSynced: false,
        imagePath: '/path/to/image.jpg',
      );

      await ReceiptRepository.addReceipt(receipt);
      print('✓ Receipt ditambahkan: ${receipt.id}');
      onDataChanged?.call();
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Ambil semua receipts dan tampilkan
  void demoGetAllReceipts() {
    try {
      final receipts = ReceiptRepository.getAll();
      print('\n╔════════════════════════════════════════╗');
      print('║       ALL RECEIPTS (${receipts.length})          ║');
      print('╚════════════════════════════════════════╝');

      for (int i = 0; i < receipts.length && i < 5; i++) {
        final r = receipts[i];
        print(
          '   Synced: ${r.isSynced ? '✓' : '✗'} | Confidence: ${r.confidencePercent}',
        );
      }

      if (receipts.length > 5) {
        print('... dan ${receipts.length - 5} lainnya');
      }
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Filter receipts
  void demoFilterReceipts() {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║        FILTER RECEIPTS DEMO            ║');
      print('╚════════════════════════════════════════╝');

      // Filter high amount
      final highAmount = ReceiptRepository.filterBy(minAmount: 100000);
      print('Receipts > Rp 100.000: ${highAmount.length}');

      // Filter pending
      final pending = ReceiptRepository.getPending();
      print('Receipts pending sync: ${pending.length}');

      // Filter high confidence
      final highConfidence = ReceiptRepository.getHighConfidence(0.85);
      print('Receipts with confidence >= 85%: ${highConfidence.length}');
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Statistik receipts
  void demoReceiptStats() {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║      RECEIPT STATISTICS                ║');
      print('╚════════════════════════════════════════╝');

      final stats = ReceiptRepository.getStatistics();
      print('Total receipts: ${stats['total_scanned']}');
      print(
        'Total spending: Rp ${(stats['total_spending'] as double).toStringAsFixed(0)}',
      );
      print(
        'Average per receipt: Rp ${(stats['average_amount'] as double).toStringAsFixed(0)}',
      );
      print('Pending sync: ${stats['pending_count']}');
      print(
        'Sync progress: ${((stats['sync_progress'] as double) * 100).toStringAsFixed(1)}%',
      );
      print(
        'Avg confidence: ${((stats['average_confidence'] as double) * 100).toStringAsFixed(1)}%',
      );

      // Highest and lowest
      final highest = ReceiptRepository.getHighestAmountReceipt();
      final lowest = ReceiptRepository.getLowestAmountReceipt();

    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // DEMO: User Management
  // ════════════════════════════════════════════════════════════════════════

  /// Demo: Create user dan login
  Future<void> demoUserLogin() async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║        USER LOGIN DEMO                 ║');
      print('╚════════════════════════════════════════╝');

      // Create user
      final user = User(
        id: 'demo_user_${DateTime.now().millisecondsSinceEpoch}',
        email: 'demo@example.com',
        name: 'Demo User',
        createdAt: DateTime.now(),
        isLoggedIn: true,
      );

      await userRepo.addUser(user);
      print('✓ User created: ${user.name}');
      print('  Email: ${user.email}');
      print('  ID: ${user.id}');

      // Get current user
      final current = userRepo.getCurrentLoggedInUser();
      if (current != null) {
        print('✓ Current logged in user: ${current.name}');
      }
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Update login status
  Future<void> demoUpdateLoginStatus(String userId, bool isLoggedIn) async {
    try {
      await userRepo.updateLoginStatus(userId, isLoggedIn);
      print('✓ Login status updated: $isLoggedIn');
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: User statistics
  void demoUserStats() {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║       USER STATISTICS                  ║');
      print('╚════════════════════════════════════════╝');

      final stats = userRepo.getUserStats();
      print('Total users: ${stats['total_users']}');
      print('Logged in: ${stats['logged_in_users']}');
      print('With photo: ${stats['users_with_photo']}');

      // Get all users
      final allUsers = userRepo.getAllUsers();
      for (final user in allUsers.take(3)) {
        print('\n- ${user.name}');
        print('  Email: ${user.email}');
        print('  Status: ${user.isLoggedIn ? 'Online' : 'Offline'}');
      }
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // DEMO: Settings Management
  // ════════════════════════════════════════════════════════════════════════

  /// Demo: Get current settings
  void demoGetSettings() {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║       CURRENT SETTINGS                 ║');
      print('╚════════════════════════════════════════╝');

      print('Dark mode: ${SettingsRepository.isDarkMode() ? '✓' : '✗'}');
      print(
        'Notifications: ${SettingsRepository.isNotificationsEnabled() ? '✓' : '✗'}',
      );
      print('Auto sync: ${SettingsRepository.isAutoSyncEnabled() ? '✓' : '✗'}');
      print('Language: ${SettingsRepository.getLanguage()}');
      print(
        'Confidence threshold: ${(SettingsRepository.getConfidenceThreshold() * 100).toStringAsFixed(0)}%',
      );
      print(
        'Max receipts local: ${SettingsRepository.getMaxReceiptsLocal() == -1 ? 'Unlimited' : SettingsRepository.getMaxReceiptsLocal()}',
      );
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Update settings
  Future<void> demoUpdateSettings() async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║       UPDATE SETTINGS DEMO             ║');
      print('╚════════════════════════════════════════╝');

      await SettingsRepository.setDarkMode(false);
      print('✓ Dark mode disabled');

      await SettingsRepository.setLanguage('en');
      print('✓ Language changed to English');

      await SettingsRepository.setConfidenceThreshold(0.9);
      print('✓ Confidence threshold set to 90%');

      demoGetSettings();
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // DEMO: Complex Scenarios
  // ════════════════════════════════════════════════════════════════════════

  /// Demo: Generate sample data
  Future<void> demoGenerateSampleData() async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║    GENERATE SAMPLE DATA DEMO           ║');
      print('╚════════════════════════════════════════╝');

      final merchants = [
        'Alfamart',
        'Indomaret',
        'Supermarket',
        'Restaurant',
        'Gas Station',
      ];
      final now = DateTime.now();

      // Generate 10 receipts
      for (int i = 0; i < 10; i++) {
        final receipt = Receipt(
          id: 'sample_receipt_$i',
          userId: 'demo_user_001',
          totalAmount: 50000 + (i * 25000).toDouble(),
          confidenceScore: 0.75 + (i * 0.02),
          scannedAt: now.subtract(Duration(days: i)),
          isSynced: i % 2 == 0,
          imagePath: '/path/to/image_$i.jpg',
        );
        await ReceiptRepository.addReceipt(receipt);
      }

      print('✓ Generated 10 sample receipts');
      demoReceiptStats();
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Sync pending receipts
  Future<void> demoSyncPending() async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║    SYNC PENDING RECEIPTS               ║');
      print('╚════════════════════════════════════════╝');

      final pending = ReceiptRepository.getPending();
      print('Found ${pending.length} pending receipts');

      // Mark all as synced
      await ReceiptRepository.markAllAsSynced();
      print('✓ All marked as synced');

      // Show updated stats
      final stats = ReceiptRepository.getStatistics();
      print(
        'Sync progress: ${((stats['sync_progress'] as double) * 100).toStringAsFixed(1)}%',
      );
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  /// Demo: Cleanup (careful!)
  Future<void> demoCleanup() async {
    try {
      print('\n╔════════════════════════════════════════╗');
      print('║    CLEANUP DEMO (DELETE ALL DATA)      ║');
      print('╚════════════════════════════════════════╝');

      // You can uncomment if you really want to test cleanup
      // await HiveService.clearAllBoxes();
      // print('✓ All data cleared');

      print('⚠️  Cleanup disabled. Uncomment in code to test.');
    } catch (e) {
      print('✗ Error: $e');
      onError?.call(e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // DEMO: Run all demos
  // ════════════════════════════════════════════════════════════════════════

  /// Jalankan semua demo
  Future<void> runAllDemos() async {
    print('╔════════════════════════════════════════╗');
    print('║      HIVE IMPLEMENTATION DEMO          ║');
    print('║      Menjalankan semua demo...          ║');
    print('╚════════════════════════════════════════╝\n');

    try {
      // Receipts demos
      await demoAddReceipt();
      demoGetAllReceipts();
      demoFilterReceipts();
      demoReceiptStats();

      // Users demos
      await demoUserLogin();
      demoUserStats();

      // Settings demos
      demoGetSettings();
      await demoUpdateSettings();

      // Complex scenarios
      await demoGenerateSampleData();
      await demoSyncPending();

      print('\n✅ Semua demo selesai!');
    } catch (e) {
      print('\n❌ Error running demos: $e');
      onError?.call(e);
    }
  }
}
