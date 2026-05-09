import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../models/word.dart';
import 'quiz_screen.dart';
import 'context_quiz_screen.dart';
import '../services/ai_service.dart';
import '../services/premium_services.dart';

enum QuizMode { srs, cram, context }

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  QuizMode _selectedMode = QuizMode.srs;
  final Set<String> _selectedTags = {};
  List<String> _allTags = [];
  late Box<Word> _wordBox;
  bool _isPremium = false;
  bool _isGeneratingQuiz = false;

  @override
  void initState() {
    super.initState();
    _wordBox = Hive.box<Word>('words');
    _extractAllTags();
    PremiumService()
        .isUserPremium()
        .then((val) => setState(() => _isPremium = val));
  }

  void _extractAllTags() {
    final tags = <String>{};
    for (var word in _wordBox.values) {
      tags.addAll(word.tags);
    }
    setState(() {
      _allTags = tags.toList()..sort();
    });
  }

  void _startQuiz() async {
    // 1. Filtrer les mots selon les tags choisis
    List<Word> targetWords = _wordBox.values.toList();
    if (_selectedTags.isNotEmpty) {
      targetWords = targetWords.where((w) {
        return w.tags.any((tag) => _selectedTags.contains(tag));
      }).toList();
    }

    if (targetWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun mot trouvé pour ces tags.")),
      );
      return;
    }

    // 2. Lancer le bon mode
    if (_selectedMode == QuizMode.srs) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const QuizScreen(isCramMode: false),
          ));
    } else if (_selectedMode == QuizMode.cram) {
      Navigator.push(
          context,
          MaterialPageRoute(
            // Il faudra adapter QuizScreen pour accepter une liste de mots spécifique
            builder: (_) =>
                QuizScreen(isCramMode: true, customWords: targetWords),
          ));
    } else if (_selectedMode == QuizMode.context) {
      _launchContextQuiz(targetWords);
    }
  }

  void _launchContextQuiz(List<Word> targetWords) async {
    // 1. VERRU ANTI-DOUBLE CLIC
    if (_isGeneratingQuiz) return;

    if (targetWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun mot disponible pour ce quiz")),
      );
      return;
    }

    setState(() {
      _isGeneratingQuiz = true;
    });

    targetWords.shuffle();
    final wordsToTest = targetWords.take(5).map((w) => w.chinese).toList();

    if (!mounted) {
      setState(() => _isGeneratingQuiz = false);
      return;
    }

    // 2. ON TRAQUE L'ÉTAT EXACT DU CERCLE
    bool isDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) =>
        isDialogVisible = false); // Passe à false s'il est fermé de force

    try {
      int hskLevel = await AiService().getUserHskLevel();
      String interest = await AiService().getUserInterest();

      final result = await AiService()
          .generateContextQuiz(wordsToTest, hskLevel, interest)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw TimeoutException('API call exceeded 30 seconds'),
          );

      if (!mounted) return;

      // 3. FERMETURE CIBLÉE DU CERCLE (rootNavigator)
      if (isDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (result != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContextQuizScreen(quizData: result),
          ),
        );
      } else {
        _showErrorDialog("Erreur de génération. Réessayez.");
      }
    } on TimeoutException {
      if (mounted && isDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showErrorDialog(
          "Délai d'attente dépassé (30s). Vérifiez votre connexion.");
    } catch (e) {
      if (mounted && isDialogVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      print("Context quiz error: $e");
      _showErrorDialog("Erreur lors de la génération IA");
    } finally {
      // 4. ON LIBÈRE LE VERROU DANS TOUS LES CAS
      if (mounted) {
        setState(() {
          _isGeneratingQuiz = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Erreur"),
        content: Text(message),
        actions: [
          ElevatedButton(
            // Ici un pop normal suffit car on est sûr d'être dans le bon contexte du dialogue
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configuration du Quiz")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- CHOIX DU MODE ---
          const Text("1. Choisir le mode",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                RadioListTile<QuizMode>(
                  title: const Text("Révision du jour (SRS)"),
                  subtitle:
                      const Text("L'algorithme choisit les mots à réviser."),
                  value: QuizMode.srs,
                  groupValue: _selectedMode,
                  onChanged: (val) => setState(() => _selectedMode = val!),
                ),
                RadioListTile<QuizMode>(
                  title: const Text("Révision Libre (Cramming)"),
                  subtitle:
                      const Text("Révisez sans affecter votre progression."),
                  value: QuizMode.cram,
                  groupValue: _selectedMode,
                  onChanged: (val) => setState(() => _selectedMode = val!),
                ),
                RadioListTile<QuizMode>(
                  title: Row(
                    children: [
                      const Text("Texte à trous "),
                      if (!_isPremium)
                        const Icon(Icons.workspace_premium,
                            color: Colors.amber, size: 18),
                    ],
                  ),
                  value: QuizMode.context,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    if (_isPremium) {
                      setState(() => _selectedMode = val!);
                    } else {
                      PremiumService()
                          .showPaywallDialog(context, "Quiz en Contexte (IA)");
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- FILTRES (Seulement si Cram ou Context) ---
          if (_selectedMode != QuizMode.srs) ...[
            const Text("2. Filtrer par Tags",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_allTags.isEmpty)
              const Text("Aucun tag disponible. Vous réviserez toute la liste.",
                  style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                children: _allTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
          ]
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _startQuiz,
            child:
                const Text("Démarrer le Quiz", style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
