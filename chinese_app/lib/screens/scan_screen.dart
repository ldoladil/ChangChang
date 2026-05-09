import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lpinyin/lpinyin.dart';

import '../services/ai_service.dart';
import '../services/ocr_service.dart';
import 'add_word_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final OcrService _ocrService = OcrService();
  final AiService _aiService = AiService();
  final ImagePicker _picker = ImagePicker();

  // --- NOUVEAU : GESTION DES BULLES ---
  List<String>? _currentSegments; // Stocke les mots analysés
  bool _showBubbles = true; // État du Toggle
  // ------------------------------------

  File? _imageFile;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    if (response.file != null) {
      _processPickedFile(response.file!);
    }
  }

// Capture de l'image et lancement du processus de scan

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (photo != null) _processPickedFile(photo);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erreur capture: $e")));
    }
  }

// La méthode _processPickedFile exécute l'OCR, le nettoyage, et l'affichage du dialogue d'édition.
// C'est ici que tout le flux de travail est orchestré.

  Future<void> _processPickedFile(XFile photo) async {
    // Create a temp file copy instead of direct reference
    final tempDir = Directory.systemTemp;
    final tempFile = File(
        '${tempDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      await File(photo.path).copy(tempFile.absolute.path);
      setState(() {
        _imageFile = tempFile;
        _isScanning = true;
        _currentSegments = null; // On reset les anciennes bulles
      });

      final recognizedText =
          await _ocrService.scanImageFull(tempFile.absolute.path);

      // ← CORRECTION : Validation SANS .confidence
      if (recognizedText.blocks.isEmpty) {
        throw Exception("Aucun texte détecté");
      }

      // Vérifie qu'on a du texte non-vide
      final totalText = recognizedText.blocks
          .map((b) => b.text.trim())
          .where((t) => t.isNotEmpty)
          .join();

      if (totalText.length < 3) {
        throw Exception("Texte trop court ou vide");
      }

      List<String> rawLines = [];
      for (var block in recognizedText.blocks) {
        rawLines.add(block.text.replaceAll('\n', ' '));
      }

      String buffer = "";
      List<String> finalLines = [];
      const maxBufferLength = 300; // Évite accumulation infinie

      for (String line in rawLines) {
        final isEndOfSentence = _isEndOfSentence(buffer);
        final wouldExceedMax = (buffer + line).length > maxBufferLength;

        if (buffer.isNotEmpty && !isEndOfSentence && !wouldExceedMax) {
          buffer += " " + line; // Ajoute un espace
        } else {
          if (buffer.isNotEmpty) finalLines.add(buffer);
          buffer = line;
        }
      }

      if (buffer.isNotEmpty) finalLines.add(buffer);

      String fullText = finalLines.join("\n");

      if (mounted) {
        setState(() => _isScanning = false);
      }

      if (fullText.trim().isNotEmpty && mounted) {
        _showEditorDialog(fullText);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun texte détecté.")));
      }
    } catch (e) {
      // Nettoyage en cas d'erreur
      if (tempFile.existsSync()) tempFile.deleteSync();

      // Débloquer l'UI et informer l'utilisateur
      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Erreur de scan : ${e.toString().replaceAll('Exception: ', '')}")));
      }
    }
  }

// Cette fonction, qui renvoie un booléen, cherche à déterminer si une ligne de texte se termine
// par un caractère de ponctuation indiquant la fin d'une phrase.
// C'est une méthode simple pour regrouper les lignes qui ont été coupées par l'oCR

  bool _isEndOfSentence(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;
    final lastChar = trimmed.characters.last;
    return ['。', '！', '？', '.', '!', '?'].contains(lastChar);
  }

// Nettoyage des caractères non chinois
  String? _cleanText(String input, {bool aggressive = false}) {
    String text = input.replaceAll('\n', ' ');

    if (aggressive) {
      // Pour l'affichage final (pas avant segmentation)
      text = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    } else {
      // Pour la segmentation – garde ponctuation + espaces
      text = text.replaceAll(RegExp(r'[^\u4e00-\u9fff，。？！；：\s]'), '');
    }

    if (text.trim().isEmpty) return null;
    return text.trim();
  }

// Affichage de la fenêtre d'édition du texte, pour raffiner l'output de l'OCR
// L'utilisateur peut modifier et corriger le texte scanné,
// avant de le segmenter via DeepSeek.

  void _showEditorDialog(String rawText) {
    final textPreClean = _cleanText(rawText) ?? rawText;
    final TextEditingController controller =
        TextEditingController(text: textPreClean);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Vérifier le texte"),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Texte chinois ici...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.trim().isNotEmpty) {
                _startSegmentation(controller.text);
              }
            },
            child: const Text("Analyser (IA)"),
          ),
        ],
      ),
    );
  }

