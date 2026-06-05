import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A single line item on a receipt
class ReceiptItem {
  final String name;
  final int qty;
  final double unitPrice;
  final double totalPrice;

  ReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.totalPrice,
  });
}

/// Structured receipt data parsed from OCR text
class ParsedReceipt {
  final List<ReceiptItem> items;
  final double subtotal;
  final double total;
  final double? cash;
  final double? change;
  final String rawText;
  final String formattedItems; // display: "NAMA BARANG   3.500" per baris
  final double confidence;
  final String currency;

  ParsedReceipt({
    required this.items,
    required this.subtotal,
    required this.total,
    this.cash,
    this.change,
    required this.rawText,
    required this.confidence,
    required this.currency,
    String? formattedItems,
  }) : formattedItems = formattedItems ?? _buildFormatted(items);

  bool get hasCashPayment => cash != null && cash! > 0;
  bool get isValid => total > 0;

  /// Format: "MIE GORENG      3.500"
  static String _buildFormatted(List<ReceiptItem> items) {
    if (items.isEmpty) return '';
    // Cari panjang nama terpanjang untuk alignment
    final maxLen = items.fold(0, (m, i) => i.name.length > m ? i.name.length : m);
    final buf = StringBuffer();
    for (final item in items) {
      final name = item.name.toUpperCase().padRight(maxLen + 2);
      // Format harga: angka dengan titik ribuan (misal 3.500)
      final price = _formatPrice(item.totalPrice);
      if (item.qty > 1) {
        buf.writeln('${name}${price}');
        final unitStr = '  ${item.qty} x ${_formatPrice(item.unitPrice)}';
        buf.writeln(unitStr);
      } else {
        buf.writeln('${name}${price}');
      }
    }
    return buf.toString().trimRight();
  }

  static String _formatPrice(double value) {
    // Format dengan titik ribuan: 3500 → "3.500"
    final intVal = value.toInt();
    final str = intVal.toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
  }
}

/// OCR Service — uses Google ML Kit for offline text recognition.
class OcrService {
  static final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Process an image and return structured receipt data.
  static Future<ParsedReceipt> processImage(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;

    // DEBUG: lihat teks mentah yang dibaca ML Kit
    debugPrint('═══ OCR RAW TEXT ═══');
    for (final line in rawText.split('\n')) {
      debugPrint('  | $line');
    }
    debugPrint('════════════════════');

    final confidence = _calculateConfidence(recognizedText);
    final parsed = _parseReceipt(rawText);

    debugPrint('═══ ITEMS PARSED: ${parsed.items.length} ═══');
    for (final item in parsed.items) {
      debugPrint('  → ${item.name} | qty:${item.qty} | price:${item.totalPrice}');
    }

    return ParsedReceipt(
      items: parsed.items,
      subtotal: parsed.subtotal,
      total: parsed.total,
      cash: parsed.cash,
      change: parsed.change,
      rawText: rawText,
      confidence: confidence,
      currency: 'Rp',
    );
  }

  /// Analyze a camera frame for text presence (used for auto-scan).
  /// Returns the number of text blocks detected.
  static Future<int> analyzeFrameForText(
    CameraImage image,
    int sensorOrientation,
  ) async {
    final inputImage = _inputImageFromCamera(image, sensorOrientation);
    if (inputImage == null) return 0;

    final recognized = await _textRecognizer.processImage(inputImage);
    return recognized.blocks.length;
  }

