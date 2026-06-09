import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mist/logic/alarmsetter.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/models.dart';
import 'package:mist/uis/android/ui_alarm_notification.dart';
import 'package:mist/uis/android/ui_remainder_notification.dart';

class AlarmsState {
  final List<Remainder> remainders;
  final List<AlarmModal> alarms;
  final Settingalarm settings;
  final Map<String, int> remainingSeconds;
  final Map<String, int> currentRepeatCounts;
  final Set<String> visibleNotifications;
  final bool isLoading;

  AlarmsState({
    this.remainders = const [],
    this.alarms = const [],
    Settingalarm? settings,
    this.remainingSeconds = const {},
    this.currentRepeatCounts = const {},
    this.visibleNotifications = const {},
    this.isLoading = true,
  }) : settings = settings ?? Settingalarm(vibrate: true);

  AlarmsState copyWith({
    List<Remainder>? remainders,
    List<AlarmModal>? alarms,
    Settingalarm? settings,
    Map<String, int>? remainingSeconds,
    Map<String, int>? currentRepeatCounts,
    Set<String>? visibleNotifications,
    bool? isLoading,
  }) {
    return AlarmsState(
      remainders: remainders ?? this.remainders,
      alarms: alarms ?? this.alarms,
      settings: settings ?? this.settings,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      currentRepeatCounts: currentRepeatCounts ?? this.currentRepeatCounts,
      visibleNotifications: visibleNotifications ?? this.visibleNotifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AlarmsCubit extends Cubit<AlarmsState> {
  static late AlarmsCubit instance;

  // Background countdown isolate tracking
  final Map<String, Isolate> activeIsolates = {};
  final Map<String, ReceivePort> activeReceivePorts = {};

  AlarmsCubit() : super(AlarmsState()) {
    instance = this;
  }

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
          final updatedRemaining = Map<String, int>.from(state.remainingSeconds);
          updatedRemaining[reminder.name] = message;
          emit(state.copyWith(remainingSeconds: updatedRemaining));

          if (message <= 0) {
            stopReminderIsolate(reminder.name);
            _triggerReminderNotification(reminder);
          }
        }
      });
    } catch (e) {
      debugPrint("Error spawning isolate in cubit: $e");
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
    final updatedRemaining = Map<String, int>.from(state.remainingSeconds);
    updatedRemaining.remove(name);
    emit(state.copyWith(remainingSeconds: updatedRemaining));
  }

  void _triggerReminderNotification(Remainder reminder) {
    if (state.visibleNotifications.contains(reminder.name)) {
      return;
    }

    final updatedVisible = Set<String>.from(state.visibleNotifications);
    updatedVisible.add(reminder.name);
    emit(state.copyWith(visibleNotifications: updatedVisible));

    final context = Unviersalvariables().navigatorKey.currentContext;
    if (context == null) {
      debugPrint("Global context is null! Cannot push notification screen.");
      final updatedVisible = Set<String>.from(state.visibleNotifications);
      updatedVisible.remove(reminder.name);
      emit(state.copyWith(visibleNotifications: updatedVisible));
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => UiRemainderNotification(remainder: reminder),
          ),
        )
        .then((_) {
          final updatedVisible = Set<String>.from(state.visibleNotifications);
          updatedVisible.remove(reminder.name);
          emit(state.copyWith(visibleNotifications: updatedVisible));
          _handleRepeatCycle(reminder);
        });
  }

  void _handleRepeatCycle(Remainder reminder) {
    if (reminder.repeat == "Once") {
      reminder.isActive = false;
      updateRemainder(reminder);
    } else if (reminder.repeat == "Repeat X times") {
      final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
      int remaining = updatedRepeatCounts[reminder.name] ?? reminder.repeatCount;
      remaining--;
      updatedRepeatCounts[reminder.name] = remaining;
      emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));

      if (remaining > 0) {
        startReminderIsolate(reminder);
      } else {
        reminder.isActive = false;
        updateRemainder(reminder);
        final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
        updatedRepeatCounts.remove(reminder.name);
        emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
      }
    } else if (reminder.repeat == "Until Stopped") {
      startReminderIsolate(reminder);
    }
  }

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
        final loadedAlarms = (data['alarms'] as List<dynamic>? ?? [])
            .map((e) => AlarmModal.fromJson(e as Map<String, dynamic>))
            .toList();
        final loadedRemainders = (data['remainders'] as List<dynamic>? ?? [])
            .map((e) => Remainder.fromJson(e as Map<String, dynamic>))
            .toList();
        final loadedSettings = Settingalarm.fromJson(
          data['settings'] as Map<String, dynamic>? ?? {},
        );

        emit(state.copyWith(
          alarms: loadedAlarms,
          remainders: loadedRemainders,
          settings: loadedSettings,
          isLoading: false,
        ));

        // Restore background timers
        for (var reminder in loadedRemainders) {
          if (reminder.isActive && !activeIsolates.containsKey(reminder.name)) {
            final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
            updatedRepeatCounts[reminder.name] = reminder.repeatCount;
            emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
            startReminderIsolate(reminder);
          }
        }

        // Restore active alarms in native Alarm package
        for (var alarm in loadedAlarms) {
          if (alarm.isActive) {
            final uniqueId = Alarmsetter.instance.createuniqueid(alarm);
            final isScheduled = Alarm.scheduled.value.alarms.any(
              (a) => a.id == uniqueId,
            );

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
        emit(state.copyWith(
          alarms: [],
          remainders: [],
          settings: Settingalarm(vibrate: true),
          isLoading: false,
        ));
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
          emit(state.copyWith(
            alarms: [],
            remainders: [],
            settings: Settingalarm(vibrate: true),
            isLoading: false,
          ));
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
          'alarms': state.alarms.map((e) => e.toJson()).toList(),
          'remainders': state.remainders.map((e) => e.toJson()).toList(),
          'settings': state.settings.toJson(),
        }),
      );
    } catch (e) {
      debugPrint("Error in saveData: $e");
    }
  }

  Future<void> addAlarm(AlarmModal alarm) async {
    final updatedAlarms = List<AlarmModal>.from(state.alarms);
    final baseTitle = alarm.title;
    bool check = updatedAlarms.any((element) => element.title == alarm.title);
    int i = 1;
    while (check) {
      alarm.title = "$baseTitle ($i)";
      i++;
      check = updatedAlarms.any((element) => element.title == alarm.title);
    }
    for (final element in updatedAlarms.where(
      (e) => e.time == alarm.time && e.period == alarm.period,
    )) {
      await Alarmsetter.instance.stopAlarm(element);
    }
    updatedAlarms.removeWhere(
      (element) => element.time == alarm.time && element.period == alarm.period,
    );
    updatedAlarms.add(alarm);
    if (alarm.isActive) {
      await Alarmsetter.instance.setAlarm(alarm);
    }
    emit(state.copyWith(alarms: updatedAlarms));
    await saveData();
  }

  Future<void> removeAlarm(String title) async {
    final updatedAlarms = List<AlarmModal>.from(state.alarms);
    final idx = updatedAlarms.indexWhere((element) => element.title == title);
    if (idx != -1) {
      final alarm = updatedAlarms[idx];
      await Alarmsetter.instance.stopAlarm(alarm);
      updatedAlarms.removeAt(idx);
      emit(state.copyWith(alarms: updatedAlarms));
      await saveData();
    }
  }

  Future<void> updateAlarm(AlarmModal alarm, {String? oldTitle}) async {
    final updatedAlarms = List<AlarmModal>.from(state.alarms);
    final searchTitle = oldTitle ?? alarm.title;
    final idx = updatedAlarms.indexWhere((element) => element.title == searchTitle);
    if (idx != -1) {
      final oldAlarm = updatedAlarms[idx];
      await Alarmsetter.instance.stopAlarm(oldAlarm);
      updatedAlarms[idx] = alarm;
      if (alarm.isActive) {
        await Alarmsetter.instance.setAlarm(alarm);
      }
      emit(state.copyWith(alarms: updatedAlarms));
      await saveData();
    }
  }

  Future<void> addRemainder(Remainder remainder) async {
    final updatedRemainders = List<Remainder>.from(state.remainders);
    bool check = updatedRemainders.any((element) => element.name == remainder.name);
    int i = 1;
    while (check) {
      remainder.name = "${remainder.name} ($i)";
      i++;
      check = updatedRemainders.any((element) => element.name == remainder.name);
    }
    updatedRemainders.add(remainder);
    emit(state.copyWith(remainders: updatedRemainders));
    await saveData();
  }

  Future<void> removeRemainder(String name) async {
    stopReminderIsolate(name);
    final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
    updatedRepeatCounts.remove(name);
    final updatedRemainders = List<Remainder>.from(state.remainders);
    updatedRemainders.removeWhere((element) => element.name == name);
    emit(state.copyWith(
      remainders: updatedRemainders,
      currentRepeatCounts: updatedRepeatCounts,
    ));
    await saveData();
  }

  Future<void> updateRemainder(Remainder remainder, {String? oldName}) async {
    final updatedRemainders = List<Remainder>.from(state.remainders);
    final searchName = oldName ?? remainder.name;
    final idx = updatedRemainders.indexWhere((element) => element.name == searchName);
    if (idx != -1) {
      if (oldName != null && oldName != remainder.name) {
        stopReminderIsolate(oldName);
        final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
        updatedRepeatCounts.remove(oldName);
        emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
      }
      updatedRemainders[idx] = remainder;
      emit(state.copyWith(remainders: updatedRemainders));

      if (remainder.isActive) {
        if (!activeIsolates.containsKey(remainder.name)) {
          final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
          updatedRepeatCounts[remainder.name] = remainder.repeatCount;
          emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
          startReminderIsolate(remainder);
        }
      }
      await saveData();
    }
  }

  Future<void> toggleRemainder(Remainder reminder) async {
    reminder.isActive = !reminder.isActive;
    await updateRemainder(reminder);
    if (reminder.isActive) {
      final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
      updatedRepeatCounts[reminder.name] = reminder.repeatCount;
      emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
      startReminderIsolate(reminder);
    } else {
      stopReminderIsolate(reminder.name);
      final updatedRepeatCounts = Map<String, int>.from(state.currentRepeatCounts);
      updatedRepeatCounts.remove(reminder.name);
      emit(state.copyWith(currentRepeatCounts: updatedRepeatCounts));
    }
  }

  Future<void> saveSettings(Settingalarm newSettings) async {
    emit(state.copyWith(settings: newSettings));
    await saveData();
    for (final alarm in state.alarms) {
      if (alarm.isActive) {
        await Alarmsetter.instance.setAlarm(alarm);
      }
    }
  }
}

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
