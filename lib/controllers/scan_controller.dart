import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import '../models/receipt.dart';
import '../repositories/mock_receipt_repository.dart';

/// Fase proses scan
enum ScanPhase { idle, processing, result }

/// Jenis tampilan gambar
enum ImageViewType { original, grayscale, threshold }

/// Controller untuk ScanScreen — mengelola state dan logika pipeline scan.
///
/// Pipeline: Pick Image → Grayscale → Threshold → OCR → Result
class ScanController extends ChangeNotifier {
  ScanPhase _phase = ScanPhase.idle;
  ImageViewType _imageView = ImageViewType.original;
  String _processingStep = '';

  File? _originalFile;
  File? _grayscaleFile;
  File? _thresholdFile;
  ParsedReceipt? _ocrResult;
  bool _isSaving = false;

  // ── Getters ─────────────────────────────────────────────────────────────
  ScanPhase get phase => _phase;
  ImageViewType get imageView => _imageView;
  String get processingStep => _processingStep;

  File? get originalFile => _originalFile;
  File? get grayscaleFile => _grayscaleFile;
  File? get thresholdFile => _thresholdFile;
  ParsedReceipt? get ocrResult => _ocrResult;
  bool get isSaving => _isSaving;

  /// True jika confidence > 75% (threshold dari PRD)
  bool get isDetected =>
      _phase == ScanPhase.result && (_ocrResult?.confidence ?? 0) > 0.75;

  /// True jika OCR berhasil menemukan item belanja
  bool get hasItems => _ocrResult != null && _ocrResult!.items.isNotEmpty;

  /// File gambar yang sedang ditampilkan sesuai tab aktif
  File? get displayedImage => switch (_imageView) {
    ImageViewType.original => _originalFile,
    ImageViewType.grayscale => _grayscaleFile,
    ImageViewType.threshold => _thresholdFile,
  };

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Ganti tab tampilan gambar (Original / Grayscale / Threshold)
  void setImageView(ImageViewType view) {
    _imageView = view;
    notifyListeners();
  }

  /// Jalankan pipeline pemrosesan citra + OCR.
  /// Throws jika ada error — view bertanggung jawab menangkap dan menampilkan pesan.
  Future<void> processImage(File file) async {
    _phase = ScanPhase.processing;
    _originalFile = file;
    _processingStep = 'Konversi grayscale...';
    notifyListeners();

    try {
      // Step 1: Grayscale (PCD — ITU-R BT.601)
      final grayFile = await ImageProcessingService.convertToGrayscale(file);
      _grayscaleFile = grayFile;
      _processingStep = 'Binary thresholding...';
      notifyListeners();

      // Step 2: Threshold (PCD — Binarisasi)
      final threshFile = await ImageProcessingService.applyThreshold(grayFile);
      _thresholdFile = threshFile;
      _processingStep = 'Menjalankan OCR...';
      notifyListeners();

      // Step 3: OCR (Google ML Kit)
      final result = await OcrService.processImage(file);
      _ocrResult = result;
      _phase = ScanPhase.result;
      _imageView = ImageViewType.original;
      notifyListeners();
    } catch (e) {
      _phase = ScanPhase.idle;
      notifyListeners();
      rethrow;
    }
  }

  /// Simpan hasil scan ke repository. Returns true jika berhasil.
  Future<bool> saveReceipt() async {
    if (_isSaving || _ocrResult == null) return false;

    _isSaving = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    MockReceiptRepository.addReceipt(Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'user_001',
      totalAmount: _ocrResult!.total,
      confidenceScore: _ocrResult!.confidence,
      scannedAt: DateTime.now(),
      merchantName: 'Scanned Receipt',
    ));

    _isSaving = false;
    notifyListeners();
    return true;
  }

  /// Reset semua state ke idle.
  void resetScan() {
    _phase = ScanPhase.idle;
    _originalFile = null;
    _grayscaleFile = null;
    _thresholdFile = null;
    _ocrResult = null;
    _imageView = ImageViewType.original;
    notifyListeners();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Format angka ke format Rupiah: 142500 → "Rp 142.500"
  String formatAmount(double amount) {
    final f = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }
}
