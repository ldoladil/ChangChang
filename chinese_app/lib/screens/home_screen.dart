import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chinese_app/models/word.dart';
import 'package:chinese_app/screens/add_word_screen.dart';
import 'package:chinese_app/screens/scan_screen.dart';
import 'package:chinese_app/screens/quiz_setup_screen.dart';
import 'package:chinese_app/screens/settings_screen.dart';
import 'package:chinese_app/services/premium_services.dart';
import 'package:chinese_app/widgets/floating_action_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedFilterTag;
  int _currentHskLevel = 3; // NOUVEAU : Variable pour l'affichage
  // ✨ NOUVEAU : Les variables d'état pour les yeux
  bool _hidePinyin = false;
  bool _hideFrench = false;

  @override
  void initState() {
    super.initState();
    // NOUVEAU : On charge le niveau silencieusement (plus de popup !)
    final settingsBox = Hive.box('settings');
    _currentHskLevel = settingsBox.get('user_hsk_level', defaultValue: 3);
  }

  // NOUVEAU : Fonction pour sauvegarder le choix quand on clique
  void _updateHskLevel(int level) {
    final settingsBox = Hive.box('settings');
    settingsBox.put('user_hsk_level', level);
    setState(() => _currentHskLevel = level);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Niveau HSK $level enregistré !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wordsBox = Hive.box<Word>('words');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chang Chang',
          style: GoogleFonts.notoSansSc(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1a73e8),
        elevation: 4,
        actions: [
          // BOUTON OEIL : PINYIN
          IconButton(
            icon: Icon(_hidePinyin ? Icons.visibility_off : Icons.visibility),
            color: _hidePinyin ? Colors.white54 : Colors.white,
            tooltip: _hidePinyin ? 'Afficher Pinyin' : 'Masquer Pinyin',
            onPressed: () {
              setState(() => _hidePinyin = !_hidePinyin);
            },
          ),
          // BOUTON OEIL : FRANÇAIS
          IconButton(
            icon: Icon(_hideFrench ? Icons.visibility_off : Icons.visibility),
            color: _hideFrench ? Colors.white54 : Colors.white,
            tooltip: _hideFrench ? 'Afficher Français' : 'Masquer Français',
            onPressed: () {
              setState(() => _hideFrench = !_hideFrench);
            },
          ),
          // BOUTON PARAMETRES
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Paramètres',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          // BOUTON PARAMETRES

          IconButton(
            icon: const Icon(Icons.school, size: 28),
            tooltip: 'Lancer les révisions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuizSetupScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: wordsBox.listenable(),
        builder: (context, Box<Word> box, child) {
          var words = box.values.toList();
          if (_selectedFilterTag != null) {
            words = words
                .where((w) => w.tags.contains(_selectedFilterTag))
                .toList();
          }
          words.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final allTags = _getAllTags(box);

          return SingleChildScrollView(
            child: Column(
              children: [
                // ✅ HORSE IMAGE & WELCOME SECTION (Centré avec choix HSK)
                if (words.isEmpty)
                  Container(
                    width: double.infinity, // Force à prendre toute la largeur
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Centre verticalement
                      crossAxisAlignment:
                          CrossAxisAlignment.center, // Centre horizontalement
                      children: [
                        // L'image du cheval
                        Image.asset(
                          'assets/images/horse.jpg', // Vérifie si c'est .png ou .jpg chez toi
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 24),

                        // Le texte de bienvenue
                        Text(
                          'Enflammer votre apprentissage du chinois 🔥',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1a73e8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ajoutez vos premiers mots pour commencer votre voyage linguistique.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansSc(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 48), // Grand espace avant le HSK

                        // --- LA SÉLECTION DU NIVEAU HSK ---
                        Text(
                          'Quel est votre niveau actuel ?',
                          style: GoogleFonts.notoSansSc(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center, // Centre les puces
                          children: List.generate(6, (index) {
                            final level = index + 1;
                            return ChoiceChip(
                              label: Text('HSK $level',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              selected: _currentHskLevel == level,
                              selectedColor: Colors.orange.shade200,
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (selected) {
                                if (selected) _updateHskLevel(level);
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                // ✅ TAG FILTER SECTION
                if (words.isNotEmpty && allTags.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: _buildTagChips(allTags),
                    ),
                  ),

                // ✅ WORD LIST
                if (words.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: 80,
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    itemCount: words.length,
                    itemBuilder: (context, listIndex) {
                      final word = words[listIndex];

                      return Dismissible(
                        key: ValueKey(word.createdAt.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          word.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mot supprimé'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: _buildWordCard(word),
                      );
                    },
                  ),

                // ✅ EMPTY STATE (no words with this filter)
                if (words.isEmpty && !box.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(Icons.filter_list,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Aucun mot ne correspond à ce filtre'),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        backgroundColor: const Color(0xFF1a73e8),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  List<Widget> _buildTagChips(List<String> allTags) {
    const int maxVisibleTags = 10;
    final visibleTags = allTags.take(maxVisibleTags).toList();
    final hasMore = allTags.length > maxVisibleTags;
    final remainingCount = allTags.length - maxVisibleTags;

    return [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: const Text('Tout'),
          selected: _selectedFilterTag == null,
          onSelected: (selected) {
            setState(() => _selectedFilterTag = null);
          },
        ),
      ),
      ...visibleTags.map((tag) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(tag,
                style: const TextStyle(fontSize: 13)), // Police plus petite
            selected: _selectedFilterTag == tag,
            visualDensity: VisualDensity.compact, // Écrase la hauteur
            padding: EdgeInsets.zero,
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: -2),
            showCheckmark: false, // Enlève la grosse coche
            selectedColor: Colors.blue.shade100,
            onSelected: (selected) {
              setState(() => _selectedFilterTag = selected ? tag : null);
            },
          ),
        );
      }),
      if (hasMore)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text('+ $remainingCount'),
            selected: false,
            onSelected: (selected) {
              _showAllTagsModal(allTags);
            },
          ),
        ),
    ];
  }

  void _showAllTagsModal(List<String> allTags) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tous les tags (${allTags.length})',
                  style: GoogleFonts.notoSansSc(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    final isSelected = _selectedFilterTag == tag;
                    return ChoiceChip(
                      label: Text(tag),
                      selected: isSelected,
                      selectedColor: Colors.orange.shade200,
                      onSelected: (selected) {
                        setState(
                          () => _selectedFilterTag = selected ? tag : null,
                        );
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _selectedFilterTag = null);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Afficher tous les mots'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getAllTags(Box<Word> box) {
    final Set<String> tags = {};
    for (var word in box.values.take(1000)) {
      tags.addAll(word.tags);
      if (tags.length > 50) break;
    }
    return tags.toList()..sort();
  }

  Widget _buildWordCard(Word word) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddWordScreen(wordToEdit: word),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Aligne tout en haut
            children: [
              // --- COLONNE 1 : Hanzi (Chinois) ---
              Expanded(
                flex: 2,
                child: Text(
                  word.chinese,
                  style: const TextStyle(
                      fontSize: 26, // Un peu plus petit pour tenir en colonne
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),

              const SizedBox(width: 8), // Petit espace

              // --- COLONNE 2 : Pinyin ---
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(
                      top:
                          6.0), // Pour s'aligner visuellement avec le centre du chinois
                  child: Text(
                    // ✨ MODIF : Condition pour cacher
                    _hidePinyin ? '••••••' : word.pinyin,
                    style: TextStyle(
                        fontSize: 15,
                        // On grise un peu les points quand c'est caché pour faire propre
                        color: _hidePinyin
                            ? Colors.grey.shade400
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // --- COLONNE 3 : Français & Tags ---
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // ✨ MODIF : Condition pour cacher
                        _hideFrench ? '••••••••' : word.french,
                        style: TextStyle(
                            fontSize: 14,
                            color: _hideFrench
                                ? Colors.grey.shade400
                                : Colors.black87),
                      ),
                      // Les Tags juste en dessous
                      if (word.tags.isNotEmpty && !_hideFrench) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: word.tags
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.grey.shade300)),
                                    child: Text(tag,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black54)),
                                  ))
                              .toList(),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ajouter du vocabulaire',
                  style: GoogleFonts.notoSansSc(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Bouton Saisie Manuelle
              _buildActionOption(
                icon: Icons.edit_outlined,
                color: Colors.orange.shade600,
                title: 'Saisie manuelle',
                subtitle: 'Tapez les caractères',
                onTap: () {
                  Navigator.pop(context); // Ferme le menu
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddWordScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Bouton Scanner (AVEC SÉCURITÉ PREMIUM)
              _buildActionOption(
                icon: Icons.camera_alt_outlined,
                color: Colors.green.shade600,
                title: 'Scanner du texte',
                subtitle: 'Prenez une photo',
                onTap: () async {
                  Navigator.pop(context); // Ferme le menu

                  bool canScan = await PremiumService().canUserScan();
                  if (canScan) {
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScanScreen()),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      PremiumService()
                          .showPaywallDialog(context, "Scans illimités");
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- LE DESIGN DES BOUTONS DU MENU ---
  Widget _buildActionOption(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.3), width: 1.5)),
      leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 28)),
      title: Text(title,
          style: GoogleFonts.notoSansSc(
              fontSize: 18, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: GoogleFonts.notoSansSc(fontSize: 14, color: Colors.grey[600]),
          maxLines: 2),
      onTap: onTap,
    );
  }
}
