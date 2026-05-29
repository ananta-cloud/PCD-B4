import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';

/// Controller untuk Detail Screen - menangani business logic
class DetailController {
  final Receipt receipt;

  DetailController({required this.receipt});

  /// Hapus receipt dari repository
  Future<void> deleteReceipt() async {
    try {
      await ReceiptRepository.deleteReceipt(receipt.id);
      print('✓ Receipt ${receipt.id} deleted successfully');
    } catch (e) {
      print('✗ Error deleting receipt: $e');
      rethrow;
    }
  }

  /// Get formatted display data
  String get displayMerchant => receipt.merchantName ?? 'Unknown Merchant';
  String get displayAmount => receipt.formattedAmount;
  String get displayDate => receipt.formattedDate;
  String get displayTime => receipt.formattedTime;
  String get displayConfidence => receipt.confidencePercent;
  String get displayId => receipt.id;
  bool get isSynced => receipt.isSynced;

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}
