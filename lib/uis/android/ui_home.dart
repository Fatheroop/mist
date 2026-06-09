import 'dart:async';
import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/alarmsetter.dart';
import 'package:mist/logic/navigation_cubit.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/models.dart';
import 'package:mist/repo/permission_handler.dart';
import 'package:mist/uis/android/ui_alarm_notification.dart';
import 'package:mist/uis/android/ui_folder.dart';
import 'package:mist/uis/android/ui_nodes.dart';
import 'package:mist/uis/android/widgets/home_content.dart';
import 'package:mist/uis/android/widgets/permission_request.dart';

class UIHome extends StatefulWidget {
  const UIHome({super.key});

  @override
  State<UIHome> createState() => _UIHomeState();
}

class _UIHomeState extends State<UIHome> with WidgetsBindingObserver {
  StreamSubscription? _alarmSubscription;
  bool _isPushingRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to incoming alarm ring events to show the full screen alert
    _alarmSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) {
        _showAlarmOverlay(alarmSet.alarms.first);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowRingingAlarm();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkAndShowRingingAlarm();
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _checkAndShowRingingAlarm();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmSubscription?.cancel();
    super.dispose();
  }

  void _showAlarmOverlay(dynamic settings) {
    if (settings == null) return;
    if (UiAlarmNotification.active || _isPushingRoute) return;
    if (!mounted) return;
    _isPushingRoute = true;

    debugPrint(
      "🔔 _showAlarmOverlay triggered, settings type: ${settings.runtimeType}",
    );

    dynamic alarmSettings = settings;
    try {
      if (settings.alarms != null) {
        if (settings.alarms.isEmpty) {
          _isPushingRoute = false;
          return;
        }
        alarmSettings = settings.alarms.first;
      }
    } catch (_) {}

    debugPrint(
      "🔔 Alarm ID: ${alarmSettings.id}, navigating to notification screen...",
    );

    AlarmModal? payloadAlarm;
    if (alarmSettings.payload != null && alarmSettings.payload.isNotEmpty) {
      try {
        final parsed =
            jsonDecode(alarmSettings.payload) as Map<String, dynamic>;
        payloadAlarm = AlarmModal.fromJson(parsed);
      } catch (e) {
        debugPrint("🔔 Error decoding AlarmModal from payload: $e");
      }
    }

    final alarmModel =
        payloadAlarm ??
        context.read<AlarmsCubit>().state.alarms.firstWhere(
          (element) =>
              (element.title.hashCode & 0x7FFFFFFF) == alarmSettings.id,
          orElse: () => AlarmModal(
            time:
                "${alarmSettings.dateTime.hour.toString().padLeft(2, '0')}:${alarmSettings.dateTime.minute.toString().padLeft(2, '0')}",
            period: alarmSettings.dateTime.hour >= 12 ? "PM" : "AM",
            title: alarmSettings.notificationSettings.body,
            audiopath: alarmSettings.assetAudioPath ?? '',
            isActive: true,
          ),
        );

    try {
      final navState = Unviersalvariables().navigatorKey.currentState;
      if (navState != null) {
        navState
            .push(
              MaterialPageRoute(
                builder: (context) => UiAlarmNotification(
                  alarm: alarmModel,
                  settings: alarmSettings,
                ),
                fullscreenDialog: true,
              ),
            )
            .then((_) {
              _isPushingRoute = false;
              if (mounted) {
                setState(() {});
              }
            });
      } else if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                UiAlarmNotification(alarm: alarmModel, settings: alarmSettings),
            fullscreenDialog: true,
          ),
        ).then((_) {
          _isPushingRoute = false;
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        debugPrint("🔔 Cannot navigate: no navigator available");
        _isPushingRoute = false;
      }
    } catch (e) {
      debugPrint("🔔 Error pushing alarm notification route: $e");
      _isPushingRoute = false;
    }
  }

  Future<void> _checkAndShowRingingAlarm() async {
    try {
      final ringingAlarms = Alarm.ringing.value.alarms;
      if (ringingAlarms.isNotEmpty) {
        debugPrint(
          "🔔 Found ringing alarm in stream: ${ringingAlarms.first.id}, showing overlay...",
        );
        _showAlarmOverlay(ringingAlarms.first);
        return;
      }

      for (final alarm in context.read<AlarmsCubit>().state.alarms) {
        final uniqueId = Alarmsetter.instance.createuniqueid(alarm);
        final isRinging = await Alarm.isRinging(uniqueId);
        if (!mounted) return;
        if (isRinging) {
          debugPrint(
            "🔔 Proactive check: Alarm $uniqueId is ringing natively. Showing overlay.",
          );
          final settings = await Alarm.getAlarm(uniqueId);
          if (!mounted) return;
          if (settings != null) {
            _showAlarmOverlay(settings);
          } else {
            final userSettings = context.read<AlarmsCubit>().state.settings;
            final mockSettings = AlarmSettings(
              id: uniqueId,
              assetAudioPath: alarm.audiopath,
              dateTime: DateTime.now(),
              loopAudio: userSettings.loopAudio,
              vibrate: userSettings.vibrate,
              volumeSettings: VolumeSettings.fixed(
                volume: userSettings.volume,
                volumeEnforced: true,
              ),
              payload: jsonEncode(alarm.toJson()),
              notificationSettings: NotificationSettings(
                title: "🔔 Mist Alarm",
                body: "Time to focus: '${alarm.title}'",
              ),
            );
            _showAlarmOverlay(mockSettings);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint("🔔 Error checking ringing alarms: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPushingRoute = false;
      context.read<AlarmsCubit>().getData();

      _checkAndShowRingingAlarm();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _checkAndShowRingingAlarm();
      });
      Future.delayed(const Duration(milliseconds: 750), () {
        if (mounted) _checkAndShowRingingAlarm();
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) _checkAndShowRingingAlarm();
      });
    }
  }

  Widget _getActiveScreen(int index) {
    switch (index) {
      case 0:
        return const UiHomeScreen();
      case 1:
        return const UiFolderScreen();
      case 2:
        return const UiNodesScreen();
      default:
        return const UiHomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return BlocBuilder<NavigationCubit, int>(
      builder: (context, activeIndex) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: const Color(0xFF0C0C16),
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [
                Positioned(
                  top: 0,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromARGB(180, 0, 254, 72),
                          blurRadius: 80,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  bottom: 10,
                  child: _getActiveScreen(activeIndex),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  left: 24,
                  right: 24,
                  bottom: isKeyboardVisible ? -100 : 24,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isKeyboardVisible ? 0.0 : 1.0,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white70, width: 1.5),
                          color: const Color(0xFF0C0C16).withValues(alpha: 0.92),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(
                              context: context,
                              currentIndex: activeIndex,
                              index: 0,
                              icon: FontAwesomeIcons.house,
                              label: "Home",
                            ),
                            _buildNavItem(
                              context: context,
                              currentIndex: activeIndex,
                              index: 1,
                              icon: FontAwesomeIcons.folder,
                              label: "Folders",
                            ),
                            _buildNavItem(
                              context: context,
                              currentIndex: activeIndex,
                              index: 2,
                              icon: FontAwesomeIcons.circleNodes,
                              label: "Mindmap",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int currentIndex,
    required int index,
    required FaIconData icon,
    required String label,
  }) {
    final bool isActive = currentIndex == index;
    final Color activeColor = index == 0
        ? Colors.indigoAccent
        : index == 1
        ? Colors.amberAccent
        : Colors.tealAccent;

    return GestureDetector(
      onTap: () => context.read<NavigationCubit>().changeIndex(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isActive
                  ? activeColor.withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: FaIcon(
              icon,
              size: 20,
              color: isActive
                  ? activeColor
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? activeColor
                  : Colors.white.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class UiHomeScreen extends StatefulWidget {
  const UiHomeScreen({super.key});

  @override
  State<UiHomeScreen> createState() => _UiHomeScreenState();
}

class _UiHomeScreenState extends State<UiHomeScreen> {
  late Future<bool> _permissionFuture;

  @override
  void initState() {
    super.initState();
    _permissionFuture = PermissionHandler().checkAllPermissions();
  }

  void _refreshPermissions() {
    setState(() {
      _permissionFuture = PermissionHandler().checkAllPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: FutureBuilder<bool>(
          future: _permissionFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data == true) {
                return const UiHomeContent();
              } else {
                return UiPermissionRequestScreen(
                  onGranted: _refreshPermissions,
                );
              }
            } else {
              return const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              );
            }
          },
        ),
      ),
    );
  }
}
