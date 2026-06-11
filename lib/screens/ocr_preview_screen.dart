import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../controllers/ocr_preview_controller.dart';
import 'detail_screen.dart';
import '../services/ocr_service.dart';

/// Halaman preview hasil OCR — user bisa lihat teks raw + item yang terdeteksi
/// sebelum konfirmasi simpan.
class OcrPreviewScreen extends StatefulWidget {
  final File croppedFile;
  final ParsedReceipt parsedReceipt;

  const OcrPreviewScreen({
    super.key,
    required this.croppedFile,
    required this.parsedReceipt,
  });

  @override
  State<OcrPreviewScreen> createState() => _OcrPreviewScreenState();
}

class _OcrPreviewScreenState extends State<OcrPreviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _previewController = OcrPreviewController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _previewController.dispose();
    super.dispose();
  }

  String _formatRp(double amount) {
    final f = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $f';
  }

  Future<void> _saveReceipt() async {
    final receipt = await _previewController.saveReceipt(
      widget.croppedFile,
      widget.parsedReceipt,
    );

    if (receipt != null && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => DetailScreen(receipt: receipt)),
        (route) => route.isFirst,
      );
    } else if (mounted && _previewController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_previewController.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      _previewController.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.parsedReceipt;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0C14),
        elevation: 0,
        title: Text(
          'Hasil OCR',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white38,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Text(
                    'Info Struk',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    'Teks OCR',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildInfoTab(parsed),
                _buildRawTextTab(parsed),
              ],
            ),
          ),

          // Bottom action buttons
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ── Tab 1: Info Struk ────────────────────────────────────────────────────

  Widget _buildInfoTab(ParsedReceipt parsed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence badge
          _ConfidenceBadge(confidence: parsed.confidence),
          const SizedBox(height: 16),

          // Foto hasil crop (kecil, preview)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.croppedFile,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),

          // Items section
          if (parsed.items.isNotEmpty) ...[
            _SectionHeader(title: 'ITEM BELANJA', count: parsed.items.length),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: parsed.items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nomor item
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Nama & qty
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.qty > 1 || item.unitPrice > 0) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item.qty}x ${_formatRp(item.unitPrice)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Harga
                            Text(
                              _formatRp(item.totalPrice),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < parsed.items.length - 1)
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06),
                          indent: 52,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tidak ada item terdeteksi. Cek tab Teks OCR untuk melihat teks mentah.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Summary: subtotal, total, cash, change
          _SectionHeader(title: 'RINGKASAN PEMBAYARAN'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (parsed.subtotal > 0 && parsed.subtotal != parsed.total)
                  _SummaryRow(
                    label: 'Subtotal',
                    value: _formatRp(parsed.subtotal),
                  ),
                _SummaryRow(
                  label: 'TOTAL',
                  value: parsed.isValid
                      ? _formatRp(parsed.total)
                      : 'Tidak terdeteksi',
                  isBold: true,
                  valueColor: parsed.isValid
                      ? AppColors.primary
                      : Colors.redAccent,
                ),
                if (parsed.hasCashPayment) ...[
                  const Divider(color: Colors.white12, height: 20),
                  _SummaryRow(label: 'Tunai', value: _formatRp(parsed.cash!)),
                  if (parsed.change != null && parsed.change! > 0)
                    _SummaryRow(
                      label: 'Kembalian',
                      value: _formatRp(parsed.change!),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Tab 2: Item Barang (formatted) ─────────────────────────────────────

  Widget _buildRawTextTab(ParsedReceipt parsed) {
    final display = parsed.formattedItems;
    if (display.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada item barang terdeteksi',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.list_alt_rounded,
                color: Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Item terdeteksi (${parsed.items.length} barang)',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SelectableText(
              display,
              style: GoogleFonts.spaceMono(
                fontSize: 13,
                color: Colors.white70,
                height: 1.8,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Total di bawah
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  parsed.isValid ? _formatRp(parsed.total) : '-',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return ListenableBuilder(
      listenable: _previewController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1020),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Row(
            children: [
              // Scan ulang
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.crop_rotate_rounded, size: 18),
                  label: Text(
                    'Crop Ulang',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Simpan
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _previewController.isSaving ? null : _saveReceipt,
                  icon: _previewController.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(
                    _previewController.isSaving
                        ? 'Menyimpan...'
                        : 'Simpan Struk',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.4,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final Color color;
    final String label;
    if (pct >= 85) {
      color = const Color(0xFF4CAF50);
      label = 'Kualitas Bagus';
    } else if (pct >= 60) {
      color = Colors.orange;
      label = 'Kualitas Cukup';
    } else {
      color = Colors.redAccent;
      label = 'Kualitas Rendah';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            'Confidence: $pct% — $label',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white38,
            letterSpacing: 1.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isBold ? 15 : 14,
              color: isBold ? Colors.white : Colors.white60,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isBold ? 16 : 14,
              color: valueColor ?? (isBold ? Colors.white : Colors.white),
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
