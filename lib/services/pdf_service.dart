import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class PdfService {
  /// Mengekspor daftar struk menjadi file PDF dan langsung membuka menu share OS
  static Future<void> exportMonthlyRecap(DateTime month, List<Receipt> receipts) async {
    // Load Google Font agar support Unicode (huruf Indonesia, simbol, dll)
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    // Helper formatter
    String formatCurrency(double amount) {
      final f = amount
          .toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
      return 'Rp $f';
    }

    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final monthFormat = DateFormat('MMMM yyyy');

    final totalSpending = receipts.fold(0.0, (sum, r) => sum + r.totalAmount);

    // Sort receipts from oldest to newest
    final sortedReceipts = List<Receipt>.from(receipts)
      ..sort((a, b) => a.scannedAt.compareTo(b.scannedAt));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ReceiptSync',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    'Rekap Bulanan',
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Info Box
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Periode Laporan', style: const pw.TextStyle(color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        monthFormat.format(month),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Pengeluaran', style: const pw.TextStyle(color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        formatCurrency(totalSpending),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Total: ${receipts.length} Struk',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Details Section Title
            pw.Text(
              'Rincian Transaksi',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 15),

            // List of Receipts
            if (sortedReceipts.isEmpty)
              pw.Center(
                child: pw.Text(
                  'Tidak ada transaksi pada bulan ini.',
                  style: const pw.TextStyle(color: PdfColors.grey600),
                ),
              )
            else
              ...sortedReceipts.map((r) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            dateFormat.format(r.scannedAt),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Confidence: ${(r.confidenceScore * 100).toStringAsFixed(0)}%',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Text(
                        formatCurrency(r.totalAmount),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ],
                  ),
                );
              }),

            // Footer summary
            if (sortedReceipts.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL KESELURUHAN',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    formatCurrency(totalSpending),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ],
              ),
            ]
          ];
        },
      ),
    );

    // Generate filename and share
    final filename = 'Rekap_ReceiptSync_${DateFormat('MMM_yyyy').format(month)}.pdf';
    
    // Convert to bytes
    final bytes = await pdf.save();
    
    // Trigger OS share dialog
    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );
  }
}
