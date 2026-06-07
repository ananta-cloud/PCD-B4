import 'dart:io';
import 'package:flutter/material.dart';
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
  });

  bool get hasCashPayment => cash != null && cash! > 0;
  bool get isValid => total > 0;
}

class OcrService {
  static final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// UPDATE: Fungsi sekarang menerima List kotak item dan satu kotak total dari YOLO
  static Future<ParsedReceipt> processImage(
    File imageFile, {
    List<Rect> itemBoxes = const [], // Menampung semua kotak berlabel 'item_belanja'
    Rect? totalBox,                  // Menampung kotak berlabel 'total'
  }) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    // Wadah penampung baris teks yang difilter koordinat YOLO
    List<String> itemLines = [];
    List<String> totalLines = [];
    List<String> allLines = []; // Untuk cadangan jika YOLO meleset

    // Iterasi membaca baris demi baris teks dari Google OCR
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        final Rect kotakTeks = line.boundingBox;
        allLines.add(line.text);

        // 1. Cek apakah baris teks ini berada di dalam salah satu kotak 'item_belanja'
        bool isInsideItem = false;
        for (Rect box in itemBoxes) {
          if (_isBoxInside(kotakTeks, box)) {
            isInsideItem = true;
            break;
          }
        }
        if (isInsideItem) {
          itemLines.add(line.text);
        }

        // 2. Cek apakah baris teks ini berada di dalam kotak 'total'
        if (totalBox != null && _isBoxInside(kotakTeks, totalBox)) {
          totalLines.add(line.text);
        }
      }
    }

    // --- STRATEGI FALLBACK AMAN ---
    // Jika YOLO berhasil memfilter, gunakan teks hasil saringan tersebut.
    // Jika koordinat YOLO kosong/meleset, gunakan seluruh teks asli agar aplikasi tidak blank.
    String rawTextForItems = itemLines.isNotEmpty ? itemLines.join('\n') : recognizedText.text;

    final confidence = _calculateConfidence(recognizedText);
    
    // 3. Ekstrak Daftar Barang: Jalankan parser bawaanmu HANYA pada teks area 'item_belanja'
    // Ini membuat _parseReceipt milikmu fokus tanpa terganggu teks info_toko atau header lainnya!
    final parsed = _parseReceipt(rawTextForItems);

    // 4. Ekstrak Nilai Total: Jika kotak total terdeteksi, ambil angka terbesar di dalam kotak tersebut
    double finalTotal = parsed.total;
    if (totalLines.isNotEmpty) {
      finalTotal = _findLargestNumber(totalLines);
    } else if (finalTotal == 0) {
      // Jika area total kosong, gunakan pencarian angka terbesar dari seluruh struk sebagai cadangan
      finalTotal = _findLargestNumber(allLines);
    }

    // Teks yang akan ditampilkan di Tab "Teks OCR"
    String displayedRawText = '';
    if (itemLines.isNotEmpty || totalLines.isNotEmpty) {
      if (itemLines.isNotEmpty) {
        displayedRawText += "--- AREA ITEM BELANJA (YOLO) ---\n" + itemLines.join('\n') + "\n\n";
      }
      if (totalLines.isNotEmpty) {
        displayedRawText += "--- AREA TOTAL (YOLO) ---\n" + totalLines.join('\n');
      }
    } else {
      // Jika YOLO meleset/tidak mendeteksi, tampilkan semua teks sebagai fallback
      displayedRawText = "--- SELURUH TEKS (YOLO Tidak Mendeteksi Area) ---\n" + recognizedText.text;
    }

    return ParsedReceipt(
      items: parsed.items,
      subtotal: parsed.subtotal,
      total: finalTotal,
      cash: parsed.cash,
      change: parsed.change,
      rawText: displayedRawText.trim(),
      confidence: confidence,
      currency: 'Rp',
    );
  }

  /// HELPER BARU: Logika matematika untuk mengecek irisan posisi kotak teks di dalam kotak YOLO
  static bool _isBoxInside(Rect inner, Rect outer) {
    // Berikan sedikit toleransi sebesar 10 piksel jika koordinat pemotongan YOLO terlalu mepet
    const double padding = 10;
    return inner.left >= (outer.left - padding) &&
           inner.right <= (outer.right + padding) &&
           inner.top >= (outer.top - padding) &&
           inner.bottom <= (outer.bottom + padding);
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
    final namePriceMatch = RegExp(
      r'^(.+?)\s{2,}([\d.,]+)\s*$',
    ).firstMatch(line);
    if (namePriceMatch != null) {
      final name = namePriceMatch.group(1)!.trim();
      final price = _parseNumber(namePriceMatch.group(2)!);
      if (!RegExp(r'^\d').hasMatch(name) && price > 0) {
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

  // ── Confidence ──────────────────────────────────────────────────────────

  static double _calculateConfidence(RecognizedText text) {
    if (text.blocks.isEmpty) return 0.0;
    double totalConfidence = 0;
    int count = 0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final conf = element.confidence;
          if (conf != null) {
            totalConfidence += conf;
            count++;
          }
        }
      }
    }
    if (count > 0) return (totalConfidence / count).clamp(0.0, 1.0);
    int totalElements = 0;
    for (final block in text.blocks) {
      for (final line in block.lines) {
        totalElements += line.elements.length;
      }
    }
    return (totalElements / 30.0).clamp(0.3, 0.95);
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
