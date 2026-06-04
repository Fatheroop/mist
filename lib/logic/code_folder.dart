import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mist/repo/permission_handler.dart';

class CodeFolder extends ChangeNotifier {
  // singleton class
  static final CodeFolder _instance = CodeFolder._();
  static CodeFolder get instance => _instance;
  CodeFolder._();

  Directory? baseDirectory;
  Directory? currentDirectory;
  List<FileSystemEntity> items = [];
  bool isStoragePermissionGranted = false;
  bool isLoading = true;
  bool isDecoyActive = false;

  Directory get effectiveDirectory {
    if (isDecoyActive && currentDirectory != null) {
      if (!currentDirectory!.path.contains('/.decoy_data')) {
        return Directory('${currentDirectory!.path}/.decoy_data');
      }
    }
    return currentDirectory!;
  }

  bool get isRoot => currentDirectory?.path == baseDirectory?.path;

  Future<void> checkPermissionAndInit() async {
    final granted = await PermissionHandler().checkStoragePermission();
    isStoragePermissionGranted = granted;
    notifyListeners();

    if (granted) {
      await initVaultDirectory();
    } else {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initVaultDirectory() async {
    isLoading = true;
    notifyListeners();

    // Multiplatform directory fallback
    Directory? externalDir;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        externalDir = await getExternalStorageDirectory();
      } catch (_) {}
    }
    externalDir ??= await getApplicationDocumentsDirectory();

    // Get external storage root to persist data even after app uninstall
    String rootPath = externalDir.path;
    debugPrint("CodeFolder: external storage path: $rootPath");
    if (rootPath.contains('/Android/data')) {
      rootPath = rootPath.split('/Android/data').first;
    }

    baseDirectory = Directory('$rootPath/StudentMist');
    if (!await baseDirectory!.exists()) {
      await baseDirectory!.create(recursive: true);
    }
    currentDirectory = baseDirectory;
    await refreshFiles();
  }

