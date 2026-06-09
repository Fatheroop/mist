import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/models.dart';
import 'package:mist/uis/android/widgets/alarm_card.dart';
import 'package:mist/uis/android/widgets/custom_audio_selector.dart';
import 'package:mist/uis/android/widgets/premium_toast.dart';

class Alarms extends StatefulWidget {
  const Alarms({super.key});

  @override
  State<Alarms> createState() => _AlarmsState();
}

class _AlarmsState extends State<Alarms> {
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
                          existingAlarm != null ? "Edit Alarm" : "Add New Alarm",
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
                        children: [
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
                            builder: (dialogCtx) {
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Pick Your Audio",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              "selected audio: ${audiopath.split("/").last}",
                              style: const TextStyle(color: Colors.white54),
                            ),
                            const Text(
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

                                final cubit = context.read<AlarmsCubit>();
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
                                  await cubit.updateAlarm(
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
                                  await cubit.addAlarm(newAlarm);
                                }

                                if (context.mounted) {
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
    return BlocBuilder<AlarmsCubit, AlarmsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(
              child: CircularProgressIndicator(color: Colors.amberAccent),
            ),
          );
        }

        final alarmsList = state.alarms;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.clock,
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
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogCtx) {
                          return AlertDialog(
                            backgroundColor: Colors.black54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white54),
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
                    return AlarmCardWidget(
                      alarm: alarm,
                      onTap: () async {
                        final updated = AlarmModal(
                          time: alarm.time,
                          period: alarm.period,
                          title: alarm.title,
                          audiopath: alarm.audiopath,
                          isActive: !alarm.isActive,
                          repeatType: alarm.repeatType,
                          repeatDays: alarm.repeatDays,
                        );
                        await context.read<AlarmsCubit>().updateAlarm(updated);
                      },
                      onDoubleTap: () {
                        _showAddAlarmBottomSheet(existingAlarm: alarm);
                      },
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
                      onDismissed: () async {
                        await context.read<AlarmsCubit>().removeAlarm(alarm.title);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
