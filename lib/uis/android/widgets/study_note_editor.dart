import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mist/uis/android/widgets/premium_toast.dart';

class StudyNoteEditorScreen extends StatefulWidget {
  final File file;
  final VoidCallback onSave;

  const StudyNoteEditorScreen({
    super.key,
    required this.file,
    required this.onSave,
  });

  @override
  State<StudyNoteEditorScreen> createState() => _StudyNoteEditorScreenState();
}

class _StudyNoteEditorScreenState extends State<StudyNoteEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool isSaving = false;
  int wordCount = 0;
  int charCount = 0;
  Timer? time;

  @override
  void initState() {
    super.initState();
    _loadNoteData();
    _bodyController.addListener(_updateCounts);
    time = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveNote();
    });
  }

  @override
  void dispose() {
    time?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _loadNoteData() {
    final title = widget.file.path.split('/').last.replaceAll(".txt", "");
    _titleController.text = title;

    try {
      final content = widget.file.readAsStringSync();
      _bodyController.text = content;
    } catch (_) {}
    _updateCounts();
  }

  void _updateCounts() {
    final text = _bodyController.text;
    setState(() {
      charCount = text.length;
      wordCount = text.trim().isEmpty
          ? 0
          : text.trim().split(RegExp(r'\s+')).length;
    });
  }

  Future<void> _saveNote() async {
    setState(() {
      isSaving = true;
    });

    try {
      // Save Body Content
      await widget.file.writeAsString(_bodyController.text);

      // Save Title Content (rename file if title changed!)
      var cleanTitle = _titleController.text
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "")
          .trim();

      if (cleanTitle.length > 40) {
        cleanTitle = "${cleanTitle.substring(0, 20)}...";
      }
      final currentTitle = widget.file.path
          .split('/')
          .last
          .replaceAll(".txt", "");
      if (_checksamefileexist(widget.file, cleanTitle)) {
        widget.onSave();
        return;
      }
      if (cleanTitle.isNotEmpty && cleanTitle != currentTitle) {
        final parentPath = widget.file.parent.path;
        final newPath = '$parentPath/$cleanTitle.txt';
        await widget.file.rename(newPath);
      }
      widget.onSave();
    } catch (_) {}

    setState(() {
      isSaving = false;
    });
  }

  bool _checksamefileexist(File file, String title) {
    try {
      List<FileSystemEntity> files = file.parent.listSync();
      for (FileSystemEntity f in files) {
        String filename = f.path.split("/").last;
        if (filename == "$title.txt") {
          showPremiumToast(
            context,
            "Same name file exists: $filename",
            isError: true,
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C16),
        body: Stack(
          children: [
            // Glow orbs matching Mist app aesthetic
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amberAccent.withValues(alpha: 0.08),
                ),
              ),
            ),

            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.shrink(),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Editor App Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                // Auto-save on exit
                                await _saveNote();
                                navigator.pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Study Note Editor",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Auto-saves on exit",
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: isSaving ? null : _saveNote,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.amberAccent,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_rounded,
                                  color: Colors.amberAccent,
                                  size: 24,
                                ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // Note Content Fields
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          cursorColor: Colors.amberAccent,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Untitled Note",
                            hintStyle: TextStyle(
                              color: Colors.white24,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _bodyController,
                          maxLines: null,
                          minLines: 15,
                          cursorColor: Colors.amberAccent,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 15,
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                "Start writing your lecture & review notes here...",
                            hintStyle: TextStyle(
                              color: Colors.white24,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom statistics status strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF131324),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$wordCount words  |  $charCount characters",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_done_rounded,
                              color: Colors.tealAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Persistent Sync Active",
                              style: TextStyle(
                                color: Colors.tealAccent.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
