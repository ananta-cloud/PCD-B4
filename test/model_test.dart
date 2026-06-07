import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  test('Inspect YOLO model', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final interpreter = await Interpreter.fromFile(File('assets/ml/best_int8.tflite'));
    
    print('Input Tensors:');
    for (var tensor in interpreter.getInputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
      try {
        print('Quantization params: scale=${tensor.params.scale}, zeroPoint=${tensor.params.zeroPoint}');
      } catch (e) {
         print('No quantization params');
      }
    }

    print('\nOutput Tensors:');
    for (var tensor in interpreter.getOutputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
      try {
        print('Quantization params: scale=${tensor.params.scale}, zeroPoint=${tensor.params.zeroPoint}');
      } catch (e) {
         print('No quantization params');
      }
    }
    
    interpreter.close();
  });
}
