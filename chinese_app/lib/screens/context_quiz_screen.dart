import 'package:flutter/material.dart';

class ContextQuizScreen extends StatefulWidget {
  final Map<String, dynamic> quizData;

  const ContextQuizScreen({super.key, required this.quizData});

  @override
  State<ContextQuizScreen> createState() => _ContextQuizScreenState();
}

class _ContextQuizScreenState extends State<ContextQuizScreen> {
  late List<String> _textParts; // Les morceaux de la phrase
  late List<String> _correctAnswers; // La vraie solution

  List<String> _availableWords = []; // Les mots que le joueur peut glisser
  Map<int, String> _userAnswers =
      {}; // Les trous remplis par le joueur (index du trou -> Mot)

  bool _isSubmitted = false;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    String chineseText = widget.quizData['texte_chinois'] ?? "";

    // On découpe le texte autour des "___"
    _textParts = chineseText.split('___');

    // On récupère les mots manquants et on les mélange pour le jeu
    _correctAnswers = List<String>.from(widget.quizData['mots_manquants']);
    _availableWords = List.from(_correctAnswers)..shuffle();
  }

  // Permet de retirer un mot d'un trou pour le remettre dans la banque
  void _removeWordFromBlank(int blankIndex) {
    if (_isSubmitted || !_userAnswers.containsKey(blankIndex)) return;

    setState(() {
      _availableWords.add(_userAnswers[blankIndex]!);
      _userAnswers.remove(blankIndex);
    });
  }

  // Remplit automatiquement le premier trou vide quand on clique sur un mot
  void _autoFillWord(String word) {
    for (int i = 0; i < _textParts.length - 1; i++) {
      if (!_userAnswers.containsKey(i)) {
        setState(() {
          _userAnswers[i] = word;
          _availableWords.remove(word);
        });
        break; // On s'arrête après avoir rempli un trou
      }
    }
  }

  void _checkAnswers() {
    setState(() {
      _isSubmitted = true;
    });
  }

  void _retryWrongAnswers() {
    setState(() {
      _isSubmitted = false;
      List<int> keysToRemove = [];

      // On vérifie chaque réponse
      _userAnswers.forEach((index, word) {
        if (word != _correctAnswers[index]) {
          // Si c'est faux, on remet le mot dans la banque en bas
          _availableWords.add(word);
          keysToRemove.add(index);
        }
      });

      // On vide les trous qui étaient faux
      for (var k in keysToRemove) {
        _userAnswers.remove(k);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isReadyToSubmit =
        _userAnswers.length == _correctAnswers.length && !_isSubmitted;

    // Calcul du score si soumis
    int score = 0;
    if (_isSubmitted) {
      for (int i = 0; i < _correctAnswers.length; i++) {
        if (_userAnswers[i] == _correctAnswers[i]) score++;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Texte à trous")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Complétez l'histoire :",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- LA PHRASE À TROUS (Utilisation de RichText) ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 22,
                      color: Colors.black,
                      height: 2.0), // height gère l'espacement des lignes
                  children: _buildInlineSpans(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // --- TRADUCTION & FEEDBACK ---
            if (_isSubmitted)
              Container(
                padding: const EdgeInsets.all(12),
                color: score == _correctAnswers.length
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                child: Text(
                  "Score : $score / ${_correctAnswers.length}",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: score == _correctAnswers.length
                          ? Colors.green
                          : Colors.orange.shade800),
                  textAlign: TextAlign.center,
                ),
              ),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(
                    _showTranslation ? Icons.visibility_off : Icons.translate),
                label: Text(_showTranslation
                    ? "Masquer la traduction"
                    : "Voir la traduction"),
                onPressed: () =>
                    setState(() => _showTranslation = !_showTranslation),
              ),
            ),
            if (_showTranslation)
              Text(
                widget.quizData['traduction_francaise'] ?? "",
                style: const TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey),
              ),

            const Spacer(),

            // --- BANQUE DE MOTS ---
            if (!_isSubmitted) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _availableWords.map((word) {
                  return Draggable<String>(
                    data: word,
                    feedback: Material(
                        color: Colors.transparent,
                        child: _buildWordChip(word, isDragging: true)),
                    childWhenDragging:
                        Opacity(opacity: 0.3, child: _buildWordChip(word)),
                    child: GestureDetector(
                      onTap: () => _autoFillWord(word), // Le clic magique !
                      child: _buildWordChip(word),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // --- BOUTON DE VALIDATION ---
            if (_isSubmitted)
              Row(
                children: [
                  if (score < _correctAnswers.length) // S'il y a des erreurs
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _retryWrongAnswers,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Réessayer"),
                      ),
                    ),
                  if (score < _correctAnswers.length) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Terminer"),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isReadyToSubmit ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: isReadyToSubmit ? _checkAnswers : null,
                child: const Text("Vérifier"),
              ),
          ],
        ),
      ),
    );
  }

