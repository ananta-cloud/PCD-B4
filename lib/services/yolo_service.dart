import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloDetection {
  final Rect boundingBox;
  final double confidence;
  final int classIndex;
  final String label;

  YoloDetection(this.boundingBox, this.confidence, this.classIndex, this.label);
}

class YoloService {
  static Interpreter? _interpreter;
  static const List<String> _labels = [
    'info_toko',
    'item_belanja',
    'struk_belanja',
    'total'
  ];

  static Future<void> init() async {
    if (_interpreter != null) return;
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset('assets/ml/best_int8.tflite', options: options);
      debugPrint('✅ YOLO Model loaded successfully');
    } catch (e) {
      debugPrint('❌ Failed to load YOLO model: $e');
    }
  }

  static Future<List<YoloDetection>> detect(File imageFile) async {
    if (_interpreter == null) await init();
    if (_interpreter == null) return [];

    try {
      // 1. Load image
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return [];

      final origW = originalImage.width.toDouble();
      final origH = originalImage.height.toDouble();

      // 2. Prepare input
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape; // e.g., [1, 640, 640, 3]
      final inputSize = inputShape[1]; // assuming square 640x640

      final resizedImage = img.copyResize(originalImage, width: inputSize, height: inputSize);

      bool isInputInt = inputTensor.type == TensorType.int8 || inputTensor.type == TensorType.uint8;
      double inScale = inputTensor.params.scale == 0.0 ? 1.0 : inputTensor.params.scale;
      int inZeroPoint = inputTensor.params.zeroPoint;

      List<dynamic> inputBuffer;
      if (isInputInt) {
        inputBuffer = List.generate(1, (i) => List.generate(inputSize, (y) => List.generate(inputSize, (x) => List.filled(3, 0))));
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            // normalized to [0, 1] then quantized
            inputBuffer[0][y][x][0] = ((pixel.r / 255.0) / inScale + inZeroPoint).round();
            inputBuffer[0][y][x][1] = ((pixel.g / 255.0) / inScale + inZeroPoint).round();
            inputBuffer[0][y][x][2] = ((pixel.b / 255.0) / inScale + inZeroPoint).round();
          }
        }
      } else {
        inputBuffer = List.generate(1, (i) => List.generate(inputSize, (y) => List.generate(inputSize, (x) => List.filled(3, 0.0))));
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            inputBuffer[0][y][x][0] = pixel.r / 255.0;
            inputBuffer[0][y][x][1] = pixel.g / 255.0;
            inputBuffer[0][y][x][2] = pixel.b / 255.0;
          }
        }
      }

      // 3. Prepare output
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape; 
      
      bool isTransposed = outputShape[1] > outputShape[2];
      int numAnchors = isTransposed ? outputShape[1] : outputShape[2];
      
      bool isOutputInt = outputTensor.type == TensorType.int8 || outputTensor.type == TensorType.uint8;
      double outScale = outputTensor.params.scale == 0.0 ? 1.0 : outputTensor.params.scale;
      int outZeroPoint = outputTensor.params.zeroPoint;

      var outputBuffer;
      if (isOutputInt) {
        outputBuffer = List.generate(outputShape[0], (_) => List.generate(outputShape[1], (_) => List.filled(outputShape[2], 0)));
      } else {
        outputBuffer = List.generate(outputShape[0], (_) => List.generate(outputShape[1], (_) => List.filled(outputShape[2], 0.0)));
      }

      // 4. Run inference
      _interpreter!.run(inputBuffer, outputBuffer);

      // Helper to dequantize
      double dequantize(dynamic val) {
        if (val is int) {
          return (val - outZeroPoint) * outScale;
        }
        return val is double ? val : double.parse(val.toString());
      }

      // 5. Process outputs
      List<YoloDetection> allDetections = [];
      double scaleX = origW / inputSize;
      double scaleY = origH / inputSize;

      for (int i = 0; i < numAnchors; i++) {
        double xCenter, yCenter, w, h;
        List<double> classScores = [];

        if (isTransposed) {
           xCenter = dequantize(outputBuffer[0][i][0]);
           yCenter = dequantize(outputBuffer[0][i][1]);
           w = dequantize(outputBuffer[0][i][2]);
           h = dequantize(outputBuffer[0][i][3]);
           for (int c = 0; c < _labels.length; c++) {
             classScores.add(dequantize(outputBuffer[0][i][4 + c]));
           }
        } else {
           xCenter = dequantize(outputBuffer[0][0][i]);
           yCenter = dequantize(outputBuffer[0][1][i]);
           w = dequantize(outputBuffer[0][2][i]);
           h = dequantize(outputBuffer[0][3][i]);
           for (int c = 0; c < _labels.length; c++) {
             classScores.add(dequantize(outputBuffer[0][4 + c][i]));
           }
        }

        double maxScore = -1;
        int maxClassIndex = -1;
        for (int c = 0; c < classScores.length; c++) {
          if (classScores[c] > maxScore) {
            maxScore = classScores[c];
            maxClassIndex = c;
          }
        }

        if (maxScore > 0.4) { // Confidence threshold
          double left = (xCenter - w / 2) * scaleX;
          double top = (yCenter - h / 2) * scaleY;
          double right = (xCenter + w / 2) * scaleX;
          double bottom = (yCenter + h / 2) * scaleY;

          allDetections.add(YoloDetection(
            Rect.fromLTRB(left, top, right, bottom),
            maxScore,
            maxClassIndex,
            _labels[maxClassIndex],
          ));
        }
      }

      // 6. Non-Max Suppression (NMS)
      final results = _applyNMS(allDetections, 0.45);
      debugPrint('🎯 YOLO Found ${results.length} valid objects');
      for (var r in results) {
         debugPrint('   -> ${r.label} (Conf: ${(r.confidence*100).toStringAsFixed(1)}%)');
      }
      return results;

    } catch (e) {
      debugPrint('❌ Error running YOLO inference: $e');
      return [];
    }
  }

  static List<YoloDetection> _applyNMS(List<YoloDetection> detections, double iouThreshold) {
    List<YoloDetection> result = [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence)); // Sort by confidence descending

    while (detections.isNotEmpty) {
      final best = detections.removeAt(0);
      result.add(best);

      detections.removeWhere((detection) {
        if (detection.classIndex != best.classIndex) return false; // Only suppress same class
        double iou = _calculateIoU(best.boundingBox, detection.boundingBox);
        return iou > iouThreshold;
      });
    }

    return result;
  }

  static double _calculateIoU(Rect box1, Rect box2) {
    final intersection = box1.intersect(box2);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;

    final intersectionArea = intersection.width * intersection.height;
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;

    return intersectionArea / (box1Area + box2Area - intersectionArea);
  }
}
