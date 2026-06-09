import 'package:flutter/material.dart';
import 'package:mist/repo/models.dart';

class AlarmCardWidget extends StatelessWidget {
  final AlarmModal alarm;
  final Future<void> Function() onTap;
  final VoidCallback onDoubleTap;
  final Future<bool?> Function(DismissDirection) confirmDismiss;
  final Future<void> Function() onDismissed;

  const AlarmCardWidget({
    super.key,
    required this.alarm,
    required this.onTap,
    required this.onDoubleTap,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Dismissible(
          key: Key(alarm.title),
          confirmDismiss: confirmDismiss,
          direction: DismissDirection.horizontal,
          onDismissed: (_) async => await onDismissed(),
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
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(16),
                color: alarm.isActive ? Colors.black26 : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alarm,
                    color: alarm.isActive ? Colors.white70 : Colors.white30,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            alarm.time,
                            style: TextStyle(
                              color: alarm.isActive ? Colors.white70 : Colors.white38,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            alarm.period,
                            style: TextStyle(
                              color: alarm.isActive ? Colors.white70 : Colors.white38,
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
                          color: alarm.isActive ? Colors.white60 : Colors.white30,
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
                              ? Colors.purpleAccent.withValues(alpha: 0.8)
                              : Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    alarm.isActive ? "Active" : "Inactive",
                    style: TextStyle(
                      color: alarm.isActive ? Colors.white70 : Colors.white38,
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
        const SizedBox(height: 5),
      ],
    );
  }
}
