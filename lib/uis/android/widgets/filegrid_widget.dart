import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/logic/folder_cubit.dart';
import 'package:mist/uis/android/ui_canvas.dart';
import 'package:mist/uis/android/ui_flash_cards.dart';
import 'package:mist/uis/android/widgets/study_note_editor.dart';

class FilegridWidget {
  final FileSystemEntity entity;
  late Filetype type;
  VoidCallback actiononfolder;
  final FolderCubit _logic;
  bool isLocked = false;
  late Color accentColors;
  late String name;

  // defining file type
  Filetype _getfiletype(FileSystemEntity item) {
    final String suffix = item.path.split('/').last.split('.').last;
    if (item is Directory) {
      return Filetype.folder;
    }
    return switch (suffix) {
      'md' => Filetype.texteditor,
      'flashcard' => Filetype.flashcard,
      'text' || 'txt' => Filetype.texteditor,
      'canvas' => Filetype.canvas,
      String() => Filetype.unknown,
      // String() => throw UnimplementedError(),
    };
  }

  // default constructor to set type, isdir, is locked, name, accent Color
  FilegridWidget({
    required this.entity,
    required this.actiononfolder,
    required FolderCubit folderCubit,
  }) : _logic = folderCubit {
    type = _getfiletype(entity);
    final bool isDir = entity is Directory;
    accentColors = isDir
        ? _logic.getVaultColor(entity as Directory)
        : Colors.white;

    if (entity is Directory) {
      isLocked = _logic.isFolderLocked(entity as Directory);
    }
    final String lastSegment = entity.path.split("/").last;
    final int dotIndex = lastSegment.lastIndexOf('.');
    name = dotIndex == -1 ? lastSegment : lastSegment.substring(0, dotIndex);
  }

  // navigating to given widget
  void _nagaitatetowidget(BuildContext context, Widget widget) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => widget),
    ).then((_) => _logic.refreshFiles());
  }

  // handle navigation
  void navigate(BuildContext context) {
    // final navigation = (Widget widget){ Navigator.push(context, MaterialPageRoute(builder: (context) => widget));};
    switch (type) {
      case Filetype.folder:
        actiononfolder();
        break;
      case Filetype.flashcard:
        _nagaitatetowidget(context, UiFlashCards(filename: name));
        break;
      case Filetype.texteditor:
        _nagaitatetowidget(
          context,
          StudyNoteEditorScreen(
            file: entity as File,
            onSave: _logic.refreshFiles,
          ),
        );
        break;
      case Filetype.canvas:
        _nagaitatetowidget(context, CanvasHome(file: File(entity.path)));
        break;
      case Filetype.unknown:
        _nagaitatetowidget(context, const _UnsupportedFileScreen());
        break;
    }
  }

  // get subtitle of file
  String getSubtitle() {
    return switch (type) {
      Filetype.folder => 'Tap to open Directory',
      Filetype.texteditor => 'Text File',
      Filetype.flashcard => 'Flash Cards File',
      Filetype.canvas => 'Canvas File',
      Filetype.unknown => 'Unknown File',
    };
  }

  // getting icon of file
  FaIconData getIcon() {
    return switch (type) {
      Filetype.folder => _logic.getVaultIcon(entity as Directory),
      Filetype.texteditor => FontAwesomeIcons.solidFileLines,
      Filetype.flashcard => FontAwesomeIcons.stackExchange,
      Filetype.canvas => FontAwesomeIcons.penToSquare,
      Filetype.unknown => FontAwesomeIcons.file,
      // String() => throw UnimplementedError(),
    };
  }
}

enum Filetype { folder, texteditor, flashcard, canvas, unknown }

class _UnsupportedFileScreen extends StatelessWidget {
  const _UnsupportedFileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Stack(
        children: [
          // Top-left ambient glow
          Positioned(
            left: -80,
            top: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: const SizedBox(),
              ),
            ),
          ),
          // Center-right ambient glow
          Positioned(
            right: -50,
            bottom: 100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox(),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Icon with glowing card background
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.02),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withValues(alpha: 0.2),
                            Colors.orangeAccent.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const FaIcon(
                        FontAwesomeIcons.fileCircleExclamation,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Error Title
                  const Text(
                    "Unsupported Format",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description text
                  Text(
                    "This file cannot be read by this application. Please try opening supported files in your workspace.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Supported Formats box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SUPPORTED FILES",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFormatBadge(
                              ".txt or .text",
                              "Notes",
                              FontAwesomeIcons.solidFileLines,
                            ),
                            _buildFormatBadge(
                              ".canvas",
                              "Canvas",
                              FontAwesomeIcons.penToSquare,
                            ),
                            _buildFormatBadge(
                              ".flashcard",
                              "Flashcards",
                              FontAwesomeIcons.boxesStacked,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Action Button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE5E5E5), Colors.white],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Go Back",
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(String ext, String label, FaIconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: FaIcon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ext,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
