import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/logic/navigation_cubit.dart';
import 'package:mist/logic/folder_cubit.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/tasks_cubit.dart';
import 'package:mist/uis/android/ui_home.dart';
import 'package:mist/uis/android/widgets/image_canvas_widget.dart';
import 'package:mist/uis/android/widgets/text_canvas_widget.dart';
import 'package:alarm/alarm.dart';
import 'package:feedback/feedback.dart';

@pragma('vm:entry-point')
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Alarm.init();

  // Register all canvas widget types for serialisation/deserialisation.
  TextCanvasWidgetData.register();
  ImageCanvasWidgetData.register();
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
      child: MultiBlocProvider(
        providers: [
          BlocProvider<NavigationCubit>(
            create: (context) => NavigationCubit(),
          ),
          BlocProvider<FolderCubit>(
            create: (context) => FolderCubit(),
          ),
          BlocProvider<AlarmsCubit>(
            create: (context) => AlarmsCubit()..getData(),
          ),
          BlocProvider<TasksCubit>(
            create: (context) => TasksCubit(),
          ),
        ],
        child: const MainApp(),
      ),
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
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(control: true, LogicalKeyboardKey.keyS):
            VoidCallbackIntent(() {}),
      },
      theme: ThemeData.dark(),
      home: const UIHome(),
    );
  }
}
