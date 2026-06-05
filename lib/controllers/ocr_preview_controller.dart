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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<Receipt?> saveReceipt(File croppedFile, ParsedReceipt parsedReceipt) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

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
        merchantName: 'Scanned Receipt',
        imagePath: croppedFile.path,
      );

      // Simpan ke Hive
      await ReceiptRepository.addReceipt(receipt);

      // Auto-sync ke MongoDB
      try {
        final synced = await MongoService.insertReceipt(
          receipt.merchantName ?? 'Scanned Receipt',
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
      notifyListeners();
      return receipt;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan: $e';
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }
}
