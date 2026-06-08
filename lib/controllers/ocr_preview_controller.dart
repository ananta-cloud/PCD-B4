import 'dart:io';
import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../repositories/receipt_repository.dart';
import '../services/mongo_service.dart';
import '../services/ocr_service.dart';

class OcrPreviewController extends ChangeNotifier {
  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safe notifyListeners — tidak crash jika sudah disposed
  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _safeNotify();
  }

  Future<Receipt?> saveReceipt(File croppedFile, ParsedReceipt parsedReceipt) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final receiptId = 'receipt_${DateTime.now().millisecondsSinceEpoch}';
      final userId = MongoService.currentUserId ?? 'unknown_user';

      final receipt = Receipt(
        id: receiptId,
        userId: userId,
        totalAmount: parsedReceipt.total,
        confidenceScore: parsedReceipt.confidence,
        scannedAt: DateTime.now(),
        isSynced: false,
        imagePath: croppedFile.path,
      );

      // Simpan ke Hive
      await ReceiptRepository.addReceipt(receipt);

      // Auto-sync ke MongoDB
      try {
        final synced = await MongoService.insertReceipt(
          receipt.totalAmount,
        );
        if (synced) {
          await ReceiptRepository.markAsSynced([receiptId]);
          receipt.isSynced = true; // Update local instance just in case
        }
      } catch (_) {
        // Tetap lanjut meski sync gagal
      }

      _isSaving = false;
      _safeNotify();
      return receipt;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan: $e';
      _isSaving = false;
      _safeNotify();
      return null;
    }
  }
}
