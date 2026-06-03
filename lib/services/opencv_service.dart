import 'dart:math' as math;
import 'dart:typed_data';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class OpenCVService {
  
  /// TAHAP UTAMA: Fungsi yang akan dipanggil oleh Repository untuk memotong bodi struk
  Future<Uint8List?> cropReceiptBody(String imagePath) async {
    try {
      // 1. Baca file gambar dari storage lokal HP menjadi Matriks OpenCV (Mat)
      cv.Mat img = cv.imread(imagePath);
      if (img.isEmpty) return null;

      // 2. Jalankan Tahap 1: Eliminasi Background Meja & Meluruskan Perspektif
      cv.Mat fullReceipt = _extractFullReceipt(img);

      // 3. Jalankan Tahap 2: Isolasi Area Daftar Barang (Body Only)
      cv.Mat receiptBody = _segmentReceiptBody(fullReceipt);

      // 4. Konversi Matriks OpenCV (.jpg) ke format bytes agar bisa dipahami Flutter UI & ML Kit
      final (_, bytes) = cv.imencode(".jpg", receiptBody);
      
      // PENTING: Bebaskan memori native C++ agar HP tidak mengalami memory leak / lag
      img.dispose();
      fullReceipt.dispose();
      receiptBody.dispose();

      return Uint8List.fromList(bytes);
    } catch (e) {
      print("Error di OpenCVService: $e");
      return null;
    }
  }

  /// TAHAP 1: Logika pencarian kontur kertas struk dan pelurusan sudut
  cv.Mat _extractFullReceipt(cv.Mat img) {
    final gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
    final blurred = cv.gaussianBlur(gray, (5, 5), 0);
    final edged = cv.canny(blurred, 75, 200);

    final (contours, _) = cv.findContours(edged, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
    
    final sortedContours = contours.toList();
    sortedContours.sort((a, b) => cv.contourArea(b).compareTo(cv.contourArea(a)));

    cv.VecPoint? receiptContour;
    int maxCheck = math.min(5, sortedContours.length);
    
    for (int i = 0; i < maxCheck; i++) {
      final c = sortedContours[i];
      double peri = cv.arcLength(c, true);
      final approx = cv.approxPolyDP(c, 0.02 * peri, true);

      if (approx.length == 4) {
        receiptContour = approx;
        break;
      }
    }

    if (receiptContour != null) {
      return _fourPointTransform(img, receiptContour.toList());
    }
    
    return img.clone(); // Fallback jika gagal mendeteksi kertas struk
  }

  /// TAHAP 2: Logika segmentasi morfologi untuk memisahkan bodi dari header & footer
  cv.Mat _segmentReceiptBody(cv.Mat warpedImg) {
    int h = warpedImg.rows;
    int w = warpedImg.cols;

    final gray = cv.cvtColor(warpedImg, cv.COLOR_BGR2GRAY);
    final thresh = cv.threshold(gray, 0, 255, cv.THRESH_BINARY_INV + cv.THRESH_OTSU).$2;

    // Deteksi garis horizontal minimal sepanjang 40% dari lebar struk
    int kernelWidth = (w * 0.4).toInt();
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (kernelWidth, 1));
    final detectHorizontal = cv.morphologyEx(thresh, cv.MORPH_OPEN, kernel, iterations: 2);

    final (cnts, _) = cv.findContours(detectHorizontal, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
    List<int> yCoords = cnts.map((c) => cv.boundingRect(c).y).toList();
    yCoords.sort();

    // Default crop (25% atas s.d 85% bawah) jika struk polosan tanpa garis tabel
    int yStart = (h * 0.25).toInt();
    int yEnd = (h * 0.85).toInt();

    // Pengaman boks kode transaksi (Abaikan garis di area 10% teratas)
    List<int> validLines = yCoords.where((y) => y > (h * 0.10)).toList();

    if (validLines.length >= 2) {
      yStart = validLines.first;
      yEnd = validLines.last + 15; // Padding 15px agar baris total aman tidak terpotong
    } else if (validLines.length == 1) {
      if (validLines.first < (h * 0.5)) {
        yStart = validLines.first;
      }
    }

    if (yStart >= yEnd || (yEnd - yStart) < (h * 0.2)) {
      yStart = (h * 0.25).toInt();
      yEnd = (h * 0.85).toInt();
    }

    if (yEnd > h) yEnd = h;

    final cropRect = cv.Rect(0, yStart, w, yEnd - yStart);
    return warpedImg.region(cropRect);
  }

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