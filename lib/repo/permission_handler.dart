import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHandler {
  static const MethodChannel _batteryChannel = MethodChannel(
    'com.example.mist/battery',
  );
  static const MethodChannel _fullscreenChannel = MethodChannel(
    'com.example.mist/fullscreen',
  );

  Future<bool> isAndroid11OrAbove() async {
    if (!Platform.isAndroid) return false;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final apiMatch = RegExp(r'API\s+(\d+)').firstMatch(versionStr);
      if (apiMatch != null) {
        final apiLevel = int.tryParse(apiMatch.group(1) ?? '');
        if (apiLevel != null) {
          return apiLevel >= 30;
        }
      }
      final androidMatch = RegExp(r'Android\s+(\d+)').firstMatch(versionStr);
      if (androidMatch != null) {
        final majorVersion = int.tryParse(androidMatch.group(1) ?? '');
        if (majorVersion != null) {
          return majorVersion >= 11;
        }
      }
    } catch (_) {}
    return true; // Default fallback to true for safety on newer devices
  }

  Future<bool> isAndroid12OrAbove() async {
    if (!Platform.isAndroid) return false;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final apiMatch = RegExp(r'API\s+(\d+)').firstMatch(versionStr);
      if (apiMatch != null) {
        final apiLevel = int.tryParse(apiMatch.group(1) ?? '');
        if (apiLevel != null) {
          return apiLevel >= 31;
        }
      }
      final androidMatch = RegExp(r'Android\s+(\d+)').firstMatch(versionStr);
      if (androidMatch != null) {
        final majorVersion = int.tryParse(androidMatch.group(1) ?? '');
        if (majorVersion != null) {
          return majorVersion >= 12;
        }
      }
    } catch (_) {}
    return true; // Default fallback to true for safety on newer devices
  }

  Future<bool> checkAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    final n = await checkNotificationPermission();
    final s = await checkStoragePermission();
    final a = await checkAlarmPermission();
    final o = await checkSystemAlertWindowPermission();
    final f = await checkFullScreenNotificationPermission();
    return n && s && a && o && f;
  }

  Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    if (Platform.isIOS) {
      return true;
    }
    if (await isAndroid11OrAbove()) {
      return await Permission.manageExternalStorage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    return await Permission.notification.isGranted;
  }

  Future<bool> checkAlarmPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    if (Platform.isIOS) {
      return true;
    }
    try {
      final bool? allowed = await _fullscreenChannel.invokeMethod<bool>(
        'isExactAlarmAllowed',
      );
      return allowed ?? true;
    } catch (_) {
      if (await isAndroid12OrAbove()) {
        return await Permission.scheduleExactAlarm.isGranted;
      }
      return true;
    }
  }

  Future<bool> checkSystemAlertWindowPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    if (Platform.isIOS) {
      return true;
    }
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Checks full screen intent permission using the native NotificationManager
  /// on Android 14+ (API 34). On older versions, the manifest declaration is sufficient.
  Future<bool> checkFullScreenNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    if (Platform.isIOS) {
      return true;
    }
    try {
      final bool? allowed = await _fullscreenChannel.invokeMethod<bool>(
        'isFullScreenIntentAllowed',
      );
      return allowed ?? true;
    } catch (_) {
      // If the channel call fails (e.g. older Android), fall back to true
      // since the manifest declaration is sufficient pre-Android 14.
      return true;
    }
  }

  Future<bool> checkBatteryOptimizationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? isIgnoring = await _batteryChannel.invokeMethod<bool>(
        'isBatteryOptimizationDisabled',
      );
      return isIgnoring ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestBatteryOptimizationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      if (!status.isGranted) {
        await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
      }
    } catch (_) {
      try {
        await _batteryChannel.invokeMethod('requestDisableBatteryOptimization');
      } catch (_) {}
    }
  }

  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    if (Platform.isIOS) {
      return;
    }
    if (await isAndroid11OrAbove()) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isDenied) {
        await Permission.manageExternalStorage.request();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } else {
      final status = await Permission.storage.status;
      if (status.isDenied) {
        await Permission.storage.request();
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> requestAlarmPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    if (Platform.isIOS) {
      return;
    }
    try {
      await _fullscreenChannel.invokeMethod('requestExactAlarmPermission');
    } catch (_) {
      if (await isAndroid12OrAbove()) {
        final status = await Permission.scheduleExactAlarm.status;
        if (status.isDenied || status.isPermanentlyDenied) {
          await Permission.scheduleExactAlarm.request();
        }
      }
    }
  }

  Future<void> requestSystemAlertWindowPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    if (Platform.isIOS) {
      return;
    }
    final status = await Permission.systemAlertWindow.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      await Permission.systemAlertWindow.request();
    }
  }

  /// Opens the Android 14+ full screen intent settings page via native MethodChannel.
  /// Falls back to generic openAppSettings() if the native call fails.
  Future<void> requestFullScreenNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    if (Platform.isIOS) {
      return;
    }
    try {
      await _fullscreenChannel.invokeMethod('requestFullScreenIntent');
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    if (Platform.isIOS) {
      await requestNotificationPermission();
      return;
    }

    // On Android, request them sequentially to let system prompt appear for as many as possible
    debugPrint("Permission handler requesting storage");
    if (await isAndroid11OrAbove()) {
      final storageStatus = await Permission.manageExternalStorage.status;
      if (storageStatus.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    } else {
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }
    }

    debugPrint("Permission handler requesting notification");
    final notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      await Permission.notification.request();
    }

    debugPrint("Permission handler requesting alarm");
    if (await isAndroid12OrAbove()) {
      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied || alarmStatus.isPermanentlyDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    debugPrint("Permission handler requesting overlay/system alert window");
    final systemAlertStatus = await Permission.systemAlertWindow.status;
    if (systemAlertStatus.isDenied || systemAlertStatus.isPermanentlyDenied) {
      await Permission.systemAlertWindow.request();
    }

    // Check if any required permissions are permanently denied, then open App Settings
    bool hasPermanentlyDenied = false;

    if (await isAndroid11OrAbove()) {
      if (await Permission.manageExternalStorage.isPermanentlyDenied) {
        hasPermanentlyDenied = true;
      }
    } else {
      if (await Permission.storage.isPermanentlyDenied) {
        hasPermanentlyDenied = true;
      }
    }

    if (await Permission.notification.isPermanentlyDenied) {
      hasPermanentlyDenied = true;
    }

    if (await Permission.systemAlertWindow.isPermanentlyDenied) {
      hasPermanentlyDenied = true;
    }

    if (hasPermanentlyDenied) {
      await openAppSettings();
    }

    debugPrint("Permission handler requesting full screen intent");
    final fullScreenGranted = await checkFullScreenNotificationPermission();
    if (!fullScreenGranted) {
      await requestFullScreenNotificationPermission();
    }

    debugPrint("Permission handler requesting battery optimization");
    final batteryGranted = await checkBatteryOptimizationPermission();
    if (!batteryGranted) {
      await requestBatteryOptimizationPermission();
    }
  }
}
