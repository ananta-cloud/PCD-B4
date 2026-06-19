import 'package:hive_flutter/hive_flutter.dart';
import '../models/receipt.dart';
import '../models/receipt_adapter.dart';
import '../models/user.dart';
import '../models/user_adapter.dart';
import '../models/app_settings.dart';
import '../models/app_settings_adapter.dart';

/// Service untuk mengelola inisialisasi dan konfigurasi Hive database.
///
/// Responsible untuk:
/// - Initialize Hive Flutter
/// - Register semua TypeAdapter
/// - Buka/setup semua boxes
/// - Cleanup resources
class HiveService {
  // ── Box names (konstanta) ───────────────────────────────────────────────
  static const String receiptsBoxName = 'receipts';
  static const String usersBoxName = 'users';
  static const String settingsBoxName = 'app_settings';

  // ── Private properties ──────────────────────────────────────────────────
  static bool _isInitialized = false;

  /// Cek apakah Hive sudah diinisialisasi
  static bool get isInitialized => _isInitialized;

  // ── Initialization ──────────────────────────────────────────────────────

  /// Inisialisasi Hive dan buka semua boxes
  ///
  /// HARUS dipanggil di main() sebelum runApp()
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await HiveService.initialize();
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize Hive Flutter
    await Hive.initFlutter();

    // 2. Register semua TypeAdapter
    Hive.registerAdapter(ReceiptAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    // 3. Buka boxes dengan try-catch untuk recovery otomatis jika data korup (RangeError)
    await _safeOpenBox<Receipt>(receiptsBoxName);
    await _safeOpenBox<User>(usersBoxName);
    await _safeOpenBox<AppSettings>(settingsBoxName);
    await _safeOpenBox<dynamic>('session'); // Tambahkan juga box session

    // 4. Initialize default settings
    final settingsBox = Hive.box<AppSettings>(settingsBoxName);
    if (settingsBox.isEmpty) {
      await settingsBox.put('app_settings', AppSettings.defaultSettings());
    }

    _isInitialized = true;
    print('✅ Hive Service initialized successfully');
  }

  /// Helper method to safely open a box, handling corrupted data
  static Future<void> _safeOpenBox<T>(String boxName) async {
    try {
      await Hive.openBox<T>(boxName);
      print('✓ Box $boxName dibuka');
    } catch (e) {
      print('⚠️ Box $boxName korup/gagal: $e. Mencoba recovery dengan menghapus data...');
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox<T>(boxName);
        print('✓ Box $boxName berhasil direcover dan dibuka kembali');
      } catch (e2) {
        print('❌ Box $boxName gagal direcover: $e2');
        rethrow;
      }
    }
  }

  // ── Box accessors (convenience methods) ──────────────────────────────────

  /// Dapatkan receipts box
  static Box<Receipt> get receiptsBox {
    _checkInitialized();
    return Hive.box<Receipt>(receiptsBoxName);
  }

  /// Dapatkan users box
  static Box<User> get usersBox {
    _checkInitialized();
    return Hive.box<User>(usersBoxName);
  }

  /// Dapatkan app settings box
  static Box<AppSettings> get settingsBox {
    _checkInitialized();
    return Hive.box<AppSettings>(settingsBoxName);
  }

  // ── Utility methods ─────────────────────────────────────────────────────

  /// Cek apakah Hive sudah diinisialisasi
  static void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'Hive Service belum diinisialisasi. '
        'Panggil HiveService.initialize() di main() terlebih dahulu.',
      );
    }
  }

  /// Clear semua data dari semua boxes
  ///
  /// ⚠️ HATI-HATI: Operasi ini tidak bisa di-undo!
  static Future<void> clearAllBoxes() async {
    _checkInitialized();
    try {
      await receiptsBox.clear();
      await usersBox.clear();
      await settingsBox.clear();
      print('✓ Semua boxes telah dikosongkan');
    } catch (e) {
      print('❌ Error saat clear boxes: $e');
      rethrow;
    }
  }

  /// Delete specific box
  static Future<void> deleteBox(String boxName) async {
    try {
      await Hive.deleteBoxFromDisk(boxName);
      print('✓ Box $boxName telah dihapus');
    } catch (e) {
      print('❌ Error saat delete box: $e');
      rethrow;
    }
  }

  /// Close semua boxes
  ///
  /// Biasanya dipanggil saat app shutdown
  static Future<void> closeAllBoxes() async {
    try {
      await Hive.close();
      _isInitialized = false;
      print('✓ Semua Hive boxes ditutup');
    } catch (e) {
      print('❌ Error saat close boxes: $e');
      rethrow;
    }
  }

  /// Dapatkan statistik database
  static Map<String, dynamic> getDbStats() {
    _checkInitialized();
    return {
      'receipts_count': receiptsBox.length,
      'users_count': usersBox.length,
      'settings_count': settingsBox.length,
      'receipts_size_bytes': _estimateBoxSize(receiptsBox),
      'users_size_bytes': _estimateBoxSize(usersBox),
      'settings_size_bytes': _estimateBoxSize(settingsBox),
    };
  }

  /// Backup semua data ke Map
  static Map<String, dynamic> backupAllData() {
    _checkInitialized();
    return {
      'receipts': {for (var r in receiptsBox.values) r.id: r},
      'users': {for (var u in usersBox.values) u.id: u},
      'settings': {for (var s in settingsBox.values) s.id: s},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Estimate ukuran box (rough estimate)
  static int _estimateBoxSize<T>(Box<T> box) {
    if (box.isEmpty) return 0;
    // Simple estimate: average size × count
    // Ini bukan akurat, hanya rough estimate
    try {
      return (box.length * 1024); // assume ~1KB per item
    } catch (e) {
      return 0;
    }
  }

  // ── Debug helpers ───────────────────────────────────────────────────────

  /// Print debug info tentang Hive
  static void printDebugInfo() {
    print('╔════════════════════════════════════════╗');
    print('║       HIVE SERVICE DEBUG INFO          ║');
    print('╚════════════════════════════════════════╝');
    print('Initialized: $_isInitialized');

    if (!_isInitialized) return;

    final stats = getDbStats();
    print('\n📊 Database Stats:');
    print('  • Receipts: ${stats['receipts_count']}');
    print('  • Users: ${stats['users_count']}');
    print('  • Settings: ${stats['settings_count']}');
    print(
      '  • Total size: ~${(stats['receipts_size_bytes'] as int) + (stats['users_size_bytes'] as int) + (stats['settings_size_bytes'] as int)} bytes',
    );

    print('\n📦 Current Settings:');
    try {
      final settings = settingsBox.get('app_settings');
      if (settings != null) {
        print('  • Dark mode: ${settings.isDarkMode}');
        print('  • Language: ${settings.language}');
        print('  • Auto sync: ${settings.enableAutoSync}');
        print('  • Confidence threshold: ${settings.confidenceThreshold}');
      }
    } catch (e) {
      print('  • Error reading settings: $e');
    }
  }
}
