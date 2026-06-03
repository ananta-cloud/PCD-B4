import 'dart:io';
import 'dart:typed_data';

class OpenCVService {
  /// Fallback implementation without native OpenCV
  /// This bypasses image preprocessing and passes the image directly to OCR
  /// TODO: Re-enable native opencv_dart once NDK build is properly configured
  Future<Uint8List?> cropReceiptBody(String imagePath) async {
    try {
      // For now, just read the image file and return its bytes
      // This skips the perspective correction and body segmentation,
      // but allows the app to run and test the OCR functionality
      final file = File(imagePath);
      if (!await file.exists()) {
        print("Image file not found: $imagePath");
        return null;
      }

      final bytes = await file.readAsBytes();
      print("Loaded image without preprocessing: ${bytes.length} bytes");
      return bytes;
    } catch (e) {
      print("Error di OpenCVService: $e");
      return null;
    }
  }
}
