import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:chinese_app/models/word.dart';
import 'package:chinese_app/screens/home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // CHARGE LA CLE API (avec gestion d'erreur)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found or invalid: $e");
  }

  // 🔑 INITIALISATION ASYNCHRONE OBLIGATOIRE
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 🔑 ENREGISTRE L'ADAPTATEUR AVANT TOUTE UTILISATION
  Hive.registerAdapter(WordAdapter());

  // 🔑 OUVRE LES BOÎTES
  try {
    await Hive.openBox<Word>('words');
    await Hive.openBox('settings');
  } catch (e) {
    print("Error opening Hive boxes: $e");
    // App will crash here if boxes can't open, but we want to know why
    rethrow;
  }

  // Catch unhandled errors globally
  FlutterError.onError = (FlutterErrorDetails details) {
    print("FlutterError: ${details.exception}");
    print("Stack: ${details.stack}");
  };

  runApp(const ChineseApp());
}

class ChineseApp extends StatelessWidget {
  const ChineseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chang Chang',
      theme: ThemeData(
        fontFamily: GoogleFonts.notoSansSc().fontFamily,
        colorScheme: ColorScheme.light(primary: const Color(0xFF1a73e8)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a73e8),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      // 🔴 ERROR HANDLER: Catch errors and show them instead of crashing
      builder: (context, child) {
        return MaterialApp(
          title: 'Chang Chang',
          theme: ThemeData(
            fontFamily: GoogleFonts.notoSansSc().fontFamily,
            colorScheme: ColorScheme.light(primary: const Color(0xFF1a73e8)),
          ),
          home: child,
          // Global error UI
          navigatorObservers: [_ErrorNavigatorObserver()],
        );
      },
      home: const HomeScreenWrapper(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      locale: const Locale('fr', 'FR'),
    );
  }
}

// Wrapper to catch errors in HomeScreen
class HomeScreenWrapper extends StatelessWidget {
  const HomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FutureBuilder(
            future: _initializeApp(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorScreen(error: snapshot.error.toString());
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              return const HomeScreen();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _initializeApp() async {
    // Ensure boxes are open
    if (!Hive.isBoxOpen('words')) {
      await Hive.openBox<Word>('words');
    }
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
  }
}

// Error display screen
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Erreur')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Une erreur s\'est produite'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }
}

// Navigator observer to catch navigation errors
class _ErrorNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    print('Navigator: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    print('Navigator: Popped ${route.settings.name}');
  }
}
