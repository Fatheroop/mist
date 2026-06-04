import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:alarm/alarm.dart';

import 'package:flutter/material.dart';
import 'package:mist/logic/alarmsetter.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/uis/android/ui_remainder_notification.dart';
import 'package:mist/uis/android/ui_alarm_notification.dart';
import 'package:mist/uis/android/widgets/alarms_and_settings.dart';
import 'package:path_provider/path_provider.dart';

class AlarmsAndSettings extends ChangeNotifier {
  static final AlarmsAndSettings instance = AlarmsAndSettings();

  List<Remainder> remainders = [];
  List<AlarmModal> alarms = [];
  Settingalarm settings = Settingalarm(vibrate: false);

  // Background countdown isolate tracking
  final Map<String, Isolate> activeIsolates = {};
  final Map<String, ReceivePort> activeReceivePorts = {};
  final Map<String, int> remainingSeconds = {};
  final Map<String, int> currentRepeatCounts = {};
  final Set<String> visibleNotifications = {};

  void startReminderIsolate(Remainder reminder) async {
    stopReminderIsolate(reminder.name);

    final receivePort = ReceivePort();
    activeReceivePorts[reminder.name] = receivePort;

    try {
      final isolate = await Isolate.spawn(
        _isolateRemainderTimer,
        receivePort.sendPort,
      );
      activeIsolates[reminder.name] = isolate;

      receivePort.listen((message) {
        if (message is SendPort) {
          SendPort childSendPort = message;
          childSendPort.send(reminder.durationSeconds);
        } else if (message is int) {
          remainingSeconds[reminder.name] = message;
          notifyListeners();

          if (message <= 0) {
            stopReminderIsolate(reminder.name);
            _triggerReminderNotification(reminder);
          }
        }
      });
    } catch (e) {
      debugPrint("Error spawning isolate in singleton: $e");
    }
  }

  void stopReminderIsolate(String name) {
    if (activeIsolates.containsKey(name)) {
      activeIsolates[name]?.kill(priority: Isolate.beforeNextEvent);
      activeIsolates.remove(name);
    }
    if (activeReceivePorts.containsKey(name)) {
      activeReceivePorts[name]?.close();
      activeReceivePorts.remove(name);
    }
    remainingSeconds.remove(name);
    notifyListeners();
  }

