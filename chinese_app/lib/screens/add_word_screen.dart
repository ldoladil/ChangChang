import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lpinyin/lpinyin.dart';
import '../models/word.dart';
import '../services/ai_service.dart'; // ✅ Import Service IA
import 'dart:async';

class AddWordScreen extends StatefulWidget {
  final String? prefilledChinese;
  final String? prefilledPinyin;
  final String? prefilledTranslation;
  final String? prefilledExampleCn; // ✅ Nouveau
  final String? prefilledExampleFr; // ✅ Nouveau

  final Word? wordToEdit;
  final int? index;

  const AddWordScreen({
    super.key,
    this.prefilledChinese,
    this.prefilledPinyin,
    this.prefilledTranslation,
    this.prefilledExampleCn,
    this.prefilledExampleFr,
    this.wordToEdit,
    this.index,
  });

  factory AddWordScreen.prefilled({
    required String chinese,
    String? pinyin,
    String? translation,
    String? exampleCn,
    String? exampleFr,
  }) {
    return AddWordScreen(
      prefilledChinese: chinese,
      prefilledPinyin: pinyin,
      prefilledTranslation: translation,
      prefilledExampleCn: exampleCn,
      prefilledExampleFr: exampleFr,
    );
  }

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  late Box<Word> _wordBox;
  late final TextEditingController _chineseController;
  late final TextEditingController _pinyinController;
  late final TextEditingController _frenchController;
  late final TextEditingController _exCnController; // ✅
  late final TextEditingController _exFrController; // ✅

  final _formKey = GlobalKey<FormState>();
  final AiService _aiService = AiService(); // ✅ Instance du service
  bool _isLoadingAi = false; // Pour le petit spinner

