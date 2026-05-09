import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ IMPORT DOTENV

class AiService {
  // ⚠️ Remplace par ta vraie clé API (commence par sk-...)
  final String _apiKey = dotenv.env['DEEPSEEK_API_KEY'] ?? '';
  static const String _baseUrl = "https://api.deepseek.com/chat/completions";

  Future<int> getUserHskLevel() async {
    final prefs = await SharedPreferences.getInstance();
    // Cherche le niveau sauvegardé. S'il n'y a rien (ex: l'utilisateur a passé l'étape),
    // on renvoie un niveau par défaut (ici 3).
    return prefs.getInt('user_hsk_level') ?? 3;
  }

  Future<String> getUserInterest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_interest') ?? "Vie quotidienne";
  }

  /// Analyse un mot : Traduction + Pinyin + Exemple
  Future<Map<String, String>> analyzeWord(String chineseWord) async {
    String interest = await getUserInterest();
    int hskLevel = await getUserHskLevel();
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              "model": "deepseek-chat",
              "messages": [
                {
                  "role": "system",
                  "content": """
              作为中文助教，对输入的词/短语，返回严格JSON对象，含： 
              - "translation": 法语翻译（简洁） 
              - "pinyin": 带声调拼音 
              - "example_cn": 中文例句（HSK $hskLevel 级, 题目：中国的$interest） 
              - "example_fr": 例句法语翻译
              """
                },
                {"role": "user", "content": "生词是：$chineseWord"}
              ],
              "response_format": {"type": "json_object"}, // Force le JSON
              "temperature": 0.3, // Créativité faible pour rester précis
              "max_tokens": 200
            }),
          )
          .timeout(const Duration(
              seconds: 15)); // <--- AJOUTE CECI À LA FIN DE CHAQUE HTTP.POST

      if (response.statusCode == 200) {
        // Décodage UTF-8 pour les caractères chinois
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];

        // Parsing du JSON renvoyé par l'IA
        final Map<String, dynamic> result = jsonDecode(content);

        return {
          'translation': result['translation']?.toString() ?? '',
          'pinyin': result['pinyin']?.toString() ?? '',
          'example_cn': result['example_cn']?.toString() ?? '',
          'example_fr': result['example_fr']?.toString() ?? '',
        }.cast<String, String>(); // <--- AJOUTE CECI
      } else {
        print("Erreur API : ${response.statusCode} - ${response.body}");
        return <String, String>{}; // <--- Ajoute les types ici
      }
    } catch (e) {
      print("Exception AI Service : $e");
      return <String, String>{}; // <--- Ajoute les types ici
    }
  }

  /// Découpe une phrase chinoise en mots individuels
  Future<List<String>> segmentText(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              "model": "deepseek-chat",
              "messages": [
                {
                  "role": "system",
                  "content": "你是一个中文分词助手。用户输入的文本可能包含OCR识别错误或乱码。"
                      "任务：1. 提取文本中的有效中文句子。"
                      "2. 忽略拼音、英文和无关字符。"
                      "3. 将清洗后的句子切分为单词。"
                      "4. 仅输出JSON字符串数组。"
                      "示例输入: 'ni hao 你 好 hello'"
                      "示例输出: ['你', '好']"
                },
                {"role": "user", "content": text}
              ],
              "temperature": 0.1,
            }),
          )
          .timeout(const Duration(
              seconds: 15)); // <--- AJOUTE CECI À LA FIN DE CHAQUE HTTP.POST

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        final cleanJson = content
            .replaceAll(RegExp(r'```json\n?'), '')
            .replaceAll(RegExp(r'```\n?'), '')
            .trim();
        return List<String>.from(jsonDecode(cleanJson));
      }
      return [text]; // Fallback : renvoie la phrase entière
    } catch (e) {
      return [text];
    }
  }

  Future<Map<String, dynamic>?> generateContextQuiz(
      List<String> targetWords, int hskLevel, String interest) async {
    // 1. On prépare la liste de mots (nettoyée des espaces)
    final cleanedWords = targetWords.map((w) => w.trim()).toList();
    final wordsListStr = cleanedWords.join(', ');

    // 2. Le Prompt
    final prompt = """
作为中文老师，写一个HSK$hskLevel水平段落（3-4句），主题中国的$interest。必须用：[$wordsListStr]。不加拼音。
只返回JSON： 
{ 
"texte_chinois": "中文", 
"traduction_francaise": "法语翻译", 
"mots_manquants": ["按首次出现顺序的词语"] 
}""";

    try {
      final response = await http
          .post(
            Uri.parse(
                _baseUrl), // Assure-toi que _baseUrl est bien défini, ou remplace par 'https://api.deepseek.com/chat/completions'
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              "model": "deepseek-chat",
              "messages": [
                {
                  "role": "system",
                  "content": "You are a helpful JSON-only outputting assistant."
                },
                {"role": "user", "content": prompt}
              ],
              "response_format": {"type": "json_object"},
              "temperature": 0.7,
            }),
          )
          .timeout(const Duration(
              seconds: 15)); // <--- AJOUTE CECI À LA FIN DE CHAQUE HTTP.POST

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        final cleanJson = content
            .replaceAll(RegExp(r'```json\n?'), '')
            .replaceAll(RegExp(r'```\n?'), '')
            .trim();

        Map<String, dynamic> finalData = jsonDecode(cleanJson);
        String fullText = finalData['texte_chinois'] ?? "";

        List<dynamic> missingWordsDynamic = finalData['mots_manquants'] ?? [];
        List<String> missingWords =
            missingWordsDynamic.map((e) => e.toString().trim()).toList();

        for (String word in missingWords) {
          if (word.isNotEmpty) {
            fullText = fullText.replaceFirst(word, '___');
          }
        }

        finalData['texte_chinois'] = fullText;
        return finalData;
      } else {
        print("Erreur DeepSeek: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // <--- L'accolade manquante était juste avant cette ligne !
      print("Exception API: $e");
      return null;
    }
  }
}
