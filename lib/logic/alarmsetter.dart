import 'dart:convert';
import 'dart:io';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/repo/models.dart';

class Alarmsetter {
  static final Alarmsetter instance = Alarmsetter();

  int createuniqueid(AlarmModal modal) {
    return modal.title.hashCode & 0x7FFFFFFF;
  }

  DateTime calculateNextRepeatDateTime(AlarmModal modal) {
    final now = DateTime.now();
    try {
      final parts = modal.time.split(':');
      int hour = int.parse(parts[0].trim());
      int minute = int.parse(parts[1].trim());

      final period = modal.period.toUpperCase().trim();
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      // If repeating days are empty or repeatType is "Once"
      if (modal.repeatType == "Once" || modal.repeatDays.isEmpty) {
        var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        return scheduled;
      }

      // Day mapping to DateTime weekdays
      final dayMap = {
        'Mon': DateTime.monday,
        'Tue': DateTime.tuesday,
        'Wed': DateTime.wednesday,
        'Thu': DateTime.thursday,
        'Fri': DateTime.friday,
        'Sat': DateTime.saturday,
        'Sun': DateTime.sunday,
      };

      final activeDays = modal.repeatDays
          .map((d) => dayMap[d])
          .where((d) => d != null)
          .cast<int>()
          .toList();

      if (activeDays.isEmpty) {
        var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        return scheduled;
      }

      // Search matching weekdays for the next 7 days (including today)
      for (int i = 0; i <= 7; i++) {
        final candidate = now.add(Duration(days: i));
        final candidateDate = DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          hour,
          minute,
        );

        if (activeDays.contains(candidate.weekday)) {
          if (candidateDate.isAfter(now)) {
            return candidateDate;
          }
        }
      }

      return now.add(const Duration(days: 1));
    } catch (e) {
      return now.add(const Duration(minutes: 1));
    }
  }

  Future<void> setAlarm(AlarmModal modal) async {
    final scheduledTime = calculateNextRepeatDateTime(modal);
    debugPrint(
      "⏰ setAlarm: title='${modal.title}', time='${modal.time} ${modal.period}'",
    );
    debugPrint(
      "⏰ setAlarm: scheduledTime=$scheduledTime (${scheduledTime.difference(DateTime.now()).inMinutes} minutes from now)",
    );

    // For custom local audio files, use the absolute path directly.
    // For asset audio files, keep the assets/ prefix as-is.
    // The alarm package supports both absolute device paths and asset paths.
    String resolvedPath = modal.audiopath;
    if (!resolvedPath.startsWith("assets/") && resolvedPath.isNotEmpty) {
      // Verify local file exists, fall back to default if missing
      try {
        final file = File(resolvedPath);
        if (!await file.exists()) {
          debugPrint(
            "⏰ Custom audio file not found: $resolvedPath, using default",
          );
          resolvedPath = "assets/gangnam_style.mp3";
        }
      } catch (_) {
        resolvedPath = "assets/gangnam_style.mp3";
      }
    } else if (resolvedPath.isEmpty) {
      resolvedPath = "assets/gangnam_style.mp3";
    }
    debugPrint("⏰ setAlarm: resolvedAudioPath='$resolvedPath'");

    // Read user settings from the settings manager
    final userSettings = AlarmsCubit.instance.state.settings;
    debugPrint(
      "⏰ setAlarm: vibrate=${userSettings.vibrate}, loop=${userSettings.loopAudio}, vol=${userSettings.volume}",
    );

    // Build volume settings based on user settings
    final VolumeSettings volumeSettings;
    if (userSettings.ascendingVolume && userSettings.fadeDurationSeconds > 0) {
      volumeSettings = VolumeSettings.fade(
        fadeDuration: Duration(seconds: userSettings.fadeDurationSeconds),
        volume: userSettings.volume,
        volumeEnforced: true,
      );
    } else {
      volumeSettings = VolumeSettings.fixed(
        volume: userSettings.volume,
        volumeEnforced: true,
      );
    }

    final alarmId = createuniqueid(modal);
    debugPrint("⏰ setAlarm: alarmId=$alarmId");

    AlarmSettings settings = AlarmSettings(
      id: alarmId,
      assetAudioPath: resolvedPath,
      dateTime: scheduledTime,
      loopAudio: userSettings.loopAudio,
      vibrate: userSettings.vibrate,
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      warningNotificationOnKill: false,
      volumeSettings: volumeSettings,
      payload: jsonEncode(modal.toJson()),
      notificationSettings: NotificationSettings(
        title: "🔔 Mist Alarm",
        body: "Time to focus: '${modal.title}' (${modal.time} ${modal.period})",
        stopButton: "Dismiss Alarm",
        iconColor: const Color(0xFFC084FC),
      ),
    );

    try {
      await Alarm.set(alarmSettings: settings);
      debugPrint(
        "⏰ setAlarm: SUCCESS — alarm $alarmId scheduled for $scheduledTime",
      );
    } catch (e) {
      debugPrint("⏰ setAlarm: FAILED — $e");
    }
  }

  Future<void> removeAlarm(AlarmModal modal) async {
    await Alarm.stop(createuniqueid(modal));
  }

  Future<void> stopAlarm(AlarmModal modal) async {
    await Alarm.stop(createuniqueid(modal));
  }
}
