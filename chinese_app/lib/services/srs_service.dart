import '../models/word.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SrsService {
  // Qualité de la réponse :
  // 0: Oublié (Reset)
  // 1: Difficile (On réduit l'intervalle)
  // 2: Bon (On augmente un peu)
  // 3: Facile (On augmente beaucoup)

  void processReview(Word word, int quality) {
    if (quality < 2) {
      // ÉCHEC : On remet le compteur à zéro
      word.interval = 1;
      word.easeFactor =
          (word.easeFactor - 0.2).clamp(1.3, 2.5); // On rend un peu plus dur
    } else {
      // SUCCÈS
      if (word.interval == 0) {
        word.interval = 1;
      } else if (word.interval == 1) {
        word.interval = 3; // 2ème révision après 3 jours
      } else {
        // Formule magique SM-2
        word.interval = (word.interval * word.easeFactor)
            .round()
            .clamp(1, 365); // Cap interval
      }

      // Bonus si c'était "Facile" (3)
      if (quality == 3) {
        word.easeFactor += 0.15;
      }
    }

    // Calcul de la prochaine date
    word.nextReview = DateTime.now().add(Duration(days: word.interval));

    // Sauvegarde dans Hive
    try {
      word.save();
    } catch (e) {
      print("Save error: $e");
    }
  }

  // Récupérer les mots à réviser aujourd'hui
  List<Word> getDueWords(List<Word> allWords) {
    final now = DateTime.now();
    return allWords.where((w) => w.nextReview.isBefore(now)).toList();
  }
}
