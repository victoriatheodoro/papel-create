import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<String> extractText(XFile file) async {
  final compressedPath = await _compress(file.path);
  final inputImage = InputImage.fromFilePath(compressedPath ?? file.path);
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(inputImage);
    return result.text;
  } finally {
    recognizer.close();
  }
}

Future<String?> _compress(String path) async {
  final target = '${path}_c.jpg';
  final result = await FlutterImageCompress.compressAndGetFile(
    path, target, quality: 80, minWidth: 1024,
  );
  return result?.path;
}
