/// Receipt model — mirrors the Receipts DB schema from PRD §6
class Receipt {
  final String id;
  final String userId;
  final double totalAmount;
  final double confidenceScore;
  final DateTime scannedAt;
  bool isSynced;
  final String? merchantName;

  Receipt({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.confidenceScore,
    required this.scannedAt,
    this.isSynced = false,
    this.merchantName,
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
}
