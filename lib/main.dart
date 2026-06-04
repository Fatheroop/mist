import 'package:flutter/material.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/uis/android/ui_home.dart';
import 'package:alarm/alarm.dart';
import 'package:feedback/feedback.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();
  runApp(
    BetterFeedback(
      theme: FeedbackThemeData(
        background: Colors.black.withValues(alpha: 0.6),
        feedbackSheetColor: const Color(0xFF131324), // deep elegant dark slate
        activeFeedbackModeColor: Colors.indigoAccent,
        dragHandleColor: Colors.white24,
        brightness: Brightness.dark,
        sheetIsDraggable: true,
        drawColors: [
          const Color(0xFFFF6B6B),
          const Color(0xFFFFB347),
          Colors.tealAccent,
          Colors.indigoAccent,
          Colors.pink,
          Colors.amber,
          Colors.white,
        ],
        bottomSheetDescriptionStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        bottomSheetTextInputStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
        ),
      ),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: Unviersalvariables().navigatorKey,
      debugShowCheckedModeBanner: false,
      // showPerformanceOverlay: true,
      theme: ThemeData.dark(),
      home: const UIHome(),
    );
  }
}
