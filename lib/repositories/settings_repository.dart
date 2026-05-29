import 'package:hive/hive.dart';
import '../models/app_settings.dart';
import '../services/hive_service.dart';

/// Repository untuk akses app settings menggunakan Hive local database.
class SettingsRepository {
  static const String _settingsKey = 'app_settings';

  /// Dapatkan Hive box
  static Box<AppSettings> get _box => HiveService.settingsBox;

  // ── Get/Update Settings ────────────────────────────────────────────────

  /// Dapatkan app settings saat ini
  /// Jika belum ada, return default settings
  static AppSettings getSettings() {
    try {
      final settings = _box.get(_settingsKey);
      return settings ?? AppSettings.defaultSettings();
    } catch (e) {
      print('Error getting settings: $e');
      return AppSettings.defaultSettings();
    }
  }

  /// Simpan/update app settings
  static Future<void> updateSettings(AppSettings settings) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      await _box.put(_settingsKey, updatedSettings);
    } catch (e) {
      print('Error updating settings: $e');
      rethrow;
    }
  }

  // ── Individual setting updates ────────────────────────────────────────

  /// Update dark mode
  static Future<void> setDarkMode(bool isDark) async {
    final current = getSettings();
    await updateSettings(current.copyWith(isDarkMode: isDark));
  }

  /// Update notifications
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final current = getSettings();
    await updateSettings(current.copyWith(enableNotifications: enabled));
  }

  /// Update auto sync
  static Future<void> setAutoSyncEnabled(bool enabled) async {
    final current = getSettings();
    await updateSettings(current.copyWith(enableAutoSync: enabled));
  }

  /// Update language
  static Future<void> setLanguage(String language) async {
    final current = getSettings();
    await updateSettings(current.copyWith(language: language));
  }

  /// Update confidence threshold (0.0 - 1.0)
  static Future<void> setConfidenceThreshold(double threshold) async {
    if (threshold < 0.0 || threshold > 1.0) {
      throw ArgumentError('Threshold harus antara 0.0 dan 1.0');
    }
    final current = getSettings();
    await updateSettings(current.copyWith(confidenceThreshold: threshold));
  }

  /// Update max receipts untuk local storage
  static Future<void> setMaxReceiptsLocal(int max) async {
    final current = getSettings();
    await updateSettings(current.copyWith(maxReceiptsLocal: max));
  }

  /// Reset settings ke default
  static Future<void> resetToDefault() async {
    final defaultSettings = AppSettings.defaultSettings();
    await updateSettings(defaultSettings);
  }

  // ── Individual getters ────────────────────────────────────────────────

  /// Dapatkan dark mode setting
  static bool isDarkMode() => getSettings().isDarkMode;

  /// Dapatkan notifications setting
  static bool isNotificationsEnabled() => getSettings().enableNotifications;

  /// Dapatkan auto sync setting
  static bool isAutoSyncEnabled() => getSettings().enableAutoSync;

  /// Dapatkan language setting
  static String getLanguage() => getSettings().language;

  /// Dapatkan confidence threshold
  static double getConfidenceThreshold() => getSettings().confidenceThreshold;

  /// Dapatkan max receipts local
  static int getMaxReceiptsLocal() => getSettings().maxReceiptsLocal;

  // ── Utility methods ────────────────────────────────────────────────────

  /// Print debug info tentang settings
  static void printSettings() {
    final settings = getSettings();
    print('╔════════════════════════════════════════╗');
    print('║       APP SETTINGS DEBUG              ║');
    print('╚════════════════════════════════════════╝');
    print('Dark mode: ${settings.isDarkMode}');
    print('Notifications: ${settings.enableNotifications}');
    print('Auto sync: ${settings.enableAutoSync}');
    print('Language: ${settings.language}');
    print('Confidence threshold: ${settings.confidenceThreshold}');
    print('Max receipts local: ${settings.maxReceiptsLocal}');
    print('Created at: ${settings.createdAt}');
    print('Updated at: ${settings.updatedAt}');
  }
}
