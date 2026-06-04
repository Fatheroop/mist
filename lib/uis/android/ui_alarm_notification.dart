import 'dart:ui';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/alarmsandremainder.dart';
import 'package:mist/uis/android/widgets/alarms_and_settings.dart';

class UiAlarmNotification extends StatefulWidget {
  final AlarmModal alarm;
  final AlarmSettings settings;

  static bool active = false;
  static int? activeAlarmId;

  const UiAlarmNotification({
    super.key,
    required this.alarm,
    required this.settings,
  });

  @override
  State<UiAlarmNotification> createState() => _UiAlarmNotificationState();
}

class _UiAlarmNotificationState extends State<UiAlarmNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    UiAlarmNotification.active = true;
    UiAlarmNotification.activeAlarmId = widget.settings.id;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    UiAlarmNotification.active = false;
    UiAlarmNotification.activeAlarmId = null;
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String soundName = widget.alarm.audiopath.split("/").last;
    int lastDot = soundName.lastIndexOf('.');
    if (lastDot != -1) {
      soundName = soundName.substring(0, lastDot);
    }
    soundName = soundName
        .split(RegExp(r'[-_]'))
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');

    return Scaffold(
      backgroundColor: const Color(0xFF07070C),
      body: Stack(
        children: [
          // White Glow Ambient Circle 1 (Top Left)
          Positioned(
            left: -50,
            top: -50,
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 180,
                  ),
                ],
              ),
            ),
          ),
          // White Glow Ambient Circle 2 (Bottom Right)
          Positioned(
            right: -50,
            bottom: -50,
            child: Container(
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.05),
                    blurRadius: 180,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 20),
                  // Ticking Header Illustration
                  Column(
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.03),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.02),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: const FaIcon(
                                FontAwesomeIcons.clock,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        "ALARM RINGING",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.alarm.title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // Alarm Time Container (Glassmorphic)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.alarm.time,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.alarm.period,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Metadata Card (Glassmorphic look)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow(
                          icon: Icons.music_note_rounded,
                          label: "Alarm Audio File",
                          value: soundName,
                        ),
                        const SizedBox(height: 16),
                        _buildMetaRow(
                          icon: Icons.vibration_rounded,
                          label: "Vibrate Mode",
                          value: widget.settings.vibrate
                              ? "Enabled"
                              : "Disabled",
                        ),
                      ],
                    ),
                  ),

                  // Tactile Glassmorphic Dismiss Button
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFF2F2F2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () async {
                            // Stop the currently ringing alarm FIRST to prevent
                            // race conditions with rescheduling
                            await Alarm.stop(widget.settings.id);
                            // Turn active off in state manager if repeatType is Once
                            // Keep active and reschedule if it's a repeating alarm
                            widget.alarm.isActive = widget.alarm.repeatType != "Once";
                            await AlarmsAndSettings.instance.updateAlarm(
                              widget.alarm,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            "Dismiss Alarm",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