  void _triggerReminderNotification(Remainder reminder) {
    if (visibleNotifications.contains(reminder.name)) {
      return;
    }

    visibleNotifications.add(reminder.name);

    final context = Unviersalvariables().navigatorKey.currentContext;
    if (context == null) {
      debugPrint("Global context is null! Cannot push notification screen.");
      visibleNotifications.remove(reminder.name);
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => UiRemainderNotification(remainder: reminder),
          ),
        )
        .then((_) {
          visibleNotifications.remove(reminder.name);
          _handleRepeatCycle(reminder);
        });
  }

  void _handleRepeatCycle(Remainder reminder) {
    if (reminder.repeat == "Once") {
      reminder.isActive = false;
      updateRemainder(reminder);
    } else if (reminder.repeat == "Repeat X times") {
      int remaining =
          currentRepeatCounts[reminder.name] ?? reminder.repeatCount;
      remaining--;
      currentRepeatCounts[reminder.name] = remaining;

      if (remaining > 0) {
        startReminderIsolate(reminder);
      } else {
        reminder.isActive = false;
        updateRemainder(reminder);
        currentRepeatCounts.remove(reminder.name);
      }
    } else if (reminder.repeat == "Until Stopped") {
      startReminderIsolate(reminder);
    }
  }

  // In-memory list of custom audio names (mock files)
  Future<List<String>> customAudios() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String path = "${dir.path}/alarmsandremainder/";
    Directory customAudiosDir = Directory(path);
    if (!await customAudiosDir.exists()) {
      await customAudiosDir.create(recursive: true);
    }
    Stream<FileSystemEntity> files = customAudiosDir.list();
    List<String> audioNames = [];
    await for (var file in files) {
      if (file is File) {
        audioNames.add(file.path);
      }
    }
    return audioNames;
  }

  List<String> getDefaultAssetsAudio() {
    return [
      "assets/anime_message.mp3",
      "assets/bling_bang_bang_born.mp3",
      "assets/gangnam_style.mp3",
      "assets/hachimi.mp3",
      "assets/loud.mp3",
      "assets/moana_music_box.mp3",
      "assets/morning_alarm.mp3",
      "assets/pyscho.mp3",
      "assets/rooster_alarm.mp3",
      "assets/solo.mp3",
    ];
  }

  Future<void> getData() async {
    try {
      String path = (await getApplicationSupportDirectory()).path;
      File file = File("$path/alarms_and_settings.json");
      if (await file.exists()) {
        String json = await file.readAsString();
        if (json.trim().isEmpty) {
          await file.writeAsString(
            jsonEncode({
              'alarms': [],
              'remainders': [],
              'settings': Settingalarm(vibrate: true).toJson(),
            }),
          );
          json = await file.readAsString();
        }
        Map<String, dynamic> data = jsonDecode(json);
        alarms = (data['alarms'] as List<dynamic>? ?? [])
            .map((e) => AlarmModal.fromJson(e as Map<String, dynamic>))
            .toList();
        remainders = (data['remainders'] as List<dynamic>? ?? [])
            .map((e) => Remainder.fromJson(e as Map<String, dynamic>))
            .toList();
        settings = Settingalarm.fromJson(
          data['settings'] as Map<String, dynamic>? ?? {},
        );

        // Restore background timers if active and not already running
        for (var reminder in remainders) {
          if (reminder.isActive && !activeIsolates.containsKey(reminder.name)) {
            currentRepeatCounts[reminder.name] = reminder.repeatCount;
            startReminderIsolate(reminder);
          }
        }

        // Restore active alarms in native Alarm package to keep them in sync if not already scheduled
        for (var alarm in alarms) {
          if (alarm.isActive) {
            final uniqueId = Alarmsetter.instance.createuniqueid(alarm);
            final isScheduled = Alarm.scheduled.value.alarms.any(
              (a) => a.id == uniqueId,
            );

            // Check if it is currently ringing or showing in the UI to prevent interrupting it
            final isRingingLocally = Alarm.ringing.value.alarms.any(
              (a) => a.id == uniqueId,
            );
            final isScreenActive =
                UiAlarmNotification.active &&
                UiAlarmNotification.activeAlarmId == uniqueId;
            final isRingingNatively = await Alarm.isRinging(uniqueId);

            final isRingingOrActive =
                isRingingLocally || isScreenActive || isRingingNatively;

            if (!isScheduled && !isRingingOrActive) {
              await Alarmsetter.instance.setAlarm(alarm);
            }
          }
        }
      } else {
        await file.create(recursive: true);
        await file.writeAsString(
          jsonEncode({
            'alarms': [],
            'remainders': [],
            'settings': Settingalarm(vibrate: true).toJson(),
          }),
        );
      }
    } catch (e) {
      debugPrint("Error in getData: $e");
      if (e is FormatException) {
        try {
          String path = (await getApplicationSupportDirectory()).path;
          File file = File("$path/alarms_and_settings.json");
          await file.writeAsString(
            jsonEncode({
              'alarms': [],
              'remainders': [],
              'settings': Settingalarm(vibrate: true).toJson(),
            }),
          );
          alarms = [];
          remainders = [];
          settings = Settingalarm(vibrate: true);
        } catch (err) {
          debugPrint("Failed to reset corrupted storage file: $err");
        }
      }
    }
  }

  Future<void> saveData() async {
    try {
      String path = (await getApplicationSupportDirectory()).path;
      File file = File("$path/alarms_and_settings.json");
      await file.writeAsString(
        jsonEncode({
          'alarms': alarms.map((e) => e.toJson()).toList(),
          'remainders': remainders.map((e) => e.toJson()).toList(),
          'settings': settings.toJson(),
        }),
      );
    } catch (e) {
      debugPrint("Error in saveData: $e");
    }
  }

  Future<void> addAlarm(AlarmModal alarm) async {
    final baseTitle = alarm.title;
    bool check = alarms.any((element) => element.title == alarm.title);
    int i = 1;
    while (check) {
      alarm.title = "$baseTitle ($i)";
      i++;
      check = alarms.any((element) => element.title == alarm.title);
    }
    // Stop same time alarms natively first to prevent orphaned active alarms
    for (final element in alarms.where(
      (e) => e.time == alarm.time && e.period == alarm.period,
    )) {
      await Alarmsetter.instance.stopAlarm(element);
    }
    alarms.removeWhere(
      (element) => element.time == alarm.time && element.period == alarm.period,
    );
    alarms.add(alarm);
    if (alarm.isActive) {
      await Alarmsetter.instance.setAlarm(alarm);
    }
    await saveData();
    notifyListeners();
  }

  Future<void> removeAlarm(String title) async {
    final idx = alarms.indexWhere((element) => element.title == title);
    if (idx != -1) {
      final alarm = alarms[idx];
      await Alarmsetter.instance.stopAlarm(alarm);
      alarms.removeAt(idx);
      await saveData();
      notifyListeners();
    }
  }

  Future<void> updateAlarm(AlarmModal alarm, {String? oldTitle}) async {
    final searchTitle = oldTitle ?? alarm.title;
    final idx = alarms.indexWhere((element) => element.title == searchTitle);
    if (idx != -1) {
      final oldAlarm = alarms[idx];
      await Alarmsetter.instance.stopAlarm(oldAlarm);
      alarms[idx] = alarm;
      if (alarm.isActive) {
        await Alarmsetter.instance.setAlarm(alarm);
      }
      await saveData();
      notifyListeners();
    }
  }

  Future<void> addRemainder(Remainder remainder) async {
    bool check = remainders.any((element) => element.name == remainder.name);
    int i = 1;
    while (check) {
      remainder.name = "${remainder.name} ($i)";
      i++;
      check = remainders.any((element) => element.name == remainder.name);
    }
    remainders.add(remainder);
    await saveData();
    notifyListeners();
  }

  Future<void> removeRemainder(String name) async {
    stopReminderIsolate(name);
    currentRepeatCounts.remove(name);
    remainders.removeWhere((element) => element.name == name);
    await saveData();
    notifyListeners();
  }

  Future<void> updateRemainder(Remainder remainder, {String? oldName}) async {
    final searchName = oldName ?? remainder.name;
    final idx = remainders.indexWhere((element) => element.name == searchName);
    if (idx != -1) {
      if (oldName != null && oldName != remainder.name) {
        stopReminderIsolate(oldName);
        currentRepeatCounts.remove(oldName);
      }
      remainders[idx] = remainder;
      if (remainder.isActive) {
        if (!activeIsolates.containsKey(remainder.name)) {
          currentRepeatCounts[remainder.name] = remainder.repeatCount;
          startReminderIsolate(remainder);
        }
      }
      await saveData();
      notifyListeners();
    }
  }

  Future<void> toggleRemainder(Remainder reminder) async {
    reminder.isActive = !reminder.isActive;
    await updateRemainder(reminder);
    if (reminder.isActive) {
      currentRepeatCounts[reminder.name] = reminder.repeatCount;
      startReminderIsolate(reminder);
    } else {
      stopReminderIsolate(reminder.name);
      currentRepeatCounts.remove(reminder.name);
    }
  }

  Future<void> saveSettings(Settingalarm newSettings) async {
    settings = newSettings;
    await saveData();
    // Reschedule all active alarms to apply the new settings immediately
    for (final alarm in alarms) {
      if (alarm.isActive) {
        await Alarmsetter.instance.setAlarm(alarm);
      }
    }
    notifyListeners();
  }
}

// Top-level function for Dart Isolate countdown
void _isolateRemainderTimer(SendPort mainSendPort) {
  final childReceivePort = ReceivePort();
  mainSendPort.send(childReceivePort.sendPort);

  childReceivePort.listen((message) {
    if (message is int) {
      int remaining = message;
      Timer.periodic(const Duration(seconds: 1), (timer) {
        remaining--;
        mainSendPort.send(remaining);
        if (remaining <= 0) {
          timer.cancel();
          childReceivePort.close();
        }
      });
    }
  });
}
