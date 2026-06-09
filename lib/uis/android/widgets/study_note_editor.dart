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

  /// Mutable reference to the current file — updated after renames so that
  /// subsequent saves always write to the correct path instead of recreating
  /// the original file (which was the root cause of duplicates).
  late File _currentFile;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.file;
    _loadNoteData();
    _bodyController.addListener(_updateCounts);
    time = Timer.periodic(const Duration(seconds: 5), (_) {
      // Guard: skip if a save is already in flight to prevent race conditions
      if (!isSaving) {
        _saveNote();
      }
    });
  }

  @override
  void dispose() {
    time?.cancel();
    // Final save on dispose to capture any last-second edits.
    // Use the sync path to guarantee it completes before teardown.
    try {
      _currentFile.writeAsStringSync(_bodyController.text);
    } catch (_) {}
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _loadNoteData() {
    final title = _currentFile.path.split('/').last.replaceAll(".txt", "");
    _titleController.text = title;

    try {
      final content = _currentFile.readAsStringSync();
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
    if (isSaving) return; // Prevent concurrent saves
    setState(() {
      isSaving = true;
    });

    try {
      // 1. Compute the desired title (sanitised, clamped)
      var cleanTitle = _titleController.text
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), "")
          .trim();

      if (cleanTitle.length > 40) {
        cleanTitle = cleanTitle.substring(0, 40);
      }
      if (cleanTitle.isEmpty) {
        cleanTitle = "Untitled Note";
      }

      // 2. Determine current on-disk title from _currentFile
      final currentTitle = _currentFile.path
          .split('/')
          .last
          .replaceAll(".txt", "");

      // 3. Always write body content to the CURRENT file first
      await _currentFile.writeAsString(_bodyController.text);

      // 4. If the title hasn't changed, we're done
      if (cleanTitle == currentTitle) {
        widget.onSave();
        return;
      }

      // 5. Title changed — check for name collision with OTHER files
      if (_checkDuplicateExists(cleanTitle)) {
        // A different file with this name already exists; don't rename.
        widget.onSave();
        return;
      }

      // 6. Perform the rename and UPDATE _currentFile to the new path
      final parentPath = _currentFile.parent.path;
      final newPath = '$parentPath/$cleanTitle.txt';
      final renamedFile = await _currentFile.rename(newPath);
      _currentFile = renamedFile;

      widget.onSave();
    } catch (_) {}

    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }

  /// Returns true if a DIFFERENT file with `title.txt` already exists in the
  /// same directory. Excludes the current file from the check by comparing
  /// paths (not object identity, which was the old bug).
  bool _checkDuplicateExists(String title) {
    try {
      final currentPath = _currentFile.path;
      final files = _currentFile.parent.listSync();
      for (final f in files) {
        // Skip the file we're currently editing
        if (f.path == currentPath) continue;
        final filename = f.path.split("/").last;
        if (filename == "$title.txt") {
          if (mounted) {
            showPremiumToast(
              context,
              "Same name file exists: $filename",
              isError: true,
            );
          }
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
