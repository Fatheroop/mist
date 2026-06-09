import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/models.dart';
import 'package:mist/uis/android/widgets/custom_audio_selector.dart';
import 'package:mist/uis/android/widgets/premium_toast.dart';

class RemainderWidget extends StatefulWidget {
  const RemainderWidget({super.key});

  @override
  State<RemainderWidget> createState() => _RemainderWidgetState();
}

class _RemainderWidgetState extends State<RemainderWidget> {
  String _formatDuration(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  String _getRepeatText(Remainder reminder) {
    String repeatText = reminder.repeat;
    if (reminder.repeat == "Repeat X times") {
      repeatText = "Repeat ${reminder.repeatCount} times";
    } else if (reminder.repeat == "Until Stopped") {
      repeatText = "Until I stop";
    } else if (reminder.repeat == "Once") {
      repeatText = "Once";
    }
    return repeatText;
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

  void _showAddRemainderBottomSheet({Remainder? existingRemainder}) {
    String reminderName = existingRemainder?.name ?? "";
    int minutes = 6;
    int seconds = 9;
    if (existingRemainder != null) {
      minutes = existingRemainder.durationSeconds ~/ 60;
      seconds = existingRemainder.durationSeconds % 60;
    }
    String selectedRepeat = existingRemainder?.repeat ?? "Once";
    int repeatCount = existingRemainder?.repeatCount ?? 3;

    final textController = TextEditingController(text: reminderName);
    String audiopath =
        existingRemainder?.audiopath ?? "assets/gangnam_style.mp3";

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
                            Icons.notification_add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          existingRemainder != null
                              ? "Edit Timer"
                              : "Add New Timer",
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
                      "REMINDER NAME",
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
                        reminderName = val;
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Drink Water, Stretch, etc.",
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
                      "TIMER DURATION",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Minutes Wheel
                          Expanded(
                            child: CupertinoTheme(
                              data: const CupertinoThemeData(
                                brightness: Brightness.dark,
                                textTheme: CupertinoTextThemeData(
                                  pickerTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: minutes,
                                ),
                                itemExtent: 36,
                                onSelectedItemChanged: (int index) {
                                  setDialogState(() {
                                    minutes = index;
                                  });
                                },
                                children: List<Widget>.generate(60, (
                                  int index,
                                ) {
                                  return Center(
                                    child: Text(
                                      "$index min",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          // Seconds Wheel
                          Expanded(
                            child: CupertinoTheme(
                              data: const CupertinoThemeData(
                                brightness: Brightness.dark,
                                textTheme: CupertinoTextThemeData(
                                  pickerTextStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              child: CupertinoPicker(
                                scrollController: FixedExtentScrollController(
                                  initialItem: seconds,
                                ),
                                itemExtent: 36,
                                onSelectedItemChanged: (int index) {
                                  setDialogState(() {
                                    seconds = index;
                                  });
                                },
                                children: List<Widget>.generate(60, (
                                  int index,
                                ) {
                                  return Center(
                                    child: Text(
                                      "$index sec",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              style: const TextStyle(color: Colors.white70),
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
                    const SizedBox(height: 20),
                    const Text(
                      "REPEAT",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Once', 'Until Stopped', 'Repeat X times']
                          .map((mode) {
                            final isSelected = mode == selectedRepeat;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedRepeat = mode;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: 0.08,
                                            ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      mode == 'Until Stopped'
                                          ? 'Until I stop'
                                          : (mode == 'Repeat X times'
                                                ? 'Repeat count'
                                                : mode),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black
                                            : Colors.white70,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    if (selectedRepeat == 'Repeat X times') ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "REPEAT COUNT",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (repeatCount > 1) {
                                      setDialogState(() => repeatCount--);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.remove_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 32),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    "$repeatCount",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setDialogState(() => repeatCount++);
                                  },
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(32, 32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
                                final cubit = context.read<AlarmsCubit>();
                                if (existingRemainder == null) {
                                  await cubit.addRemainder(
                                    Remainder(
                                      name: reminderName == "" ||
                                              reminderName.isEmpty
                                          ? "Why ?"
                                          : reminderName,
                                      durationSeconds:
                                          minutes * 60 + seconds,
                                      repeat: selectedRepeat,
                                      repeatCount: repeatCount,
                                      audiopath: audiopath,
                                    ),
                                  );
                                } else {
                                  await cubit.updateRemainder(
                                    Remainder(
                                      name: reminderName,
                                      durationSeconds:
                                          minutes * 60 + seconds,
                                      repeat: selectedRepeat,
                                      repeatCount: repeatCount,
                                      audiopath: audiopath,
                                      isActive:
                                          existingRemainder.isActive,
                                    ),
                                    oldName: existingRemainder.name,
                                  );
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
                                "Save Reminder",
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
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final remindersList = state.remainders;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "FOCUS REMINDERS",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    onPressed: _showAddRemainderBottomSheet,
                    icon: const Icon(
                      Icons.notification_add_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (remindersList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      "No reminders configured",
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remindersList.length,
                  itemBuilder: (context, index) {
                    final reminder = remindersList[index];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Dismissible(
                          key: Key(reminder.name),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              if (reminder.isActive) {
                                _showWarningToast(
                                  "Only non-active reminders could be deleted",
                                );
                                return false;
                              }
                              return true;
                            } else if (direction == DismissDirection.endToStart) {
                              _showAddRemainderBottomSheet(
                                existingRemainder: reminder,
                              );
                              return false;
                            }
                            return false;
                          },
                          direction: DismissDirection.horizontal,
                          onDismissed: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await context
                                  .read<AlarmsCubit>()
                                  .removeRemainder(reminder.name);
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
                            onTap: () {
                              context
                                  .read<AlarmsCubit>()
                                  .toggleRemainder(reminder);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: reminder.isActive
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.05),
                                ),
                                borderRadius: BorderRadius.circular(24),
                                color: reminder.isActive
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        color: reminder.isActive
                                            ? Colors.white
                                            : Colors.white30,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reminder.name,
                                              style: TextStyle(
                                                color: reminder.isActive
                                                    ? Colors.white
                                                    : Colors.white70,
                                                fontWeight: reminder.isActive
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getRepeatText(reminder),
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: reminder.isActive
                                              ? Colors.white
                                              : Colors.white.withValues(
                                                  alpha: 0.05,
                                                ),
                                          border: Border.all(
                                            color: reminder.isActive
                                                ? Colors.white
                                                : Colors.white.withValues(
                                                    alpha: 0.15,
                                                  ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          reminder.isActive
                                              ? Icons.notifications_active_rounded
                                              : Icons.notifications_none_rounded,
                                          color: reminder.isActive
                                              ? Colors.black87
                                              : Colors.white38,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AnimatedCrossFade(
                                    firstChild: const SizedBox.shrink(),
                                    secondChild: Column(
                                      children: [
                                        const SizedBox(height: 16),
                                        Container(
                                          height: 1,
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              "Remaining Time",
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(
                                                state.remainingSeconds[reminder.name] ??
                                                    reminder.durationSeconds,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value:
                                                (state.remainingSeconds[reminder.name] ??
                                                    reminder.durationSeconds) /
                                                reminder.durationSeconds,
                                            backgroundColor: Colors.white
                                                .withValues(alpha: 0.05),
                                            valueColor:
                                                const AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                    crossFadeState: reminder.isActive
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    duration: const Duration(milliseconds: 300),
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
                        const SizedBox(height: 5),
                      ],
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