  /// Convert CameraImage (YUV420/NV21) to InputImage for ML Kit.
  static InputImage? _inputImageFromCamera(
    CameraImage image,
    int sensorOrientation,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Concatenate all YUV planes
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final rotation = _rotationFromDegrees(sensorOrientation);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  static InputImageRotation _rotationFromDegrees(int degrees) {
    switch (degrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RECEIPT PARSER — handles messy real-world OCR output
  // ═══════════════════════════════════════════════════════════════════════════

  static ParsedReceipt _parseReceipt(String text) {
    if (text.isEmpty) {
      return ParsedReceipt(
        items: [],
        subtotal: 0,
        total: 0,
        rawText: text,
        confidence: 0,
        currency: 'Rp',
      );
    }

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // ── Step 1: Classify each line ──────────────────────────────────────────
    final classified = <_ClassifiedLine>[];
    for (final line in lines) {
      classified.add(_classifyLine(line));
    }

    // ── Step 2: Merge multi-line items ──────────────────────────────────────
    // Pattern: text-only line followed by "NxPrice" line → combine as one item
    final items = <ReceiptItem>[];
    for (int i = 0; i < classified.length; i++) {
      final c = classified[i];

      if (c.type == _LineType.qtyPrice && i > 0) {
        final prev = classified[i - 1];
        // Previous line is the item name if it was text-only or unclassified text
        if (prev.type == _LineType.itemName || prev.type == _LineType.unknown) {
          final name = prev.text;
          if (name.isNotEmpty && !_isSkipLine(name)) {
            items.add(
              ReceiptItem(
                name: name,
                qty: c.qty ?? 1,
                unitPrice: c.unitPrice ?? c.price ?? 0,
                totalPrice: c.price ?? (c.unitPrice ?? 0) * (c.qty ?? 1),
              ),
            );
            // Mark prev as consumed
            classified[i - 1] = _ClassifiedLine(prev.text, _LineType.consumed);
          }
        }
      } else if (c.type == _LineType.fullItem) {
        items.add(
          ReceiptItem(
            name: c.itemName ?? c.text,
            qty: c.qty ?? 1,
            unitPrice: c.unitPrice ?? c.price ?? 0,
            totalPrice: c.price ?? (c.unitPrice ?? 0) * (c.qty ?? 1),
          ),
        );
      }
    }

    // ── Step 3: Extract summary values from keyword lines ───────────────────
    double subtotal = 0;
    double total = 0;
    double? cash;
    double? change;

    for (final c in classified) {
      if (c.type == _LineType.consumed) continue;

      switch (c.keyword) {
        case _Keyword.subtotal:
          if (c.price != null && c.price! > 0) subtotal = c.price!;
        case _Keyword.total:
          if (c.price != null && c.price! > total) total = c.price!;
        case _Keyword.cash:
          cash ??= c.price;
        case _Keyword.change:
          change ??= c.price;
        default:
          break;
      }
    }

    // ── Step 4: Handle trailing number-only lines (common in receipts) ──────
    // Numbers at the bottom without labels → assign by context
    final trailingNumbers = <double>[];
    for (int i = classified.length - 1; i >= 0; i--) {
      final c = classified[i];
      if (c.type == _LineType.numberOnly && c.price != null) {
        trailingNumbers.insert(0, c.price!);
      } else if (c.type != _LineType.skip && c.type != _LineType.consumed) {
        break;
      }
    }

    // If we have trailing numbers and missing summary values, assign them
    if (trailingNumbers.length >= 2) {
      // Sort to find the pattern: item prices → subtotal → total → cash → change
      // Heuristic: last number that's larger than total = cash, number after = change
      if (total == 0 || cash == null || change == null) {
        _assignTrailingNumbers(
          trailingNumbers,
          items,
          currentTotal: total,
          currentCash: cash,
          currentChange: change,
          onTotal: (v) => total = v,
          onCash: (v) => cash = v,
          onChange: (v) => change = v,
          onSubtotal: (v) => subtotal = v,
        );
      }
    }

    // ── Step 5: Derive missing values ───────────────────────────────────────
    if (subtotal == 0 && items.isNotEmpty) {
      subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    }
    if (total == 0 && subtotal > 0) {
      total = subtotal;
    }
    if (total == 0) {
      total = _findLargestNumber(lines);
    }

    return ParsedReceipt(
      items: items,
      subtotal: subtotal,
      total: total,
      cash: cash,
      change: change,
      rawText: text,
      confidence: 0,
      currency: 'Rp',
    );
  }

  // ── Line Classification ─────────────────────────────────────────────────

  static _ClassifiedLine _classifyLine(String line) {
    final lower = line.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    // Check for keywords first (fuzzy matching for OCR errors)
    final keyword = _detectKeyword(lower);
    if (keyword != null) {
      final price = _extractNumber(line);
      return _ClassifiedLine(
        line,
        _LineType.keyword,
        keyword: keyword,
        price: price,
      );
    }

    // Check for skip lines (address, phone, etc.)
    if (_isSkipLine(lower)) {
      return _ClassifiedLine(line, _LineType.skip);
    }

    // Check for "NxPrice" pattern (qty line, e.g., "1x5.000", "2x 30.000", "3 x 15.000")
    final qtyMatch = RegExp(
      r'^(\d+)\s*[xX×]\s*([\d.,]+)\s*$',
    ).firstMatch(line.trim());
    if (qtyMatch != null) {
      final qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
      final unitPrice = _parseNumber(qtyMatch.group(2)!);
      return _ClassifiedLine(
        line,
        _LineType.qtyPrice,
        qty: qty,
        unitPrice: unitPrice,
        price: unitPrice * qty,
      );
    }

    // Check for full item line: "name  qty x price  total" or "name  qty x price"
    final fullItemMatch = RegExp(
      r'(.+?)\s+(\d+)\s*[xX×]\s*([\d.,]+)(?:\s+([\d.,]+))?\s*$',
    ).firstMatch(line);
    if (fullItemMatch != null) {
      final name = fullItemMatch.group(1)!.trim();
      final qty = int.tryParse(fullItemMatch.group(2)!) ?? 1;
      final unitPrice = _parseNumber(fullItemMatch.group(3)!);
      final totalPrice = fullItemMatch.group(4) != null
          ? _parseNumber(fullItemMatch.group(4)!)
          : unitPrice * qty;
      return _ClassifiedLine(
        line,
        _LineType.fullItem,
        itemName: name,
        qty: qty,
        unitPrice: unitPrice,
        price: totalPrice,
      );
    }

    // Check for number-only line (e.g., "35.000", "100.000")
    final numOnly = RegExp(r'^[\d.,]+$').firstMatch(line.trim());
    if (numOnly != null) {
      return _ClassifiedLine(
        line,
        _LineType.numberOnly,
        price: _parseNumber(line.trim()),
      );
    }

    // Check for line with just "name  price" pattern
    // ✅ Support: 1+ spasi (bukan hanya 2+), untuk struk biasa
    final namePriceMatch = RegExp(
      r'^(.+?)\s+(\d[\d.,]*)\s*$',
    ).firstMatch(line);
    if (namePriceMatch != null) {
      final name = namePriceMatch.group(1)!.trim();
      final priceStr = namePriceMatch.group(2)!;
      final price = _parseNumber(priceStr);
      // Pastikan nama bukan angka semua, harga > 0, dan panjang nama minimal 2 karakter
      if (!RegExp(r'^[\d.,]+$').hasMatch(name) && price > 0 && name.length >= 2) {
        return _ClassifiedLine(
          line,
          _LineType.fullItem,
          itemName: name,
          qty: 1,
          unitPrice: price,
          price: price,
        );
      }
    }

    // Text-only line (potential item name for next line's qty)
    if (!RegExp(r'\d').hasMatch(line)) {
      return _ClassifiedLine(line, _LineType.itemName);
    }

    return _ClassifiedLine(line, _LineType.unknown);
  }

  // ── Fuzzy Keyword Detection ─────────────────────────────────────────────
  // Handles OCR misreads like "10TAI"→TOTAL, "Lash"→Cash, "Keuba l ian"→Kembalian

  static _Keyword? _detectKeyword(String lower) {
    // Remove spaces for fuzzy matching
    final compact = lower.replaceAll(' ', '');

    // CHANGE / KEMBALIAN — check first (before cash, since "kembali" contains "ba")
    if (_fuzzyMatch(compact, [
          'kembalian',
          'kembali',
          'kembal',
          'kmbali',
          'change',
        ]) ||
        RegExp(
          r'k.{0,2}e.{0,2}m.{0,2}b.{0,2}a.{0,2}l',
          caseSensitive: false,
        ).hasMatch(compact)) {
      return _Keyword.change;
    }

    // SUBTOTAL — check before total
    if (_fuzzyMatch(compact, ['subtotal', 'sub total', 'sub-total'])) {
      return _Keyword.subtotal;
    }

    // TOTAL
    if (_fuzzyMatch(compact, [
          'grandtotal',
          'totalbelanja',
          'totalbayar',
          'total',
        ]) ||
        RegExp(r't.?o.?t.?a.?[li1]', caseSensitive: false).hasMatch(compact) ||
        RegExp(r'[t1].?ota[li1]', caseSensitive: false).hasMatch(compact)) {
      // Avoid matching "subtotal" again
      if (!_fuzzyMatch(compact, ['subtotal', 'sub'])) {
        return _Keyword.total;
      }
    }

    // CASH / TUNAI / BAYAR
    if (_fuzzyMatch(compact, [
          'tunai',
          'cash',
          'bayar',
          'pembayaran',
          'debit',
          'kredit',
        ]) ||
        RegExp(r'[cl]a[s5]h', caseSensitive: false).hasMatch(compact) ||
        RegExp(r'tun.?[ae]i', caseSensitive: false).hasMatch(compact)) {
      return _Keyword.cash;
    }

    return null;
  }

  static bool _fuzzyMatch(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  // ── Skip Line Detection ─────────────────────────────────────────────────

  static bool _isSkipLine(String lower) {
    final skipPatterns = [
      RegExp(r'^jl\.?\s|^jln|^alamat', caseSensitive: false), // Address
      RegExp(r'terima\s*kasih|thank', caseSensitive: false),
      RegExp(r'^\d{8,}$'), // Phone numbers
      RegExp(r'nomor\s*ref|no\.?\s*ref|invoice', caseSensitive: false),
      RegExp(r'kasir|cashier', caseSensitive: false),
      RegExp(r'tanggal|date|waktu|time', caseSensitive: false),
      RegExp(r'member|pelanggan', caseSensitive: false),
      RegExp(r'struk|nota|receipt', caseSensitive: false),
      RegExp(r'pesanan|order|meja|table', caseSensitive: false),
      RegExp(r'ppn|pajak|tax|diskon|discount', caseSensitive: false),
      RegExp(r'tipe|type|dine|take', caseSensitive: false),
      RegExp(r'kota|kab|prov|telp|phone|hp', caseSensitive: false),
    ];
    return skipPatterns.any((p) => p.hasMatch(lower));
  }

  // ── Trailing Numbers Assignment ─────────────────────────────────────────
  // When receipt has number-only lines at the bottom like:
  // 5.000, 30.000, 35.000, 35.000, 100.000, 65.000
  // → item prices, subtotal, total, cash, change

  static void _assignTrailingNumbers(
    List<double> numbers,
    List<ReceiptItem> items, {
    required double currentTotal,
    required double? currentCash,
    required double? currentChange,
    required void Function(double) onTotal,
    required void Function(double) onCash,
    required void Function(double) onChange,
    required void Function(double) onSubtotal,
  }) {
    if (numbers.isEmpty) return;

    // Find the item prices sum to identify where summary starts
    final itemPriceSum = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    // Strategy: Look for a number matching itemPriceSum (= subtotal/total)
    // Then the number after that matching sum = cash, next = change
    int summaryStart = -1;
    for (int i = 0; i < numbers.length; i++) {
      if (itemPriceSum > 0 && (numbers[i] - itemPriceSum).abs() < 1) {
        summaryStart = i;
        break;
      }
    }

    if (summaryStart >= 0 && summaryStart < numbers.length) {
      // Found subtotal/total match
      if (currentTotal == 0) {
        onSubtotal(numbers[summaryStart]);
        // Check if next number is same (total = subtotal)
        if (summaryStart + 1 < numbers.length &&
            (numbers[summaryStart + 1] - numbers[summaryStart]).abs() < 1) {
          onTotal(numbers[summaryStart + 1]);
          summaryStart++;
        } else {
          onTotal(numbers[summaryStart]);
        }
      }
      // Cash: next number larger than total
      if (currentCash == null && summaryStart + 1 < numbers.length) {
        final possibleCash = numbers[summaryStart + 1];
        if (possibleCash >=
            (currentTotal > 0 ? currentTotal : numbers[summaryStart])) {
          onCash(possibleCash);
          summaryStart++;
        }
      }
      // Change: next number
      if (currentChange == null && summaryStart + 1 < numbers.length) {
        onChange(numbers[summaryStart + 1]);
      }
    } else if (numbers.length >= 3) {
      // Fallback: assume last 3 numbers are total, cash, change
      if (currentTotal == 0) onTotal(numbers[numbers.length - 3]);
      if (currentCash == null &&
          numbers[numbers.length - 2] >= numbers[numbers.length - 3]) {
        onCash(numbers[numbers.length - 2]);
      }
      if (currentChange == null) onChange(numbers[numbers.length - 1]);
    } else if (numbers.length == 2) {
      if (currentTotal == 0) onTotal(numbers[0]);
      if (numbers[1] > numbers[0]) {
        if (currentCash == null) onCash(numbers[1]);
      }
    } else if (numbers.length == 1 && currentTotal == 0) {
      onTotal(numbers[0]);
    }
  }

  // ── Number Helpers ──────────────────────────────────────────────────────

  static double? _extractNumber(String text) {
    String cleaned = text.replaceAll(RegExp(r'[Rr][Pp]\s*'), '');
    final matches = RegExp(r'[\d]+[.,\d]*').allMatches(cleaned);
    double? largest;
    for (final match in matches) {
      final value = _parseNumber(match.group(0)!);
      if (largest == null || value > largest) largest = value;
    }
    return largest;
  }

  static double _parseNumber(String numStr) {
    numStr = numStr.replaceAll(RegExp(r'[Rr][Pp]\s*'), '');
    numStr = numStr.replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(numStr) ?? 0;
  }

  static double _findLargestNumber(List<String> lines) {
    double largest = 0;
    for (final line in lines) {
      final num = _extractNumber(line);
      if (num != null && num > largest) largest = num;
    }
    return largest;
  }

  /// Hitung confidence berdasarkan kualitas OCR output.
  /// ML Kit Latin script di Android hampir tidak pernah mengembalikan
  /// nilai confidence dari element, jadi kita pakai heuristic multi-faktor.
  static double _calculateConfidence(RecognizedText text) {
    if (text.blocks.isEmpty) return 0.0;

    // ── Coba ambil dari ML Kit langsung ──────────────────────────────────
    double totalConf = 0;
    int confCount = 0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        for (final el in line.elements) {
          if (el.confidence != null) {
            totalConf += el.confidence!;
            confCount++;
          }
        }
      }
    }
    if (confCount > 0) return (totalConf / confCount).clamp(0.0, 1.0);

    // ── Fallback: heuristic multi-faktor ─────────────────────────────────
    // Faktor 1: Jumlah block (struk biasanya 3-10 block)
    final blockScore = (text.blocks.length / 8.0).clamp(0.0, 1.0);

    // Faktor 2: Rata-rata panjang teks per line (lebih panjang = lebih banyak info)
    int totalLines = 0;
    int totalChars = 0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        totalLines++;
        totalChars += line.text.length;
      }
    }
    final avgLineLen = totalLines > 0 ? totalChars / totalLines : 0;
    final lengthScore = (avgLineLen / 20.0).clamp(0.0, 1.0);

    // Faktor 3: Rasio karakter "bersih" (huruf/angka) vs total
    final allText = text.text;
    final cleanChars = RegExp(r'[a-zA-Z0-9.,\s]').allMatches(allText).length;
    final cleanRatio = allText.isNotEmpty ? cleanChars / allText.length : 0.0;

    // Faktor 4: Ada angka (harga) → kemungkinan struk valid
    final hasNumbers = RegExp(r'\d{3,}').hasMatch(allText);
    final numberBonus = hasNumbers ? 0.1 : 0.0;

    // Gabung dengan bobot
    final score = (blockScore * 0.25) +
        (lengthScore * 0.30) +
        (cleanRatio * 0.35) +
        numberBonus;

    return score.clamp(0.0, 1.0);
  }

  static void dispose() {
    _textRecognizer.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Internal Classification Types
// ═══════════════════════════════════════════════════════════════════════════

enum _LineType {
  itemName,
  qtyPrice,
  fullItem,
  numberOnly,
  keyword,
  skip,
  unknown,
  consumed,
}

enum _Keyword { subtotal, total, cash, change }

class _ClassifiedLine {
  final String text;
  _LineType type;
  final _Keyword? keyword;
  final double? price;
  final int? qty;
  final double? unitPrice;
  final String? itemName;

  _ClassifiedLine(
    this.text,
    this.type, {
    this.keyword,
    this.price,
    this.qty,
    this.unitPrice,
    this.itemName,
  });
}
