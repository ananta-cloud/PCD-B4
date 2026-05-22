import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Result of the full processing pipeline
class ProcessedResult {
  final File originalFile;
  final File grayscaleFile;
  final File thresholdFile;
  final int otsuThreshold;
  final int processingTimeMs;

  ProcessedResult({
    required this.originalFile,
    required this.grayscaleFile,
    required this.thresholdFile,
    required this.otsuThreshold,
    required this.processingTimeMs,
  });
}

/// Image Processing Service — PCD pipeline with Otsu's method.
///
/// Pipeline runs in a background Isolate via compute():
///   Original → Grayscale (ITU-R BT.601) → Binary (Otsu's Threshold)
class ImageProcessingService {
  /// Run the full pipeline in a background isolate.
  static Future<ProcessedResult> processFullPipeline(File inputFile) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    final result = await compute(_runPipeline, {
      'input': inputFile.path,
      'grayOut': '${dir.path}/gray_$ts.jpg',
      'threshOut': '${dir.path}/thresh_$ts.jpg',
    });

    return ProcessedResult(
      originalFile: inputFile,
      grayscaleFile: File(result['grayOut'] as String),
      thresholdFile: File(result['threshOut'] as String),
      otsuThreshold: result['otsu'] as int,
      processingTimeMs: result['ms'] as int,
    );
  }
}

/// Runs in a separate Isolate — no UI thread blocking.
Map<String, dynamic> _runPipeline(Map<String, String> p) {
  final sw = Stopwatch()..start();

  final bytes = File(p['input']!).readAsBytesSync();
  final original = img.decodeImage(bytes);
  if (original == null) throw Exception('Gagal decode gambar');

  // ── Step 1: Grayscale (ITU-R BT.601) ──────────────────────────────────
  // Gray = 0.299R + 0.587G + 0.114B
  final gray = img.Image(width: original.width, height: original.height);
  for (int y = 0; y < original.height; y++) {
    for (int x = 0; x < original.width; x++) {
      final px = original.getPixel(x, y);
      final g = (0.299 * px.r.toInt() + 0.587 * px.g.toInt() + 0.114 * px.b.toInt())
          .round()
          .clamp(0, 255);
      gray.setPixelRgb(x, y, g, g, g);
    }
  }
  File(p['grayOut']!).writeAsBytesSync(img.encodeJpg(gray, quality: 90));

  // ── Step 2: Otsu's Threshold ──────────────────────────────────────────
  final threshold = _computeOtsu(gray);
  final binary = gray.clone();
  for (int y = 0; y < binary.height; y++) {
    for (int x = 0; x < binary.width; x++) {
      final v = binary.getPixel(x, y).r.toInt();
      final c = v > threshold ? 255 : 0;
      binary.setPixelRgb(x, y, c, c, c);
    }
  }
  File(p['threshOut']!).writeAsBytesSync(img.encodeJpg(binary, quality: 90));

  sw.stop();
  return {
    'grayOut': p['grayOut']!,
    'threshOut': p['threshOut']!,
    'otsu': threshold,
    'ms': sw.elapsedMilliseconds,
  };
}

/// Otsu's Method — finds optimal threshold that maximizes inter-class variance.
///
/// Algorithm:
/// 1. Build 256-bin histogram of grayscale values
/// 2. For each candidate threshold t (0-255):
///    - Split pixels into background (≤t) and foreground (>t)
///    - Calculate inter-class variance
/// 3. Return t that maximizes the variance
int _computeOtsu(img.Image grayscale) {
  // Build histogram
  final hist = List<int>.filled(256, 0);
  for (int y = 0; y < grayscale.height; y++) {
    for (int x = 0; x < grayscale.width; x++) {
      hist[grayscale.getPixel(x, y).r.toInt()]++;
    }
  }

  final total = grayscale.width * grayscale.height;
  double sumAll = 0;
  for (int i = 0; i < 256; i++) {
    sumAll += i * hist[i];
  }

  double sumBg = 0;
  int wBg = 0;
  double maxVariance = 0;
  int bestT = 0;

  for (int t = 0; t < 256; t++) {
    wBg += hist[t];
    if (wBg == 0) continue;
    final wFg = total - wBg;
    if (wFg == 0) break;

    sumBg += t * hist[t];
    final meanBg = sumBg / wBg;
    final meanFg = (sumAll - sumBg) / wFg;
    final diff = meanBg - meanFg;
    final variance = wBg.toDouble() * wFg.toDouble() * diff * diff;

    if (variance > maxVariance) {
      maxVariance = variance;
      bestT = t;
    }
  }

  return bestT;
}