// --- CONSTRUCTION INLINE POUR NE PAS CASSER LES LIGNES ---
  List<InlineSpan> _buildInlineSpans() {
    List<InlineSpan> spans = [];

    for (int i = 0; i < _textParts.length; i++) {
      if (_textParts[i].isNotEmpty) {
        spans.add(TextSpan(text: _textParts[i]));
      }

      if (i < _textParts.length - 1) {
        bool hasWord = _userAnswers.containsKey(i);
        String? word = _userAnswers[i];

        bool isCorrect = _isSubmitted && word == _correctAnswers[i];
        bool isWrong = _isSubmitted && !isCorrect;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: DragTarget<String>(
              // 1. PERMISSION EXPLICITE D'ACCEPTER LE MOT
              onWillAccept: (data) =>
                  true, // See if we need to switch to onWillAcceptWithDetails?

              // 2. ACTION QUAND ON LÂCHE LE MOT
              onAccept: (data) {
                // See if we need to switch to onAcceptWithDetails?
                setState(() {
                  // Si le trou était déjà plein, on remet l'ancien mot dans la banque
                  if (_userAnswers.containsKey(i)) {
                    _availableWords.add(_userAnswers[i]!);
                  }
                  _userAnswers[i] = data;
                  _availableWords.remove(data);
                });
              },

              // 3. CONSTRUCTION VISUELLE
              builder: (context, candidateData, rejectedData) {
                // candidateData n'est pas vide quand on survole le trou avec le doigt !
                bool isHovered = candidateData.isNotEmpty;

                return GestureDetector(
                  onTap: () =>
                      _removeWordFromBlank(i), // Clic pour vider le trou
                  child: Container(
                    // FORCER UNE TAILLE MINIMUM POUR LES DOIGTS (Hitbox)
                    constraints:
                        const BoxConstraints(minWidth: 70, minHeight: 35),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.shade100
                          : isWrong
                              ? Colors.red.shade100
                              : isHovered
                                  ? Colors.blue
                                      .shade100 // S'illumine quand on passe dessus
                                  : hasWord
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade200,
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : isHovered
                                    ? Colors.blue // Bordure bleue au survol
                                    : Colors.grey.shade400,
                        width: isHovered || hasWord ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasWord ? word! : "      ",
                      style: TextStyle(
                        fontSize: 20,
                        color: isCorrect
                            ? Colors.green.shade800
                            : isWrong
                                ? Colors.red.shade800
                                : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    return spans;
  }

  // UI pour les étiquettes de mots
  Widget _buildWordChip(String word, {bool isDragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDragging ? Colors.blueAccent : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDragging
            ? [const BoxShadow(color: Colors.black26, blurRadius: 8)]
            : [],
      ),
      child: Text(
        word,
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDragging ? Colors.white : Colors.blue.shade900),
      ),
    );
  }
}
