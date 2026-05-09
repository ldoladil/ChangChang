import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // On spécifie le script CHINOIS pour que le modèle sache quoi chercher
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  Future<String> scanImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // On récupère tout le texte brut
      return recognizedText.text;
    } catch (e) {
      return "Erreur lors de la lecture: $e";
    }
  }

  Future<RecognizedText> scanImageFull(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      return await _textRecognizer.processImage(inputImage);
    } catch (e) {
      print("OCR Error: $e");
      throw Exception("Failed to process image: $e");
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