  Future<void> refreshFiles({void Function(String err)? onError}) async {
    if (currentDirectory == null) return;

    isLoading = true;
    notifyListeners();

    try {
      final dir = effectiveDirectory;
      if (isDecoyActive && !dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      if (isDecoyActive && dir.existsSync()) {
        final defaultDecoy = File('${dir.path}/Public Study Notes.txt');
        if (!defaultDecoy.existsSync()) {
          defaultDecoy.writeAsStringSync(
            "Welcome to the Student Study Vault!\n\n"
            "This public study folder contains default tutorial notes and tips to optimize your study routines.\n\n"
            "Tip 1: Use active recall and spaced repetition for vocabulary and concept learning.\n"
            "Tip 2: Mind maps help connect complex topics. Try out the Nodes tab!\n"
            "Tip 3: Structure your study sessions using Pomodoro techniques for maximum efficiency.",
          );
        }
      }

      final list = dir.listSync();
      // Exclude hidden files
      final filteredList = list.where((entity) {
        final name = entity.path.split('/').last;
        return !name.startsWith('.');
      }).toList();

      // Sort: Folders first, then note files
      filteredList.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });

      items = filteredList;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      if (onError != null) {
        onError("Error reading directory: $e");
      }
    }
  }

  // Vault Config Helpers (JSON metadata)
  bool isFolderLocked(Directory dir) {
    final metaFile = File('${dir.path}/.vault_meta');
    if (metaFile.existsSync()) {
      try {
        final content = metaFile.readAsStringSync();
        final data = jsonDecode(content);
        return data['isLocked'] ?? false;
      } catch (_) {}
    }
    // Fallback to legacy passcode lock file
    final lockFile = File('${dir.path}/.vault_lock');
    return lockFile.existsSync();
  }

  String? getFolderPIN(Directory dir) {
    final metaFile = File('${dir.path}/.vault_meta');
    if (metaFile.existsSync()) {
      try {
        final content = metaFile.readAsStringSync();
        final data = jsonDecode(content);
        return data['pin']?.toString();
      } catch (_) {}
    }
    // Fallback to legacy passcode lock file
    final lockFile = File('${dir.path}/.vault_lock');
    if (lockFile.existsSync()) {
      return lockFile.readAsStringSync().trim();
    }
    return null;
  }

  String? getDecoyPIN(Directory dir) {
    final metaFile = File('${dir.path}/.vault_meta');
    if (metaFile.existsSync()) {
      try {
        final content = metaFile.readAsStringSync();
        final data = jsonDecode(content);
        return data['decoyPin']?.toString();
      } catch (_) {}
    }
    return null;
  }

  Map<String, String> getVaultRecoveryInfo(Directory dir) {
    final metaFile = File('${dir.path}/.vault_meta');
    if (metaFile.existsSync()) {
      try {
        final content = metaFile.readAsStringSync();
        final data = jsonDecode(content);
        return {
          "question": data['securityQuestion']?.toString() ?? "",
          "answer": data['securityAnswer']?.toString() ?? "",
          "hint": data['passcodeHint']?.toString() ?? "",
          "pin": data['pin']?.toString() ?? "",
        };
      } catch (_) {}
    }
    return {"question": "", "answer": "", "hint": "", "pin": ""};
  }

  Color getVaultColor(Directory dir) {
    return Colors.white;
  }

  FaIconData getVaultIcon(Directory dir) {
    final metaFile = File('${dir.path}/.vault_meta');
    if (metaFile.existsSync()) {
      try {
        final content = metaFile.readAsStringSync();
        final data = jsonDecode(content);
        final iconName = data['icon']?.toString();
        switch (iconName) {
          case 'shield':
            return FontAwesomeIcons.shieldHalved;
          case 'lock':
            return FontAwesomeIcons.lock;
          case 'key':
            return FontAwesomeIcons.key;
          case 'secret':
            return FontAwesomeIcons.userSecret;
          case 'graduate':
            return FontAwesomeIcons.userGraduate;
          case 'book':
            return FontAwesomeIcons.bookOpen;
          case 'eye-slash':
            return FontAwesomeIcons.eyeSlash;
          case 'vault':
          default:
            return FontAwesomeIcons.vault;
        }
      } catch (_) {}
    }
    return FontAwesomeIcons.folder;
  }

  void navigateToDirectory(Directory dir, {bool? keepDecoy}) {
    final shouldKeepDecoy =
        keepDecoy ?? (isDecoyActive && dir.path.contains('/.decoy_data'));
    currentDirectory = dir;
    isDecoyActive = shouldKeepDecoy;
    refreshFiles();
  }

  void goBack() {
    if (baseDirectory == null || currentDirectory == null) return;
    if (currentDirectory!.path == baseDirectory!.path) return;

    final parent = currentDirectory!.parent;
    navigateToDirectory(parent);
  }

  // File system CRUD handlers
  Future<String?> createNewFolder(String name) async {
    if (currentDirectory == null) return "No active directory";
    final cleanName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), "").trim();
    if (cleanName.isEmpty) return "Folder name cannot be empty";

    final dir = effectiveDirectory;
    final newDir = Directory('${dir.path}/$cleanName');
    if (await newDir.exists()) {
      return "A folder with this name already exists";
    }

    try {
      await newDir.create();
      await refreshFiles();
      return null;
    } catch (e) {
      return "Folder creation failed: $e";
    }
  }

  Future<String?> createNewVault(
    String name,
    String pin,
    String decoyPin,
    String securityQuestion,
    String securityAnswer,
    String passcodeHint,
    String colorName,
    String iconName,
  ) async {
    if (currentDirectory == null) return "No active directory";
    final cleanName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), "").trim();
    if (cleanName.isEmpty) return "Vault name cannot be empty";

    final dir = effectiveDirectory;
    final newDir = Directory('${dir.path}/$cleanName');
    if (await newDir.exists()) {
      return "A folder with this name already exists";
    }

    try {
      await newDir.create();

      // Save metadata in .vault_meta
      final metaFile = File('${newDir.path}/.vault_meta');
      final metaData = {
        "pin": pin,
        "decoyPin": decoyPin,
        "securityQuestion": securityQuestion,
        "securityAnswer": securityAnswer,
        "passcodeHint": passcodeHint,
        "color": colorName,
        "icon": iconName,
        "isLocked": true,
      };
      await metaFile.writeAsString(jsonEncode(metaData));

      await refreshFiles();
      return null;
    } catch (e) {
      return "Vault creation failed: $e";
    }
  }

  Future<File?> createNewNote(
    String name, {
    required void Function(String err) onError,
  }) async {
    if (currentDirectory == null) return null;
    var cleanName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), "").trim();
    if (cleanName.isEmpty) cleanName = "Untitled Note";

    final dir = effectiveDirectory;
    final file = File('${dir.path}/$cleanName.txt');
    if (await file.exists()) {
      onError("A study note with this name already exists");
      return null;
    }

    try {
      await file.create();
      await refreshFiles();
      return file;
    } catch (e) {
      onError("Failed to create note: $e");
      return null;
    }
  }

  Future<String> updateFlashcards(String? name, String data) async {
    final dir = effectiveDirectory;
    int count = 0;
    if (name == null) {
      final list = dir.listSync();
      for (FileSystemEntity entity in list) {
        if (entity.path.endsWith('.flashcard')) {
          if (entity.path
              .split('/')
              .last
              .split('.')
              .first
              .contains("Untitled_flashcard")) {
            count++;
          }
        }
      }
      name = "Untitled_flashcard_$count";
    } else {
      name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), "").trim();
    }
    final file = File('${dir.path}/$name.flashcard');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(data);
    return "Success";
  }

  Future<String> getFlashcards(String name) async {
    final dir = effectiveDirectory;
    final file = File('${dir.path}/$name.flashcard');
    if (!await file.exists()) {
      return "File not found";
    }
    return await file.readAsString();
  }

  Future<String?> deleteEntity(FileSystemEntity entity) async {
    try {
      await entity.delete(recursive: true);
      await refreshFiles();
      return null;
    } catch (e) {
      return "Could not delete item: $e";
    }
  }

  Future<String?> renameEntity(FileSystemEntity entity, String newName) async {
    final cleanName = newName.replaceAll(RegExp(r'[\\/:*?"<>|]'), "").trim();
    if (cleanName.isEmpty) return "Name cannot be empty";

    final parentPath = entity.parent.path;
    final extension = entity is File ? ".txt" : "";
    final newPath = '$parentPath/$cleanName$extension';

    try {
      await entity.rename(newPath);
      await refreshFiles();
      return null;
    } catch (e) {
      return "Rename failed: $e";
    }
  }

  Future<String?> lockFolder(
    Directory dir,
    String pin,
    String decoyPin,
    String securityQuestion,
    String securityAnswer,
    String passcodeHint,
  ) async {
    try {
      final metaFile = File('${dir.path}/.vault_meta');
      final metaData = {
        "pin": pin,
        "decoyPin": decoyPin,
        "securityQuestion": securityQuestion,
        "securityAnswer": securityAnswer,
        "passcodeHint": passcodeHint,
        "color": "amber",
        "icon": "vault",
        "isLocked": true,
      };
      await metaFile.writeAsString(jsonEncode(metaData));
      await refreshFiles();
      return null;
    } catch (e) {
      return "Failed to encrypt: $e";
    }
  }

  Future<String?> unlockFolder(Directory dir) async {
    try {
      final metaFile = File('${dir.path}/.vault_meta');
      if (metaFile.existsSync()) {
        await metaFile.delete();
      }
      final lockFile = File('${dir.path}/.vault_lock');
      if (lockFile.existsSync()) {
        await lockFile.delete();
      }
      await refreshFiles();
      return null;
    } catch (e) {
      return "Failed to decrypt: $e";
    }
  }

  // Custom Recursive Copy
  Future<String?> copyEntity(FileSystemEntity source, Directory target) async {
    final name = source.path.split('/').last;
    final targetPath = '${target.path}/$name';

    try {
      if (source is File) {
        await source.copy(targetPath);
      } else if (source is Directory) {
        await copyDirectory(source, Directory(targetPath));
      }
      await refreshFiles();
      return null;
    } catch (e) {
      return "Copy failed: $e";
    }
  }

  Future<void> copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDir = Directory(
          '${destination.path}/${entity.path.split('/').last}',
        );
        await copyDirectory(entity, newDir);
      } else if (entity is File) {
        final newFile = File(
          '${destination.path}/${entity.path.split('/').last}',
        );
        await entity.copy(newFile.path);
      }
    }
  }

  Future<String?> moveEntity(FileSystemEntity source, Directory target) async {
    final name = source.path.split('/').last;
    final targetPath = '${target.path}/$name';

    try {
      await source.rename(targetPath);
      await refreshFiles();
      return null;
    } catch (e) {
      return "Move failed: $e";
    }
  }

  List<Directory> getAllSubfolders() {
    if (baseDirectory == null) return [];
    final List<Directory> dirs = [baseDirectory!];
    traverseSubfolders(baseDirectory!, dirs);
    return dirs;
  }

  void traverseSubfolders(Directory dir, List<Directory> result) {
    try {
      final list = dir.listSync(recursive: false);
      for (var entity in list) {
        if (entity is Directory) {
          final name = entity.path.split('/').last;
          if (!name.startsWith('.')) {
            result.add(entity);
            if (!isFolderLocked(entity)) {
              traverseSubfolders(entity, result);
            }
          }
        }
      }
    } catch (_) {}
  }
}
