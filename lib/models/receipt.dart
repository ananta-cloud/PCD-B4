/// Receipt model — mirrors the Receipts DB schema from PRD §6
class Receipt {
  final String id;
  final String userId;
  final double totalAmount;
  final double confidenceScore;
  final DateTime scannedAt;
  bool isSynced;
  final String? imagePath;

  Receipt({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.confidenceScore,
    required this.scannedAt,
    this.isSynced = false,
    this.imagePath,
  });

  String get formattedAmount {
    final formatted = totalAmount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return 'Rp $formatted';
  }

  String get formattedTime {
    final h = scannedAt.hour.toString().padLeft(2, '0');
    final m = scannedAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[scannedAt.month - 1]} ${scannedAt.day}, ${scannedAt.year}';
  }

  String get confidencePercent =>
      '${(confidenceScore * 100).toStringAsFixed(0)}%';

  /// Buat copy dengan field yang diubah
  Receipt copyWith({
    String? id,
    String? userId,
    double? totalAmount,
    double? confidenceScore,
    DateTime? scannedAt,
    bool? isSynced,
    String? merchantName,
    String? imagePath,
  }) {
    return Receipt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      totalAmount: totalAmount ?? this.totalAmount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      scannedAt: scannedAt ?? this.scannedAt,
      isSynced: isSynced ?? this.isSynced,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
