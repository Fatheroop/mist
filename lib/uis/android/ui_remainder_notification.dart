import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mist/uis/android/widgets/alarms_and_settings.dart';

class UiRemainderNotification extends StatefulWidget {
  final Remainder remainder;
  const UiRemainderNotification({super.key, required this.remainder});

  @override
  State<UiRemainderNotification> createState() =>
      _UiRemainderNotificationState();
}

class _UiRemainderNotificationState extends State<UiRemainderNotification> {
  AudioPlayer player = AudioPlayer();

  void playaudio() async {
    try {
      String path = widget.remainder.audiopath;
      if (path.contains("assets")) {
        String assetPath = path.startsWith("assets/")
            ? path.substring(7)
            : path;
        await player.play(AssetSource(assetPath));
      } else {
        await player.play(DeviceFileSource(path));
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void initState() {
    super.initState();
    // setting audio mode to looping
    player.setReleaseMode(ReleaseMode.loop);
    playaudio();
  }

  @override
  void dispose() {
    player.stop();
    player.dispose();
    super.dispose();
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

  String _formatMinutes(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    if (seconds == 0) {
      return "$minutes mins";
    }
    return "$minutes mins $seconds secs";
  }

  @override
  Widget build(BuildContext context) {
    String soundName = widget.remainder.audiopath.split("/").last;
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
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.04),
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
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.04),
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
                vertical: 20.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 20),
                  // Alarm Ticking Header Illustration
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
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
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        "REMINDER ALERT",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.remainder.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // Metadata Card (Glassmorphic look)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildMetaRow(
                          icon: Icons.hourglass_top_rounded,
                          label: "Duration",
                          value: _formatMinutes(
                            widget.remainder.durationSeconds,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildMetaRow(
                          icon: Icons.repeat_rounded,
                          label: "Repeat Mode",
                          value: _getRepeatText(widget.remainder),
                        ),
                        const SizedBox(height: 16),
                        _buildMetaRow(
                          icon: Icons.music_note_rounded,
                          label: "Alert Sound",
                          value: soundName,
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFE5E5E5)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            "Dismiss",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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
            color: Colors.white.withValues(alpha: 0.05),
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
                  color: Colors.white.withValues(alpha: 0.3),
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
