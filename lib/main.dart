import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/splash_screen.dart';
import '/dashboard_screen.dart';
import 'api_service.dart';
import 'job_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  final apiService = ApiService();

  runApp(TeleoneVoiceAnalyzerApp(
    prefs: prefs,
    apiService: apiService,
  ));
}

class TeleoneVoiceAnalyzerApp extends StatelessWidget {
  final SharedPreferences prefs;
  final ApiService apiService;

  const TeleoneVoiceAnalyzerApp({
    Key? key,
    required this.prefs,
    required this.apiService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JobModel()),
        Provider.value(value: apiService),
        Provider.value(value: prefs),
      ],
      child: MaterialApp(
        title: 'Voice Analyzer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF4F46E5),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: const Color(0xFFF9FAFB),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1F2937),
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}