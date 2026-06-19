import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../controllers/crop_controller.dart';
import 'ocr_preview_screen.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;
  const CropScreen({super.key, required this.imageFile});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _cropController = CropController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processAuto();
    });
  }

  Future<void> _processAuto() async {
    final result = await _cropController.autoProcess(widget.imageFile);
    if (result != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrPreviewScreen(
            croppedFile: result.croppedFile,
            parsedReceipt: result.parsedReceipt,
          ),
        ),
      );
    } else if (mounted && _cropController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cropController.errorMessage!)),
      );
      _cropController.clearError();
      Navigator.of(context).pop(); // Go back if failed
    }
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cropController,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),
                Text(
                  _cropController.processingStep.isNotEmpty
                      ? _cropController.processingStep
                      : 'Memulai pemrosesan...',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}