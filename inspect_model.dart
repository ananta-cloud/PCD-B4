import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() async {
  try {
    final interpreter = await Interpreter.fromFile(File('assets/ml/best_int8.tflite'));
    
    print('Input Tensors:');
    for (var tensor in interpreter.getInputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }

    print('\nOutput Tensors:');
    for (var tensor in interpreter.getOutputTensors()) {
      print('Name: ${tensor.name}, Shape: ${tensor.shape}, Type: ${tensor.type}');
    }
    
    interpreter.close();
  } catch (e) {
    print('Error: $e');
  }
}
