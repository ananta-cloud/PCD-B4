import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Image Processing Service — implements core PCD (Pengolahan Citra Digital) algorithms.
///
/// Pipeline: Original → Grayscale → Binary Threshold
/// Grayscale formula (ITU-R BT.601): Gray = 0.299R + 0.587G + 0.114B
class ImageProcessingService {
  /// Convert RGB image to grayscale using the luminance formula.
  ///
  /// Uses ITU-R BT.601 standard:
  ///   Gray = 0.299 × R + 0.587 × G + 0.114 × B
  ///
  /// This manual implementation demonstrates the PCD grayscale concept.
  static Future<File> convertToGrayscale(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Gagal decode gambar');

    final result = img.Image(width: original.width, height: original.height);

    for (int y = 0; y < original.height; y++) {
      for (int x = 0; x < original.width; x++) {
        final pixel = original.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // ITU-R BT.601 luminance formula
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);

        result.setPixelRgb(x, y, gray, gray, gray);
      }
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/grayscale_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(result, quality: 90));
    return file;
  }

  /// Apply binary thresholding to separate text (black) from background (white).
  ///
  /// Pixels with luminance > [threshold] become white (255),
  /// pixels below become black (0).
  /// This is a core PCD segmentation technique.
  static Future<File> applyThreshold(File inputFile, {int threshold = 128}) async {
    final bytes = await inputFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Gagal decode gambar');

    // Ensure grayscale first
    final gray = img.grayscale(decoded.clone());

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final luminance = pixel.r.toInt(); // R=G=B after grayscale
        if (luminance > threshold) {
          gray.setPixelRgb(x, y, 255, 255, 255);
        } else {
          gray.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/threshold_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(gray, quality: 90));
    return file;
  }

  /// Resize image to target dimensions.
  static Future<File> resizeImage(File inputFile, {int width = 640}) async {
    final bytes = await inputFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) throw Exception('Gagal decode gambar');

    final resized = img.copyResize(original, width: width);

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(resized, quality: 90));
    return file;
  }
}