// Segmentation du texte via l'IA, et affichage des bulles interactives

  void _startSegmentation(String textToSegment) async {
    final textChinois = _cleanText(textToSegment); // Non-agressif !
    if (textChinois == null) return;

    // 1. On utilise le loader de l'écran (ultra sécurisé) au lieu d'une popup !
    setState(() {
      _isScanning = true;
    });

    try {
      // 2. L'appel à l'IA
      final segments = await _aiService.segmentText(textChinois);

      if (segments.isEmpty) {
        throw Exception("Segmentation vide");
      }

      // 3. Succès : On retire le loader et on affiche les bulles
      if (mounted) {
        setState(() {
          _isScanning = false;
          _currentSegments = segments;
          _showBubbles = true;
        });
      }
    } catch (e) {
      print("Erreur IA Segmentation : $e");

      // 4. Erreur / Timeout : On retire le loader et on utilise le plan B
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Serveur IA occupé. Découpage basique activé.")),
        );
        setState(() {
          _isScanning = false;
          _currentSegments =
              textChinois.split('').where((c) => c.isNotEmpty).toList();
          _showBubbles = true;
        });
      }
    }
  }

// Lorsque l'utilisateur clique sur une bulle, on affiche un dialogue de confirmation,
// avec le mot chinois et son pinyin déterminé en local.

  Future<void> _processFinalWord(String word) async {
    String pinyin = PinyinHelper.getPinyin(word,
        separator: " ", format: PinyinFormat.WITH_TONE_MARK);
    await _showResultDialog(word, pinyin);
  }

  Future<void> _showResultDialog(String hanzi, String pinyin) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(hanzi,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 32)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pinyin,
                style: const TextStyle(fontSize: 18, color: Colors.blue)),
            const SizedBox(height: 16),
            const Text("Ajouter ce mot ?",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // On part vers le formulaire, les bulles resteront en mémoire au retour
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddWordScreen.prefilled(
                    chinese: hanzi,
                    pinyin: pinyin,
                  ),
                ),
              );
            },
            child: const Text("Continuer"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On vérifie si on doit afficher le panneau des bulles
    bool hasSegments = _currentSegments != null && _currentSegments!.isNotEmpty;
    bool displayPanel = hasSegments && _showBubbles;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // ----------------------------------------------------
          // 1. LE BOUTON TOGGLE (DANS L'APPBAR OU FLOTTANT)
          // ----------------------------------------------------
          if (hasSegments)
            IconButton(
              icon:
                  Icon(_showBubbles ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showBubbles = !_showBubbles;
                });
              },
            )
        ],
      ),
      backgroundColor: Colors.black,

      // Utilisation d'une Stack pour empiler Image -> Bulles -> Loader
      body: Stack(
        children: [
          // ------------------------------------
          // COUCHE 1 : L'IMAGE
          // ------------------------------------
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Only allow if image exists; don't suppress other gestures
                if (_imageFile != null) {
                  // Optional: show hint
                }
              },
              behavior:
                  HitTestBehavior.translucent, // ← Crucial: allows bubbling
              child: Center(
                child: _imageFile == null
                    ? const Text("Prenez une photo",
                        style: TextStyle(color: Colors.white70))
                    : Image.file(_imageFile!, fit: BoxFit.contain),
              ),
            ),
          ),

          // ------------------------------------
          // COUCHE 2 : LE PANNEAU DES BULLES (Persistent)
          // ------------------------------------
          if (displayPanel)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                // Limite la hauteur max à 40% de l'écran pour voir l'image
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black45)],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Mots détectés",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          // Petit bouton croix optionnel pour fermer définitivement
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 20, color: Colors.grey),
                            onPressed: () =>
                                setState(() => _currentSegments = null),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _currentSegments!
                            .map((word) => ActionChip(
                                  label: Text(word,
                                      style: const TextStyle(fontSize: 18)),
                                  onPressed: () => _processFinalWord(word),
                                ))
                            .toList(),
                      ),
                      // Espace pour ne pas être caché par le bouton caméra
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ),

          // ------------------------------------
          // COUCHE 3 : LOADER
          // ------------------------------------
          if (_isScanning)
            Container(
              color: Colors.black54,
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),

      // ------------------------------------
      // BOUTON CAMERA
      // ------------------------------------
      floatingActionButton: !_isScanning
          ? FloatingActionButton.extended(
              onPressed: () => _pickAndScan(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Scanner"),
              backgroundColor: Colors.blueAccent,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    // Cleanup image from disk
    if (_imageFile != null && _imageFile!.existsSync()) {
      try {
        _imageFile!.deleteSync();
      } catch (e) {
        print("Failed to delete temp image: $e");
      }
    }

    // Cleanup OCR service
    try {
      _ocrService.dispose();
    } catch (e) {
      print("Error disposing OCR service: $e");
    }

    super.dispose();
  }
}
