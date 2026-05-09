import 'package:hive_flutter/hive_flutter.dart';

part 'word.g.dart';

@HiveType(typeId: 0)
class Word extends HiveObject {
  @HiveField(0)
  final String chinese;

  @HiveField(1)
  final String french;

  @HiveField(2)
  final DateTime createdAt;

  // 🔑 SRS basique : prochaine révision + stabilité
  @HiveField(3)
  DateTime nextReview;

  @HiveField(4)
  int interval; // L'intervalle actuel en jours

  @HiveField(5)
  final String pinyin;

  @HiveField(6)
  List<String> tags;

  @HiveField(7)
  final String exampleCn;

  @HiveField(8)
  final String exampleFr;

  @HiveField(9)
  double easeFactor; // Facilité (standard SM-2 algorithm : commence à 2.5)

  Word({
    required this.chinese,
    required this.french,
    this.pinyin =
        '', // Valeur par défaut pour éviter les crashs sur les vieux mots
    this.tags = const [], // Liste vide par défaut
    this.exampleCn = '',
    this.exampleFr = '',
    required this.createdAt,
    DateTime? nextReview,
    this.interval = 0,
    this.easeFactor = 2.5,
  }) : nextReview = nextReview ?? DateTime.now();
}
