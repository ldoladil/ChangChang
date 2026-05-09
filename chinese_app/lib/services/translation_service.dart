import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  // On prépare le traducteur (Chinois -> Français)
  final _onDeviceTranslator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.chinese,
    targetLanguage: TranslateLanguage.french,
  );

  final _modelManager = OnDeviceTranslatorModelManager();

  // Move static to class level (fix: remove 'static' from inside method)
  bool modelsDownloaded = false;

  /// Fonction principale : Traduit le texte
  Future<String> translate(String text) async {
    try {
      // Cache checks
      if (!modelsDownloaded) {
        // 1. On vérifie si les modèles sont téléchargés
        final bool isFrenchDownloaded = await _modelManager
            .isModelDownloaded(TranslateLanguage.french.bcpCode);
        final bool isChineseDownloaded = await _modelManager
            .isModelDownloaded(TranslateLanguage.chinese.bcpCode);

        // 2. Si non, on les télécharge (ça peut prendre un peu de temps la 1ère fois)
        if (!isFrenchDownloaded) {
          print("Téléchargement du modèle Français...");
          await _modelManager.downloadModel(TranslateLanguage.french.bcpCode);
        }
        if (!isChineseDownloaded) {
          print("Téléchargement du modèle Chinois...");
          await _modelManager.downloadModel(TranslateLanguage.chinese.bcpCode);
        }
        modelsDownloaded = true;
      }

      // 3. On traduit
      final String translation = await _onDeviceTranslator.translateText(text);
      return translation;
    } catch (e) {
      print("Erreur de traduction : $e");
      return "Erreur traduction"; // Ensure non-null return
    }
  }

  // Nettoyage de la mémoire quand on ferme l'app
  void dispose() {
    _onDeviceTranslator.close();
  }
}
