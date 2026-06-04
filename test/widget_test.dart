import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mist/uis/android/ui_folder.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock the path_provider MethodChannel to return a temp directory
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  testWidgets('UiFolderScreen runs successfully and does not crash', (WidgetTester tester) async {
    // 1. Pump the UiFolderScreen inside a MaterialApp
    await tester.pumpWidget(
      const MaterialApp(
        home: UiFolderScreen(),
      ),
    );

    // 2. Allow the post-frame callback (checkPermissionAndInit) and async tasks to execute
    await tester.runAsync(() async {
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 500));
      await tester.pump();
    });

    // 3. Verify that UiFolderScreen builds successfully and does not crash during initialization
    expect(find.byType(UiFolderScreen), findsOneWidget);
  });
}
