import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/models.dart';
import 'package:mist/uis/android/widgets/custom_audio_selector.dart';

class AlarmsSetting extends StatelessWidget {
  const AlarmsSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmsCubit, AlarmsState>(
      builder: (context, state) {
        final settings = state.settings;
        final alarmsCubit = context.read<AlarmsCubit>();

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
                          );
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
                            "${(settings.volume * 100).round()}%",
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
                          value: settings.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          onChanged: (val) {
                            alarmsCubit.saveSettings(
                              Settingalarm(
                                vibrate: settings.vibrate,
                                loopAudio: settings.loopAudio,
                                volume: val,
                                fadeDurationSeconds: settings.fadeDurationSeconds,
                                snoozeDurationMinutes: settings.snoozeDurationMinutes,
                                ascendingVolume: settings.ascendingVolume,
                              ),
                            );
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
                  value: settings.vibrate,
                  onChanged: (val) {
                    alarmsCubit.saveSettings(
                      Settingalarm(
                        vibrate: val,
                        loopAudio: settings.loopAudio,
                        volume: settings.volume,
                        fadeDurationSeconds: settings.fadeDurationSeconds,
                        snoozeDurationMinutes: settings.snoozeDurationMinutes,
                        ascendingVolume: settings.ascendingVolume,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _glassToggle(
                  title: "LOOP AUDIO",
                  subtitle: "Repeat alarm sound until dismissed",
                  icon: Icons.loop_rounded,
                  value: settings.loopAudio,
                  onChanged: (val) {
                    alarmsCubit.saveSettings(
                      Settingalarm(
                        vibrate: settings.vibrate,
                        loopAudio: val,
                        volume: settings.volume,
                        fadeDurationSeconds: settings.fadeDurationSeconds,
                        snoozeDurationMinutes: settings.snoozeDurationMinutes,
                        ascendingVolume: settings.ascendingVolume,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _glassToggle(
                  title: "ASCENDING VOLUME",
                  subtitle: "Gradually increase volume over time",
                  icon: Icons.trending_up_rounded,
                  value: settings.ascendingVolume,
                  onChanged: (val) {
                    alarmsCubit.saveSettings(
                      Settingalarm(
                        vibrate: settings.vibrate,
                        loopAudio: settings.loopAudio,
                        volume: settings.volume,
                        fadeDurationSeconds: settings.fadeDurationSeconds,
                        snoozeDurationMinutes: settings.snoozeDurationMinutes,
                        ascendingVolume: val,
                      ),
                    );
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
                          final isActive = settings.fadeDurationSeconds == secs;
                          return GestureDetector(
                            onTap: () {
                              alarmsCubit.saveSettings(
                                Settingalarm(
                                  vibrate: settings.vibrate,
                                  loopAudio: settings.loopAudio,
                                  volume: settings.volume,
                                  fadeDurationSeconds: secs,
                                  snoozeDurationMinutes: settings.snoozeDurationMinutes,
                                  ascendingVolume: settings.ascendingVolume,
                                ),
                              );
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
                              settings.snoozeDurationMinutes == mins;
                          return GestureDetector(
                            onTap: () {
                              alarmsCubit.saveSettings(
                                Settingalarm(
                                  vibrate: settings.vibrate,
                                  loopAudio: settings.loopAudio,
                                  volume: settings.volume,
                                  fadeDurationSeconds: settings.fadeDurationSeconds,
                                  snoozeDurationMinutes: mins,
                                  ascendingVolume: settings.ascendingVolume,
                                ),
                              );
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
      },
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
