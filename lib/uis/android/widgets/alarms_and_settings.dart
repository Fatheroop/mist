import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/alarmsandremainder.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/uis/android/ui_folder.dart';
import 'package:path_provider/path_provider.dart';

// Class Models
class AlarmModal {
  String time; // e.g. "08:30"
  String period; // "AM" or "PM"
  String title;
  String audiopath;
  bool isActive;
  String repeatType; // "Once", "Repeat Days"
  List<String> repeatDays; // e.g. ["Mon", "Tue"]

  AlarmModal({
    required this.time,
    required this.period,
    required this.title,
    required this.audiopath,
    this.isActive = true,
    this.repeatType = "Once",
    List<String>? repeatDays,
  }) : repeatDays = repeatDays ?? [];

  Map<String, dynamic> toJson() => {
    'time': time,
    'period': period,
    'title': title,
    'isActive': isActive,
    'audiopath': audiopath,
    'repeatType': repeatType,
    'repeatDays': repeatDays,
  };

  factory AlarmModal.fromJson(Map<String, dynamic> json) => AlarmModal(
    time: json['time'] as String,
    period: json['period'] as String,
    title: json['title'] as String,
    isActive: json['isActive'] as bool? ?? true,
    audiopath: json['audiopath'] as String? ?? "",
    repeatType: json['repeatType'] as String? ?? "Once",
    repeatDays:
        (json['repeatDays'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );
}

class Remainder {
  String name;
  int durationSeconds; // represented as seconds (e.g. 600 for 10 minutes)
  String repeat; // "Once", "Until Stopped", "Repeat X times"
  int repeatCount; // Number of repeats if repeat is "Repeat X times"
  bool isActive;
  String audiopath;
  Remainder({
    required this.name,
    required this.durationSeconds,
    required this.repeat,
    this.repeatCount = 1,
    this.isActive = false,
    required this.audiopath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'durationSeconds': durationSeconds,
    'repeat': repeat,
    'repeatCount': repeatCount,
    'isActive': isActive,
    'audiopath': audiopath,
  };

  factory Remainder.fromJson(Map<String, dynamic> json) {
    int durationSecs = 600;
    if (json['durationSeconds'] != null) {
      durationSecs = json['durationSeconds'] as int;
    } else if (json['time'] != null) {
      // Basic fallback: if old "time" string existed, use 10 mins (600s) default
      durationSecs = 600;
    }

    final reps = json['repeatCount'] as int? ?? 1;

    return Remainder(
      name: json['name'] as String,
      durationSeconds: durationSecs,
      repeat: json['repeat'] as String? ?? "Once",
      repeatCount: reps,
      isActive: json['isActive'] as bool? ?? false,
      audiopath: json['audiopath'] as String,
    );
  }
}

class Settingalarm {
  bool vibrate;
  bool loopAudio;
  double volume; // 0.0 to 1.0
  int fadeDurationSeconds; // Fade-in duration in seconds (0 = no fade)
  int snoozeDurationMinutes; // Snooze duration in minutes
  bool ascendingVolume; // Gradually increase volume

  Settingalarm({
    required this.vibrate,
    this.loopAudio = true,
    this.volume = 1.0,
    this.fadeDurationSeconds = 1,
    this.snoozeDurationMinutes = 5,
    this.ascendingVolume = false,
  });

  Map<String, dynamic> toJson() => {
    'vibrate': vibrate,
    'loopAudio': loopAudio,
    'volume': volume,
    'fadeDurationSeconds': fadeDurationSeconds,
    'snoozeDurationMinutes': snoozeDurationMinutes,
    'ascendingVolume': ascendingVolume,
  };

  factory Settingalarm.fromJson(Map<String, dynamic> json) => Settingalarm(
    vibrate: json['vibrate'] as bool? ?? true,
    loopAudio: json['loopAudio'] as bool? ?? true,
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    fadeDurationSeconds: json['fadeDurationSeconds'] as int? ?? 1,
    snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 5,
    ascendingVolume: json['ascendingVolume'] as bool? ?? false,
  );
}

class Alarms extends StatefulWidget {
  const Alarms({super.key});

  @override
  State<Alarms> createState() => _AlarmsState();
}

class _AlarmsState extends State<Alarms> {
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();

    AlarmsAndSettings.instance.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    AlarmsAndSettings.instance.removeListener(_update);
    AlarmsAndSettings.instance.saveData();
    super.dispose();
  }

  void _update() {
    AlarmsAndSettings.instance.saveData();
    if (mounted) {
      setState(() {});
    }
  }

  void _showWarningToast(String message) {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => PremiumToastWidget(
        message: message,
        isError: false,
        isWarning: true,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );
    overlayState.insert(overlayEntry);
  }

  Future<void> _loadData() async {
    await AlarmsAndSettings.instance.getData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddAlarmBottomSheet({AlarmModal? existingAlarm}) {
    String alarmTitle = existingAlarm?.title ?? "";
    TimeOfDay selectedTime = TimeOfDay.now();
    if (existingAlarm != null) {
      try {
        final parts = existingAlarm.time.split(":");
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        if (existingAlarm.period == "PM" && hour < 12) hour += 12;
        if (existingAlarm.period == "AM" && hour == 12) hour = 0;
        selectedTime = TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        debugPrint("Error parsing existing alarm time: $e");
      }
    }
    final textController = TextEditingController(text: alarmTitle);
    String audiopath = existingAlarm?.audiopath ?? "assets/gangnam_style.mp3";
    String repeatType = existingAlarm?.repeatType ?? "Once";
    List<String> repeatDays = List<String>.from(
      existingAlarm?.repeatDays ?? [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F18),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: const Icon(
                              Icons.alarm_add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            existingAlarm != null
                                ? "Edit Alarm"
                                : "Add New Alarm",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "ALARM TITLE",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        onChanged: (val) {
                          alarmTitle = val;
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Wake up, Study, etc.",
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "TIME",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Colors.white,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF0F0F15),
                                    onSurface: Colors.white,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedTime = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedTime.format(context),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "REPEAT OPTION",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  repeatType = "Once";
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: repeatType == "Once"
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: repeatType == "Once"
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Once",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  repeatType = "Repeat Days";
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: repeatType == "Repeat Days"
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: repeatType == "Repeat Days"
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    "Repeat Days",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (repeatType == "Repeat Days") ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children:
                              [
                                "Mon",
                                "Tue",
                                "Wed",
                                "Thu",
                                "Fri",
                                "Sat",
                                "Sun",
                              ].map((day) {
                                final isSelected = repeatDays.contains(day);
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        repeatDays.remove(day);
                                      } else {
                                        repeatDays.add(day);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.purpleAccent.withValues(
                                              alpha: 0.25,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.04,
                                            ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.purpleAccent
                                            : Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        day.substring(0, 1),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white60,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ],
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return CustomAudioSelectorScreen(
                                  callback: () {
                                    audiopath = Unviersalvariables().audiopath;
                                    setDialogState(() {});
                                  },
                                );
                              },
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Pick You Audio",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                "selected audio: ${audiopath.split("/").last}",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                "if you don't choose any default audio is used.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.06,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: TextButton(
                                onPressed: () async {
                                  if (alarmTitle.trim().isEmpty) {
                                    alarmTitle = "Alarm";
                                  }
                                  final rawHour = selectedTime.hourOfPeriod;
                                  final periodStr =
                                      selectedTime.period == DayPeriod.am
                                      ? "AM"
                                      : "PM";
                                  final timeStr =
                                      "${rawHour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

                                  if (existingAlarm != null) {
                                    final updatedAlarm = AlarmModal(
                                      time: timeStr,
                                      period: periodStr,
                                      title: alarmTitle.trim(),
                                      isActive: existingAlarm.isActive,
                                      audiopath: audiopath,
                                      repeatType: repeatType,
                                      repeatDays: repeatDays,
                                    );
                                    await AlarmsAndSettings.instance
                                        .updateAlarm(
                                          updatedAlarm,
                                          oldTitle: existingAlarm.title,
                                        );
                                  } else {
                                    final newAlarm = AlarmModal(
                                      time: timeStr,
                                      period: periodStr,
                                      title: alarmTitle.trim(),
                                      audiopath: audiopath,
                                      repeatType: repeatType,
                                      repeatDays: repeatDays,
                                    );
                                    await AlarmsAndSettings.instance.addAlarm(
                                      newAlarm,
                                    );
                                  }

                                  if (context.mounted) {
                                    setState(() {});
                                    Navigator.pop(context);
                                  }
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  "Save Alarm",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: CircularProgressIndicator(color: Colors.amberAccent),
        ),
      );
    }

    final alarmsList = AlarmsAndSettings.instance.alarms;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.alarmClock,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 10),
              const Text(
                "Alarm",
                style: TextStyle(
                  color: Color.fromARGB(216, 213, 213, 213),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white54),
                        ),
                        title: const Text("Info"),
                        content: const Text(
                          "Note: Swipe right to dismiss alarms. Click to enable/disable alarms. Only Non Active alarms will dismiss for safety purpose.",
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.info_outline, size: 20),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () {
                  _showAddAlarmBottomSheet();
                },
                icon: const Icon(Icons.add_alert_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alarmsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "No active alarms configured",
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alarmsList.length,
              itemBuilder: (context, index) {
                final alarm = alarmsList[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dismissible(
                      key: Key(alarm.title),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          if (alarm.isActive) {
                            _showWarningToast(
                              "Only non-active alarms could be deleted",
                            );
                            return false;
                          }
                          return true;
                        } else if (direction == DismissDirection.endToStart) {
                          _showAddAlarmBottomSheet(existingAlarm: alarm);
                          return false;
                        }
                        return false;
                      },
                      direction: DismissDirection.horizontal,
                      onDismissed: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          await AlarmsAndSettings.instance.removeAlarm(
                            alarm.title,
                          );
                          setState(() {});
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.settings, color: Colors.white),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          alarm.isActive = !alarm.isActive;
                          await AlarmsAndSettings.instance.updateAlarm(alarm);
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white12),
                            borderRadius: BorderRadius.circular(16),
                            color: alarm.isActive
                                ? Colors.black26
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alarm,
                                color: alarm.isActive
                                    ? Colors.white70
                                    : Colors.white30,
                                size: 20,
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        alarm.time,
                                        style: TextStyle(
                                          color: alarm.isActive
                                              ? Colors.white70
                                              : Colors.white38,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        alarm.period,
                                        style: TextStyle(
                                          color: alarm.isActive
                                              ? Colors.white70
                                              : Colors.white38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    alarm.title,
                                    style: TextStyle(
                                      color: alarm.isActive
                                          ? Colors.white60
                                          : Colors.white30,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    alarm.repeatType == "Once"
                                        ? "Once"
                                        : "Repeat: ${alarm.repeatDays.isEmpty ? 'None' : alarm.repeatDays.join(', ')}",
                                    style: TextStyle(
                                      color: alarm.isActive
                                          ? Colors.purpleAccent.withValues(
                                              alpha: 0.8,
                                            )
                                          : Colors.white30,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              Spacer(),
                              Text(
                                alarm.isActive ? "Active" : "Inactive",
                                style: TextStyle(
                                  color: alarm.isActive
                                      ? Colors.white70
                                      : Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 0.5,
                      color: Colors.white12,
                    ),
                    SizedBox(height: 5),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class AlarmsSetting extends StatefulWidget {
  const AlarmsSetting({super.key});

  @override
  State<AlarmsSetting> createState() => _AlarmsSettingState();
}

class _AlarmsSettingState extends State<AlarmsSetting> {
  late Settingalarm _settings;

  @override
  void initState() {
    super.initState();
    _settings = AlarmsAndSettings.instance.settings;
  }

  void _saveSettings() {
    AlarmsAndSettings.instance.saveSettings(_settings);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    String currentPath = Unviersalvariables().audiopath;
    String toneName = currentPath.split("/").last;
    int lastDot = toneName.lastIndexOf('.');
    if (lastDot != -1) {
      toneName = toneName.substring(0, lastDot);
    }
    toneName = toneName
        .split(RegExp(r'[-_]'))
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
    final displaySoundName = toneName;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── SOUND SECTION ──
            _sectionHeader("SOUND"),
            const SizedBox(height: 10),
            _glassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ALARM & TIMER SOUND",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Active: $displaySoundName",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 207, 207, 207),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CustomAudioSelectorScreen(callback: () {}),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Select Sound",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Volume Slider
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "ALARM VOLUME",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${(_settings.volume * 100).round()}%",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Audio intensity when alarm fires",
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withValues(alpha: 0.08),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                    ),
                    child: Slider(
                      value: _settings.volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: (val) {
                        _settings.volume = val;
                        _saveSettings();
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // ── BEHAVIOR SECTION ──
            _sectionHeader("BEHAVIOR"),
            const SizedBox(height: 10),
            _glassToggle(
              title: "VIBRATION",
              subtitle: "Enable device motor vibrations on alarm",
              icon: Icons.vibration_rounded,
              value: _settings.vibrate,
              onChanged: (val) {
                _settings.vibrate = val;
                _saveSettings();
              },
            ),
            const SizedBox(height: 10),
            _glassToggle(
              title: "LOOP AUDIO",
              subtitle: "Repeat alarm sound until dismissed",
              icon: Icons.loop_rounded,
              value: _settings.loopAudio,
              onChanged: (val) {
                _settings.loopAudio = val;
                _saveSettings();
              },
            ),
            const SizedBox(height: 10),
            _glassToggle(
              title: "ASCENDING VOLUME",
              subtitle: "Gradually increase volume over time",
              icon: Icons.trending_up_rounded,
              value: _settings.ascendingVolume,
              onChanged: (val) {
                _settings.ascendingVolume = val;
                _saveSettings();
              },
            ),

            const SizedBox(height: 20),
            // ── TIMING SECTION ──
            _sectionHeader("TIMING"),
            const SizedBox(height: 10),
            // Fade-In Duration
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.slow_motion_video_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "FADE-IN DURATION",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Seconds to ramp up volume from silence",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0, 1, 3, 5, 10, 15].map((secs) {
                      final isActive = _settings.fadeDurationSeconds == secs;
                      return GestureDetector(
                        onTap: () {
                          _settings.fadeDurationSeconds = secs;
                          _saveSettings();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            secs == 0 ? "Off" : "${secs}s",
                            style: TextStyle(
                              color: isActive ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Snooze Duration
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.snooze_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SNOOZE DURATION",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Minutes before alarm re-triggers after snooze",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 3, 5, 10, 15, 30].map((mins) {
                      final isActive =
                          _settings.snoozeDurationMinutes == mins;
                      return GestureDetector(
                        onTap: () {
                          _settings.snoozeDurationMinutes = mins;
                          _saveSettings();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            "${mins}m",
                            style: TextStyle(
                              color: isActive ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2.5,
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _glassToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _glassCard(
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.4),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}


class CustomAudioSelectorScreen extends StatefulWidget {
  final VoidCallback callback;
  const CustomAudioSelectorScreen({super.key, required this.callback});

  @override
  State<CustomAudioSelectorScreen> createState() =>
      _CustomAudioSelectorScreenState();
}

class _CustomAudioSelectorScreenState extends State<CustomAudioSelectorScreen> {
  bool _isLoading = false;
  String? _playingPath;
  List<String> _audioFiles = [];
  AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingPath = null;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _audioFiles = await AlarmsAndSettings.instance.customAudios();
      setState(() {});
    });
  }

  @override
  void dispose() {
    player.stop();
    player.dispose();
    super.dispose();
  }

  Future<void> _importAudio() async {
    String path = (await getApplicationDocumentsDirectory()).path;
    Directory dir = Directory("$path/alarmsandremainder/");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result != null) {
        List<String?> paths = result.paths;
        for (String? filePath in paths) {
          if (filePath != null) {
            File file = File(filePath);
            String name = file.uri.pathSegments.last;
            String dest = "$path/alarmsandremainder/$name";
            await file.copy(dest);
            _audioFiles = await AlarmsAndSettings.instance.customAudios();
            debugPrint(dest);
            for (String paths in _audioFiles) {
              debugPrint(paths);
            }
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint("Error in _importAudio: $e");
    }
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_playingPath == path) {
        await player.stop();
        setState(() {
          _playingPath = null;
        });
      } else {
        await player.stop();
        bool isasset = path.contains("assets/");
        if (isasset) {
          String assetPath = path.startsWith("assets/")
              ? path.substring(7)
              : path;
          await player.play(AssetSource(assetPath));
        } else {
          await player.play(DeviceFileSource(path));
        }
        setState(() {
          _playingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Error in _togglePreview: $e");
    }
  }

  String _getFileSizeText(String filePath) {
    String extension = "";
    int lastDot = filePath.lastIndexOf('.');
    if (lastDot != -1) {
      extension = filePath.substring(lastDot + 1).toUpperCase();
    }
    String formatText = extension.isNotEmpty ? " • $extension" : "";

    if (filePath.startsWith("assets/") || !filePath.startsWith("/")) {
      return "System Sound$formatText";
    } else {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final bytes = file.lengthSync();
          if (bytes >= 1024 * 1024) {
            return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB$formatText";
          } else {
            return "${(bytes / 1024).toStringAsFixed(2)} KB$formatText";
          }
        }
      } catch (e) {
        debugPrint("Error reading file size: $e");
      }
      return "Local File$formatText";
    }
  }

  Widget _audioPlayerItem(String filePath) {
    String toneName = filePath.split("/").last;
    int lastDot = toneName.lastIndexOf('.');
    if (lastDot != -1) {
      toneName = toneName.substring(0, lastDot);
    }
    toneName = toneName
        .split(RegExp(r'[-_]'))
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');

    bool isSelected = Unviersalvariables().audiopath == filePath;
    bool isPlaying = _playingPath == filePath;
    bool isAsset = filePath.startsWith("assets/") || !filePath.startsWith("/");

    return GestureDetector(
      onTap: () {
        _togglePreview(filePath);
        setState(() {
          Unviersalvariables().audiopath = filePath;
        });
        widget.callback();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                isPlaying
                    ? Icons.volume_up_rounded
                    : (isAsset
                          ? Icons.music_note_rounded
                          : Icons.audiotrack_rounded),
                color: isSelected ? Colors.black87 : Colors.white60,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isAsset ? "SYSTEM" : "IMPORTED",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFileSizeText(filePath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    toneName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isPlaying
                ? Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : isSelected
                ? Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black87,
                      size: 16,
                    ),
                  )
                : Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ALARM & TIMER SOUNDS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "Choose system tones or manage custom audio",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: "Rebuild Audios List",
            onPressed: () async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF111115),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: const Text(
                    "Audios list rebuilt successfully!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          // 1. System Tones Header
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 4,
                              top: 12,
                              bottom: 8,
                            ),
                            child: Text(
                              "SYSTEM BUILT-IN TONES",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),

                          // 2. Built-in Tones List
                          ...AlarmsAndSettings.instance
                              .getDefaultAssetsAudio()
                              .map((tone) => _audioPlayerItem(tone)),

                          const SizedBox(height: 20),

                          // 3. Custom Audios Header
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              "IMPORTED CUSTOM AUDIO",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),

                          // 4. Custom Audios List
                          if (_audioFiles.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.music_off_rounded,
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "No custom audios imported yet",
                                      style: TextStyle(
                                        color: Colors.white30,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._audioFiles.map((file) {
                              return _audioPlayerItem(file);
                            }),
                        ],
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFEEEEEE)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      onPressed: _importAudio,
                      icon: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.black87,
                      ),
                      label: const Text(
                        "Import Audio File",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
