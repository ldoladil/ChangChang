import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  int _currentHskLevel = 3;
  String _currentInterest = "Vie quotidienne";

  final List<String> _interestsList = [
    "Vie quotidienne",
    "Voyage",
    "Business",
    "Musique/Cinéma",
    "Tech",
    "Histoire"
  ];

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentHskLevel = _prefs.getInt('user_hsk_level') ?? 3;
        _currentInterest =
            _prefs.getString('user_interest') ?? "Vie quotidienne";
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur chargement paramètres: $e")),
        );
      }
    }
  }

  Future<void> _updateHskLevel(int level) async {
    try {
      await _prefs.setInt('user_hsk_level', level);
      setState(() => _currentHskLevel = level);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Niveau HSK $level mis à jour !")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  Future<void> _updateInterest(String interest) async {
    try {
      await _prefs.setString('user_interest', interest);
      setState(() => _currentInterest = interest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Centre d'intérêt mis à jour : $interest")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- NIVEAU HSK ---
          const Text("Niveau d'apprentissage",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
              "Ce niveau est utilisé par l'IA pour générer les phrases de contexte.",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(6, (index) {
              int level = index + 1;
              return ChoiceChip(
                label: Text("HSK $level"),
                selected: _currentHskLevel == level,
                selectedColor: Colors.orangeAccent,
                onSelected: (selected) {
                  if (selected) _updateHskLevel(level);
                },
              );
            }),
          ),

          const SizedBox(height: 40),

          // --- CENTRES D'INTÉRÊT ---
          const Text("Centres d'intérêt",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _interestsList.map((interest) {
              return ChoiceChip(
                label: Text(interest),
                selected: _currentInterest == interest,
                onSelected: (selected) {
                  if (selected) _updateInterest(interest);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 40),
          const Divider(), // Une petite ligne de séparation élégante
          const SizedBox(height: 10),

          // --- SECTION LÉGALE ---
          const Text("Légal",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // ✨ LE BOUTON POLITIQUE DE CONFIDENTIALITÉ
          ListTile(
            contentPadding:
                EdgeInsets.zero, // Aligne l'icône avec les textes au-dessus
            leading:
                const Icon(Icons.privacy_tip_outlined, color: Colors.blueGrey),
            title: const Text("Politique de confidentialité"),
            trailing: const Icon(Icons.open_in_new,
                size: 16, color: Colors.grey), // Petite icône "lien externe"
            onTap: () async {
              // ⚠️ N'oublie pas de coller ton vrai lien ici !
              final Uri url = Uri.parse(
                  'https://www.notion.so/Politique-de-Confidentialit-de-l-application-Chang-Chang-22a40cfc7b8980048a05e139c2a2f27a?source=copy_link');

              try {
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Impossible d'ouvrir le lien")),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Erreur lors de l'ouverture du lien")),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
