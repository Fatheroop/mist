import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:mist/repo/permission_handler.dart';

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