  List<String> _selectedTags = [];
  List<String> _availableTags = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _wordBox = Hive.box<Word>('words'); // Ensure box is open
    // Initialisation des contrôleurs (Code existant + Nouveaux champs)
    if (widget.wordToEdit != null) {
      _chineseController =
          TextEditingController(text: widget.wordToEdit!.chinese);
      _pinyinController =
          TextEditingController(text: widget.wordToEdit!.pinyin);
      _frenchController =
          TextEditingController(text: widget.wordToEdit!.french);
      _exCnController =
          TextEditingController(text: widget.wordToEdit!.exampleCn);
      _exFrController =
          TextEditingController(text: widget.wordToEdit!.exampleFr);
      _selectedTags = List.from(widget.wordToEdit!.tags);
    } else {
      _chineseController =
          TextEditingController(text: widget.prefilledChinese ?? '');
      _pinyinController =
          TextEditingController(text: widget.prefilledPinyin ?? '');
      _frenchController =
          TextEditingController(text: widget.prefilledTranslation ?? '');
      _exCnController =
          TextEditingController(text: widget.prefilledExampleCn ?? '');
      _exFrController =
          TextEditingController(text: widget.prefilledExampleFr ?? '');
    }
    _loadAvailableTags();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _chineseController.dispose();
    _pinyinController.dispose();
    _frenchController.dispose();
    _exCnController.dispose();
    _exFrController.dispose();
    super.dispose();
  }

  // ... (Garde _loadAvailableTags, _onChineseChanged, _addNewTag identiques à avant) ...
  void _loadAvailableTags() {
    final settingsBox = Hive.box('settings');
    _availableTags = settingsBox.get('tags', defaultValue: <String>[
      'Général',
      'Nourriture',
      'Verbe'
    ]).cast<String>();
    setState(() {});
  }

  void _onChineseChanged(String text) {
    // Si l'utilisateur tape une nouvelle lettre avant la fin des 500ms, on annule le chrono
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    // On relance un nouveau chrono de 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (text.trim().isNotEmpty) {
        String pinyin = PinyinHelper.getPinyin(text,
            separator: " ", format: PinyinFormat.WITH_TONE_MARK);
        setState(() {
          // <--- AJOUTE CECI
          _pinyinController.text = pinyin;
        });
      } else {
        setState(() {
          // <--- ET CECI
          _pinyinController.clear();
        });
      }
    });
  }

  // --- FONCTION MAGIQUE IA ---
  Future<void> _enrichWithAi() async {
    final text = _chineseController.text.trim();

    _debounce?.cancel(); // <--- AJOUT : On coupe le debounce du clavier !

    if (text.isEmpty) {
      _showErrorSnackBar("Veuillez entrer d'abord du texte");
      return;
    }

    // Prevent double-tap
    if (_isLoadingAi) return;

    setState(() => _isLoadingAi = true);

    try {
      // Add timeout to prevent hanging
      final result = await _aiService.analyzeWord(text).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('AI service timeout'),
          );

      if (!mounted) return;

      // Validate result structure before accessing
      if (result.isEmpty) {
        _showErrorSnackBar("Impossible d'enrichir. Vérifiez votre connexion.");
        return;
      }

      setState(() {
        // On remplace seulement le pinyin s'il n'a pas été généré
        if (_pinyinController.text.isEmpty) {
          _pinyinController.text = result['pinyin']?.toString() ?? '';
        }
        // On remplace systématiquement les autres champs
        _frenchController.text = result['translation']?.toString() ?? '';
        _exCnController.text = result['example_cn']?.toString() ?? '';
        _exFrController.text = result['example_fr']?.toString() ?? '';
      });
    } on TimeoutException {
      if (mounted) _showErrorSnackBar("Délai d'attente dépassé. Réessayez.");
    } catch (e) {
      print("AI enrichment error: $e");
      if (mounted) _showErrorSnackBar("Erreur lors de l'enrichissement");
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  // Helper for consistent error messaging
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _saveWord() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final word = Word(
        chinese: _chineseController.text.trim(),
        pinyin: _pinyinController.text.trim(),
        french: _frenchController.text.trim(),
        tags: _selectedTags,
        createdAt: widget.wordToEdit?.createdAt ?? DateTime.now(),
        nextReview: widget.wordToEdit?.nextReview,
        interval: widget.wordToEdit?.interval ?? 0,
        easeFactor: widget.wordToEdit?.easeFactor ?? 2.5,
        exampleCn: _exCnController.text.trim(), // ✅ Sauvegarde des exemples
        exampleFr: _exFrController.text.trim(),
      );
      await _wordBox.add(word);
      if (mounted) Navigator.pop(context, word);
    } catch (e) {
      print("Error saving word: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lors de la sauvegarde")),
      );
    }
  }

  // ... (Méthodes de tags _addNewTag et _showAddTagDialog restent identiques) ...
  // Rajoute ici les méthodes manquantes si tu as copié/collé trop vite,
  // sinon reprends-les de ton ancien fichier.

  void _addNewTag(String newTag) {
    if (newTag.trim().isEmpty) return;
    final tag = newTag.trim();
    if (!_availableTags.contains(tag)) {
      setState(() {
        _availableTags.add(tag);
        _selectedTags.add(tag);
      });
      Hive.box('settings').put('tags', _availableTags);
    }
  }

  void _showAddTagDialog() {
    // (Reprends le code de l'étape précédente pour le dialog)
    String newTagInput = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nouveau Tag"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: "Ex: HSK1"),
          onChanged: (v) => newTagInput = v,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")),
          ElevatedButton(
              onPressed: () {
                _addNewTag(newTagInput);
                Navigator.pop(context);
              },
              child: const Text("Créer"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.wordToEdit != null ? 'Modifier' : 'Nouveau mot')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // --- CHAMP CHINOIS AVEC BOUTON IA ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Caractères chinois', style: _labelStyle()),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: _chineseController,
                          decoration: _inputDecoration('Ex: 常常'),
                          // ✨ MODIF : Police native beaucoup plus grande (36) pour bien voir les traits !
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.bold),
                          onChanged: _onChineseChanged,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Champ obligatoire!';
                            }
                            final hasChineseChar =
                                RegExp(r'[\u4e00-\u9fa5]').hasMatch(value);
                            if (!hasChineseChar) {
                              return 'Utilisez des caractères chinois';
                            }
                            return null;
                          }),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // ✨ LE BOUTON MAGIQUE IA
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: IconButton.filled(
                    onPressed: _isLoadingAi ? null : _enrichWithAi,
                    icon: _isLoadingAi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    color: Colors.deepPurple,
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade100,
                        padding: const EdgeInsets.all(12)),
                    tooltip: "Enrichir avec l'IA",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- PINYIN ---
            Text('Pinyin', style: _labelStyle()),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pinyinController,
              decoration: _inputDecoration('Ex: chángcháng'),
              // ✨ MODIF : Police un peu plus grande
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            // --- TRADUCTION ---
            Text('Traduction', style: _labelStyle()),
            const SizedBox(height: 8),
            TextFormField(
              controller: _frenchController,
              decoration: _inputDecoration('Ex: souvent, fréquemment'),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vous devez fournir une traduction.';
                }
                if (value.length < 2) {
                  return 'La traduction est trop courte.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // --- EXEMPLE ---
            Text('Phrase d\'exemple (IA)', style: _labelStyle()),
            const SizedBox(height: 8),
            TextFormField(
              controller: _exCnController,
              decoration: _inputDecoration('Ex: 你好吗？'),
              maxLines: 2,
              // ✨ MODIF : Retour à la police native, taille ajustée
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _exFrController,
              decoration: _inputDecoration('Traduction de la phrase...'),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // --- TAGS (Miniaturisés) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tags', style: _labelStyle()),
                IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _showAddTagDialog),
              ],
            ),
            Wrap(
              spacing: 6.0, // Espace horizontal réduit
              runSpacing:
                  -8.0, // Espace vertical réduit pour les lignes suivantes
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag,
                      style:
                          const TextStyle(fontSize: 13)), // ✨ Texte plus petit
                  selected: isSelected,
                  visualDensity: VisualDensity
                      .compact, // ✨ Écrase la hauteur par défaut de Flutter
                  padding: EdgeInsets.zero, // ✨ Enlève le bourrage interne
                  labelPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: -2), // ✨ Rapproche le texte des bords
                  showCheckmark:
                      false, // ✨ Enlève la grosse coche (optionnel, plus esthétique)
                  selectedColor: Colors.blue.shade100,
                  onSelected: (s) => setState(() =>
                      s ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveWord,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a73e8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sauvegarder',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ MODIF : On enlève GoogleFonts pour revenir à une police système très nette
  TextStyle _labelStyle() => const TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87);

  InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14), // ✨ Ajuste l'espace intérieur des cases
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2)),
      filled: true,
      fillColor: Colors.grey[50]);
}
