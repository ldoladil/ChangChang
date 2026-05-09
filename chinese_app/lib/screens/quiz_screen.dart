import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';
import '../services/srs_service.dart';

class QuizScreen extends StatefulWidget {
// --- NOUVEAUX PARAMÈTRES ---
  final bool isCramMode;
  final List<Word>? customWords; // Les mots passés depuis les filtres

  const QuizScreen({
    super.key,
    this.isCramMode = false,
    this.customWords,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final SrsService _srsService = SrsService();
  late Box<Word> _wordBox;
  List<Word> _dueWords = [];
  int _currentIndex = 0;
  bool _isFlipped = false; // État de la carte (Recto/Verso)

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  void _loadWords() {
    _wordBox = Hive.box<Word>('words');
    setState(() {
      if (widget.isCramMode && widget.customWords != null) {
        // Mode Révision Libre : on prend les mots passés en paramètre
        _dueWords = List.from(widget.customWords!);
      } else {
        // Mode SRS Classique
        _dueWords = _srsService.getDueWords(_wordBox.values.toList());
      }
      _dueWords.shuffle();
    });
  }

  void _handleResponse(int quality) {
    if (_currentIndex >= _dueWords.length) return;

    // 1. Mise à jour de l'algo SRS (que si c'est une vraie révision, pas en cram)
    if (!widget.isCramMode) {
      _srsService.processReview(_dueWords[_currentIndex], quality);
    }
    // 2. Animation vers la carte suivante
    setState(() {
      _isFlipped = false; // Remettre face visible
      _currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dueWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Quiz")),
        body: const Center(
          child: Text("🎉 Rien à réviser pour l'instant ! Reviens demain.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
        ),
      );
    }

    if (_currentIndex >= _dueWords.length) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text("Session terminée !", style: TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Retour à l'accueil"),
              )
            ],
          ),
        ),
      );
    }

    final currentWord = _dueWords[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
          title: Text("Quiz (${_currentIndex + 1}/${_dueWords.length})")),
      body: Column(
        children: [
          const SizedBox(height: 40),

          // --- ZONE FLASHCARD ---
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isFlipped = !_isFlipped;
                });
              },
              child: Center(
                child: _isFlipped
                    ? _buildCardBack(currentWord)
                    : _buildCardFront(currentWord),
              ),
            ),
          ),

          // --- ZONE BOUTONS (Visible seulement si retournée) ---
          Expanded(
            flex: 1,
            child: _isFlipped
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRatingBtn("Oublié", Colors.red, 0),
                      _buildRatingBtn("Dur", Colors.orange, 1),
                      _buildRatingBtn("Bien", Colors.blue, 2),
                      _buildRatingBtn("Facile", Colors.green, 3),
                    ],
                  )
                : const Center(
                    child: Text("Appuyez sur la carte pour voir la réponse")),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(Word word) {
    return _baseCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(word.chinese,
              style:
                  const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(word.pinyin,
              style: const TextStyle(fontSize: 24, color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildCardBack(Word word) {
    return _baseCard(
      color: Colors.blue[50], // Couleur légère pour différencier le dos
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(word.french,
              style: const TextStyle(fontSize: 28),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          const Text("(Chinois & Pinyin masqués)",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _baseCard({required Widget child, Color? color}) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: child,
    );
  }

  Widget _buildRatingBtn(String label, Color color, int quality) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onPressed: () => _handleResponse(quality),
      child: Text(label),
    );
  }
}
