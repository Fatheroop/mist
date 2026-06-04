import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/alarmsandremainder.dart';
import 'package:mist/logic/alarmsetter.dart';
import 'package:mist/logic/code_home.dart';
import 'package:mist/logic/unviersalvariables.dart';
import 'package:mist/repo/permission_handler.dart';
import 'package:mist/uis/android/ui_alarm_notification.dart';
import 'package:mist/uis/android/ui_tasks.dart';
import 'package:mist/uis/android/widgets/alarms_and_settings.dart';
import 'package:mist/uis/android/widgets/remainder_widget.dart';
import 'package:alarm/alarm.dart';

class UIHome extends StatefulWidget {
  const UIHome({super.key});

  @override
  State<UIHome> createState() => _UIHomeState();
}

class _UIHomeState extends State<UIHome> with WidgetsBindingObserver {
  final CodeHome _codeHome = CodeHome();
  StreamSubscription? _alarmSubscription;
  bool _isPushingRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _codeHome.addListener(_updateHomeState);
    AlarmsAndSettings.instance.getData();

    // Listen to incoming alarm ring events to show the full screen alert
    _alarmSubscription = Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isNotEmpty) {
        _showAlarmOverlay(alarmSet.alarms.first);
      }
    });

    // Also check immediately if an alarm is already ringing when the app starts
    // (e.g. cold-started by a full-screen intent). The stream value may be set
    // before .listen() is attached, so we need this explicit check.
    // We also retry after short delays because the native alarm bridge may
    // take a moment to report the ringing state on cold start.
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
    _codeHome.removeListener(_updateHomeState);
    _alarmSubscription?.cancel();
    _codeHome.dispose();
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

    // Safely extract the AlarmSettings object if settings is an AlarmSet
    dynamic alarmSettings = settings;
    try {
      if (settings.alarms != null) {
        if (settings.alarms.isEmpty) {
          _isPushingRoute = false;
          return;
        }
        alarmSettings = settings.alarms.first;
      }
    } catch (_) {
      // settings is not an AlarmSet or doesn't have an alarms property, keep as is
    }

    debugPrint(
      "🔔 Alarm ID: ${alarmSettings.id}, navigating to notification screen...",
    );

    // Try to restore the exact AlarmModal from the payload
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

    // Fall back to finding the alarm modal corresponding to these settings to get its details
    final alarmModel =
        payloadAlarm ??
        AlarmsAndSettings.instance.alarms.firstWhere(
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
      // 1. Check if there are any ringing alarms in the stream value
      final ringingAlarms = Alarm.ringing.value.alarms;
      if (ringingAlarms.isNotEmpty) {
        debugPrint(
          "🔔 Found ringing alarm in stream: ${ringingAlarms.first.id}, showing overlay...",
        );
        _showAlarmOverlay(ringingAlarms.first);
        return;
      }

      // 2. Proactively check each known alarm using native Alarm.isRinging
      for (final alarm in AlarmsAndSettings.instance.alarms) {
        final uniqueId = Alarmsetter.instance.createuniqueid(alarm);
        final isRinging = await Alarm.isRinging(uniqueId);
        if (isRinging) {
          debugPrint(
            "🔔 Proactive check: Alarm $uniqueId is ringing natively. Showing overlay.",
          );
          final settings = await Alarm.getAlarm(uniqueId);
          if (settings != null) {
            _showAlarmOverlay(settings);
          } else {
            // Reconstruct mock settings if getAlarm returns null
            final userSettings = AlarmsAndSettings.instance.settings;
            final mockSettings = AlarmSettings(
              id: uniqueId,
              assetAudioPath: alarm.audiopath,
              dateTime: DateTime.now(), // dummy
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

  void _updateHomeState() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset route pushing flag upon resume in case it was interrupted
      _isPushingRoute = false;

      AlarmsAndSettings.instance.getData();

      // If an alarm is actively ringing, show the overlay screen on resume/unlock.
      // We check immediately, and also on a slight delay to allow the native
      // bridge to propagate the ringing state if the app was just cold-started/woken up.
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

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C16), // Premium dark obsidian
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(180, 0, 254, 72),
                      blurRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
            // 2. Active Screen Content
            Positioned.fill(
              bottom: 10, // Leave room for floating bottom dock
              child: _codeHome.getScreen(),
            ),
            // 3. Floating Bottom Navigation Bar Dock
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
                          index: 0,
                          icon: FontAwesomeIcons.house,
                          label: "Home",
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: FontAwesomeIcons.folder,
                          label: "Folders",
                        ),
                        _buildNavItem(
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
  }

  Widget _buildNavItem({
    required int index,
    required FaIconData icon,
    required String label,
  }) {
    final bool isActive = _codeHome.index == index;
    final Color activeColor = index == 0
        ? Colors.indigoAccent
        : index == 1
        ? Colors.amberAccent
        : Colors.tealAccent;

    return GestureDetector(
      onTap: () => _codeHome.changeindex(index),
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
                  onGranted: () {
                    _refreshPermissions();
                  },
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

class UiPermissionRequestScreen extends StatefulWidget {
  final VoidCallback onGranted;

  const UiPermissionRequestScreen({super.key, required this.onGranted});

  @override
  State<UiPermissionRequestScreen> createState() =>
      _UiPermissionRequestScreenState();
}

class _UiPermissionRequestScreenState extends State<UiPermissionRequestScreen>
    with WidgetsBindingObserver {
  bool _notificationGranted = false;
  bool _storageGranted = false;
  bool _alarmGranted = false;
  bool _overlayGranted = false;
  bool _fullScreenGranted = false;
  bool _batteryGranted = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  Future<void> _checkAll() async {
    final handler = PermissionHandler();
    final n = await handler.checkNotificationPermission();
    final s = await handler.checkStoragePermission();
    final a = await handler.checkAlarmPermission();
    final o = await handler.checkSystemAlertWindowPermission();
    final f = await handler.checkFullScreenNotificationPermission();
    final b = await handler.checkBatteryOptimizationPermission();
    if (mounted) {
      setState(() {
        _notificationGranted = n;
        _storageGranted = s;
        _alarmGranted = a;
        _overlayGranted = o;
        _fullScreenGranted = f;
        _batteryGranted = b;
        _checking = false;
      });
      if (n && s && a && o && f) {
        widget.onGranted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.purpleAccent),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: FadeInUp(
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.01),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Colors.amberAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "System Access Required",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "MIST requires credentials to run safely",
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _storageGranted
                    ? null
                    : () async {
                        await PermissionHandler().requestStoragePermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Storage Access",
                  subtitle: "Save, copy, and encrypt vaults securely",
                  isGranted: _storageGranted,
                  icon: Icons.folder_shared_rounded,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _notificationGranted
                    ? null
                    : () async {
                        await PermissionHandler()
                            .requestNotificationPermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Notification Alerts",
                  subtitle: "Send alarms and focus reminders",
                  isGranted: _notificationGranted,
                  icon: Icons.notifications_active_rounded,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _alarmGranted
                    ? null
                    : () async {
                        await PermissionHandler().requestAlarmPermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Precise Task Scheduler",
                  subtitle:
                      "Run lightweight reminders even in background (Tap to Enable)",
                  isGranted: _alarmGranted,
                  icon: Icons.alarm_rounded,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _overlayGranted
                    ? null
                    : () async {
                        await PermissionHandler()
                            .requestSystemAlertWindowPermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Background Pop-up Display",
                  subtitle:
                      "Show alarm and ringing popups while running in background",
                  isGranted: _overlayGranted,
                  icon: Icons.picture_in_picture_alt_rounded,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _fullScreenGranted
                    ? null
                    : () async {
                        await PermissionHandler()
                            .requestFullScreenNotificationPermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Full-Screen Alerts",
                  subtitle:
                      "Allow fullscreen reminders and ring screens on lock screen",
                  isGranted: _fullScreenGranted,
                  icon: Icons.fullscreen_rounded,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _batteryGranted
                    ? null
                    : () async {
                        await PermissionHandler()
                            .requestBatteryOptimizationPermission();
                        await _checkAll();
                      },
                child: _buildPermissionItem(
                  title: "Battery Saver Whitelist",
                  subtitle:
                      "Ensure bulletproof background alarms by disabling battery saver constraints",
                  isGranted: _batteryGranted,
                  icon: Icons.battery_saver_rounded,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () async {
                    await PermissionHandler().requestAllPermissions();
                    await _checkAll();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Authorize Permissions",
                    style: TextStyle(
                      color: Color(0xFF0C0C16),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  "Tip: On some devices (Xiaomi, Oppo, etc.), also enable 'Show on Lock Screen' in Other Permissions.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required String title,
    required String subtitle,
    required bool isGranted,
    required IconData icon,
  }) {
    final statusColor = isGranted ? Colors.tealAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isGranted ? Colors.white70 : Colors.white30,
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isGranted ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : Icons.lock_rounded,
              color: statusColor,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class UiHomeContent extends StatefulWidget {
  const UiHomeContent({super.key});

  @override
  State<UiHomeContent> createState() => _UiHomeContentState();
}

class _UiHomeContentState extends State<UiHomeContent> {
  double _scale = 1.0;
  String currentRemainder = "Swipe left or Right";
  int currentoptions = 0;

  String getTime() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 18) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  void _changeRemainder(int side) {
    currentoptions = currentoptions + side;
    if (currentoptions > 2) {
      currentoptions = 0;
    }
    if (currentoptions < 0) {
      currentoptions = 2;
    }
    switch (currentoptions) {
      case 0:
        currentRemainder = "Alarms";
        break;
      case 1:
        currentRemainder = "Reminders";
        break;
      case 2:
        currentRemainder = "Settings";
        break;
      default:
        side = 1;
        currentRemainder = "Alarms";
        break;
    }
    setState(() {});
  }

  // return widget based on currentoptions
  Widget _getCurrentWidget() {
    switch (currentoptions) {
      case 0:
        return const Alarms();
      case 1:
        return const RemainderWidget();
      case 2:
        return const AlarmsSetting();
      default:
        return const Text(
          "Hello no i find an error",
          style: TextStyle(color: Colors.red),
        );
    }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.96;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  /// Saves the screenshot bytes to a temporary file and sends the feedback email.
  Future<void> _sendFeedbackEmail(UserFeedback feedback) async {
    try {
      // Save screenshot to a temp file so the email client can attach it
      final Directory tempDir = await getTemporaryDirectory();
      final String screenshotPath =
          '${tempDir.path}/mist_feedback_${DateTime.now().millisecondsSinceEpoch}.png';
      final File screenshotFile = File(screenshotPath);
      await screenshotFile.writeAsBytes(feedback.screenshot);

      final Email email = Email(
        subject: 'Mist App — Bug Report / Feedback',
        body: feedback.text,
        recipients: ['t8268826@gmail.com'],
        attachmentPaths: [screenshotPath],
      );

      await FlutterEmailSender.send(email);
    } catch (e) {
      debugPrint('📧 Error sending feedback email: $e');
    }
  }

  /// Premium-styled feedback / bug-report button with glassmorphic design.
  Widget _buildFeedbackButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        BetterFeedback.of(context).show((feedback) async {
          await _sendFeedbackEmail(feedback);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
              ).createShader(bounds),
              child: const Icon(
                Icons.bug_report_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Feedback',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bordercolor = Color.fromARGB(42, 255, 255, 255);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        bottom: 120,
      ), // Bottom padding for the navigation bar dock
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${getTime()}, Yogesh",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildFeedbackButton(context),
            ],
          ),
          const SizedBox(height: 24),
          // Original Tasks Workspace Button
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const UiTasks(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;

                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
                        var fadeAnimation = animation.drive(fadeTween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(
                            opacity: fadeAnimation,
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: bordercolor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: const FaIcon(
                        FontAwesomeIcons.listCheck,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Tasks Workspace",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Organize checklists & daily tracking",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          // creating an swiper alarm and remainder changes.
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _changeRemainder(1);
              }
              if (details.primaryVelocity! < 0) {
                _changeRemainder(-1);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bordercolor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                textAlign: TextAlign.center,
                currentRemainder,
                style: TextStyle(
                  color: const Color.fromARGB(209, 255, 255, 255),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bordercolor),
            ),
            child: _getCurrentWidget(),
          ).fadeIn(
            duration: Duration(milliseconds: 500),
            key: ValueKey<int>(currentoptions),
          ),
        ],
      ),
    );
  }
}
