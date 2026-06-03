import 'dart:math' as math;
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class OpenCVService {
  
  /// MAIN PIPELINE: 2-Tahap Cropping untuk Akurasi OCR Maksimal
  /// 
  /// Alur:
  /// Photo Asli → [CROP 1: Remove Background] → Struk Clean
  ///           → [CROP 2: Extract Total Box] → Total Area Only
  ///           → OCR (akurat!)
  Future<Uint8List?> cropReceiptBody(String imagePath) async {
    try {
      // 1. Baca file gambar
      cv.Mat img = cv.imread(imagePath);
      if (img.isEmpty) return null;

      print("\n🚀 ═══════════════════════════════════════════");
      print("▶️ cropReceiptBody input: $imagePath, size=${img.cols}x${img.rows}");
      print("📸 CROPPING PIPELINE DIMULAI");
      print("═══════════════════════════════════════════\n");

      // 2️⃣ CROP 1: Extract struk bersih dari background meja
      print("▶️  TAHAP 1: Crop Background (Ambil Struk Bersih)");
      cv.Mat cleanReceipt = _cropReceiptFromBackground(img);
      print("✅ Struk bersih siap\n");

      // 3️⃣ CROP 2: Extract hanya area TOTAL dari struk yang sudah clean
      print("▶️  TAHAP 2: Crop Area Total (Dari Struk Clean)");
      cv.Mat totalBox = _cropTotalBoxFromReceipt(cleanReceipt);
      print("✅ Total Box siap\n");

      // 4. Konversi ke bytes
      final (_, bytes) = cv.imencode(".jpg", totalBox);
      
      // 5. Cleanup memori
      img.dispose();
      cleanReceipt.dispose();
      totalBox.dispose();

      print("🎉 ═══════════════════════════════════════════");
      print("✅ CROPPING SELESAI - SIAP KE OCR");
      print("═══════════════════════════════════════════\n");

      return Uint8List.fromList(bytes);
    } catch (e) {
      print("❌ Error di OpenCVService: $e");
      return null;
    }
  }

  // ╔════════════════════════════════════════════════════════════════════════╗
  // ║           CROP 1: EXTRACT STRUK DARI BACKGROUND MEJA                  ║
  // ╚════════════════════════════════════════════════════════════════════════╝

  /// CROP 1: Deteksi kertas struk, luruskan perspektif, crop ketat ke batas kertas
  /// Output: Struk bersih tanpa background meja
  cv.Mat _cropReceiptFromBackground(cv.Mat originalImg) {
    int origH = originalImg.rows;
    int origW = originalImg.cols;
    print("  📐 Original image: ${origW}x$origH");

    // Step 1: Deteksi edge kertas
    final gray = cv.cvtColor(originalImg, cv.COLOR_BGR2GRAY);
    final blurred = cv.gaussianBlur(gray, (5, 5), 0);
    final edged = cv.canny(blurred, 50, 150); // Canny edge detection

    // Step 2: Cari kontur (outline kertas)
    final (contours, _) = cv.findContours(edged, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    
    if (contours.isEmpty) {
      print("  ⚠️  Kontur tidak terdeteksi, gunakan fallback crop");
      return _fallbackReceiptCrop(originalImg);
    }

    // Step 3: Cari kontur terbesar (kertas struk)
    final sortedContours = contours.toList();
    sortedContours.sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

    cv.VecPoint? receiptContour;
    int maxCheck = math.min(5, sortedContours.length);
    
    for (int i = 0; i < maxCheck; i++) {
      final c = sortedContours[i];
      double peri = cv.arcLength(c, true);
      final approx = cv.approxPolyDP(c, 0.02 * peri, true);

      // Kertas harus 4 sisi (persegi panjang)
      if (approx.length == 4) {
        receiptContour = approx;
        break;
      }
    }

    if (receiptContour == null) {
      print("  ⚠️  Kertas 4-sisi tidak terdeteksi, gunakan fallback crop");
      return _fallbackReceiptCrop(originalImg);
    }

    // Step 4: Lakukan perspektif transform (luruskan kertas miring)
    final warpedReceipt = _fourPointTransform(originalImg, receiptContour.toList());
    print("  ✅ Kertas terdeteksi & perspektif diluruskan: ${warpedReceipt.cols}x${warpedReceipt.rows}");

    // Step 5: CROP KETAT ke area teks saja (remove white border)
    final croppedStruk = _removeWhiteBorder(warpedReceipt);
    print("  ✅ White border dihapus: ${croppedStruk.cols}x${croppedStruk.rows}");

    return croppedStruk;
  }

  /// Helper: Hapus white border dari edge image (crop to content)
  cv.Mat _removeWhiteBorder(cv.Mat img) {
    int h = img.rows;
    int w = img.cols;

    final gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
    
    // Threshold: text hitam = 0, background putih = 255
    // Gunakan BINARY_INV agar text menjadi white (255) untuk findContours
    final binInv = cv.threshold(gray, 200, 255, cv.THRESH_BINARY_INV).$2;

    // Cari kontur (area teks yang ter-invert menjadi white)
    final (contours, _) = cv.findContours(binInv, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

    if (contours.isEmpty) {
      print("    ⚠️  Content tidak terdeteksi");
      return img.clone();
    }

    // Cari bounding box terbesar (area teks)
    cv.Rect maxRect = cv.boundingRect(contours[0]);
    for (final c in contours) {
      final r = cv.boundingRect(c);
      int area1 = maxRect.width * maxRect.height;
      int area2 = r.width * r.height;
      if (area2 > area1) maxRect = r;
    }

    // Tambah padding kecil
    int padX = math.max(5, (maxRect.width * 0.02).toInt());
    int padY = math.max(5, (maxRect.height * 0.02).toInt());

    int x1 = math.max(0, maxRect.x - padX);
    int y1 = math.max(0, maxRect.y - padY);
    int x2 = math.min(w, maxRect.x + maxRect.width + padX);
    int y2 = math.min(h, maxRect.y + maxRect.height + padY);

    final cropRect = cv.Rect(x1, y1, x2 - x1, y2 - y1);
    return img.region(cropRect);
  }

  // ╔════════════════════════════════════════════════════════════════════════╗
  // ║        CROP 2: EXTRACT TOTAL BOX DARI STRUK YANG SUDAH CLEAN          ║
  // ╚════════════════════════════════════════════════════════════════════════╝

  /// CROP 2: Dari struk clean, cari & potong hanya area TOTAL saja
  /// Output: Box total/subtotal yang siap OCR
  cv.Mat _cropTotalBoxFromReceipt(cv.Mat cleanReceipt) {
    int h = cleanReceipt.rows;
    int w = cleanReceipt.cols;
    print("  📐 Clean receipt size: ${w}x$h");

    final gray = cv.cvtColor(cleanReceipt, cv.COLOR_BGR2GRAY);
    final blur = cv.gaussianBlur(gray, (3, 3), 0);
    
    // Binary threshold
    final thresh = cv.threshold(blur, 0, 255, cv.THRESH_BINARY_INV + cv.THRESH_OTSU).$2;

    // ═══════════════════════════════════════════════════════════════════════
    // STRATEGI: Deteksi garis horizontal panjang (pemisah items dari total)
    // ═══════════════════════════════════════════════════════════════════════
    
    int kernelWidth = (w * 0.7).toInt(); // Cari garis 70% lebar
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (kernelWidth, 2));
    final linesMat = cv.morphologyEx(thresh, cv.MORPH_OPEN, kernel, iterations: 1);

    final (cnts, _) = cv.findContours(linesMat, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
    
    if (cnts.isEmpty) {
      print("  ⚠️  Garis pemisah tidak terdeteksi");
      return _fallbackTotalCrop(cleanReceipt);
    }

    // Filter garis horizontal yang cukup panjang
    List<cv.Rect> lineRects = cnts
        .map((c) => cv.boundingRect(c))
        .where((r) => r.width > (w * 0.4)) // Lebar minimal 40%
        .toList();

    if (lineRects.isEmpty) {
      print("  ⚠️  Garis panjang tidak ditemukan");
      return _fallbackTotalCrop(cleanReceipt);
    }

    // Urutkan Y dari atas ke bawah
    lineRects.sort((a, b) => a.y.compareTo(b.y));

    // ═══════════════════════════════════════════════════════════════════════
    // LOGIKA: Total biasanya SETELAH garis pemisah terakhir
    // ═══════════════════════════════════════════════════════════════════════
    
    int lastLineY = lineRects.last.y;
    print("  🔍 Garis pemisah terakhir di Y = $lastLineY");

    // Crop dari garis → sampai bawah image
    int yStart = lastLineY;
    int yEnd = h;
    int cropHeight = yEnd - yStart;

    // Validasi: area minimal 5% dari tinggi struk
    if (cropHeight < (h * 0.05)) {
      print("  ⚠️  Area terlalu kecil (${cropHeight}px)");
      return _fallbackTotalCrop(cleanReceipt);
    }

    print("  ✂️ CROP TOTAL: Y=$yStart sampai Y=$yEnd (tinggi=$cropHeight)");

    final cropRect = cv.Rect(0, yStart, w, cropHeight);
    final totalBox = cleanReceipt.region(cropRect);

    return totalBox;
  }

  /// FALLBACK: Jika garis tidak terdeteksi, gunakan bottom 25%
  cv.Mat _fallbackTotalCrop(cv.Mat img) {
    int h = img.rows;
    int w = img.cols;

    int yStart = (h * 0.75).toInt(); // Bottom 25%
    int yEnd = h;

    print("  🔄 FALLBACK: Crop bottom 25% (Y=$yStart sampai Y=$yEnd)");

    final cropRect = cv.Rect(0, yStart, w, yEnd - yStart);
    return img.region(cropRect);
  }

  /// FALLBACK: Jika deteksi kertas gagal, crop sebagian bawah gambar
  cv.Mat _fallbackReceiptCrop(cv.Mat img) {
    int h = img.rows;
    int w = img.cols;
    int yStart = (h * 0.15).toInt();
    int yEnd = h;

    print("  🔄 FALLBACK receipt crop: bottom 85% (Y=$yStart sampai Y=$yEnd)");
    final cropRect = cv.Rect(0, yStart, w, yEnd - yStart);
    return img.region(cropRect);
  }

  // ╔════════════════════════════════════════════════════════════════════════╗
  // ║                    HELPER FUNCTIONS                                   ║
  // ╚════════════════════════════════════════════════════════════════════════╝

  /// Helper: Transformasi perspektif matriks gambar
  cv.Mat _fourPointTransform(cv.Mat image, List<cv.Point> pts) {
    List<cv.Point> rect = _orderPoints(pts);
    final tl = rect[0];
    final tr = rect[1];
    final br = rect[2];
    final bl = rect[3];

    double widthA = math.sqrt(math.pow(br.x - bl.x, 2) + math.pow(br.y - bl.y, 2));
    double widthB = math.sqrt(math.pow(tr.x - tl.x, 2) + math.pow(tr.y - tl.y, 2));
    int maxWidth = math.max(widthA.toInt(), widthB.toInt());

    double heightA = math.sqrt(math.pow(tr.x - br.x, 2) + math.pow(tr.y - br.y, 2));
    double heightB = math.sqrt(math.pow(tl.x - bl.x, 2) + math.pow(tl.y - bl.y, 2));
    int maxHeight = math.max(heightA.toInt(), heightB.toInt());

    final srcPts = cv.VecPoint.fromList(rect);
    final dstPts = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(maxWidth - 1, 0),
      cv.Point(maxWidth - 1, maxHeight - 1),
      cv.Point(0, maxHeight - 1),
    ]);

    final matrix = cv.getPerspectiveTransform(srcPts, dstPts);
    return cv.warpPerspective(image, matrix, (maxWidth, maxHeight));
  }

  /// Helper: Pengurutan 4 titik koordinat sudut kertas
  List<cv.Point> _orderPoints(List<cv.Point> pts) {
    List<cv.Point> rect = List.generate(4, (_) => cv.Point(0, 0));

    List<int> sum = pts.map((p) => p.x + p.y).toList();
    rect[0] = pts[sum.indexOf(sum.reduce(math.min))]; 
    rect[2] = pts[sum.indexOf(sum.reduce(math.max))]; 

    List<int> diff = pts.map((p) => p.y - p.x).toList();
    rect[1] = pts[diff.indexOf(diff.reduce(math.min))]; 
    rect[3] = pts[diff.indexOf(diff.reduce(math.max))]; 

    return rect;
  }
}