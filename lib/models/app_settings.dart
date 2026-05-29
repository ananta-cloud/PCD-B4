/// AppSettings model untuk menyimpan preferensi user di Hive
class AppSettings {
  final String id;
  bool isDarkMode;
  bool enableNotifications;
  bool enableAutoSync;
  String language; // 'en', 'id', dll
  double confidenceThreshold; // 0.0 - 1.0
  int maxReceiptsLocal; // -1 = unlimited
  DateTime createdAt;
  DateTime updatedAt;

  AppSettings({
    required this.id,
    this.isDarkMode = true,
    this.enableNotifications = true,
    this.enableAutoSync = true,
    this.language = 'id',
    this.confidenceThreshold = 0.8,
    this.maxReceiptsLocal = -1,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory untuk membuat default settings
  factory AppSettings.defaultSettings() {
    final now = DateTime.now();
    return AppSettings(
      id: 'app_settings',
      isDarkMode: true,
      enableNotifications: true,
      enableAutoSync: true,
      language: 'id',
      confidenceThreshold: 0.8,
      maxReceiptsLocal: -1,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Copy with method
  AppSettings copyWith({
    String? id,
    bool? isDarkMode,
    bool? enableNotifications,
    bool? enableAutoSync,
    String? language,
    double? confidenceThreshold,
    int? maxReceiptsLocal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      enableAutoSync: enableAutoSync ?? this.enableAutoSync,
      language: language ?? this.language,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      maxReceiptsLocal: maxReceiptsLocal ?? this.maxReceiptsLocal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'AppSettings('
      'isDarkMode: $isDarkMode, '
      'enableNotifications: $enableNotifications, '
      'language: $language)';
}
