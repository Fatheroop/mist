import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class UiTasks extends StatefulWidget {
  const UiTasks({super.key});

  @override
  State<UiTasks> createState() => _UiTasksState();
}

class _UiTasksState extends State<UiTasks> {
  List<CheckboxItem> checkboxes = [];
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _loadTasks();

    // Auto-focus the first incomplete item after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (checkboxes.isNotEmpty) {
        checkboxes[0].node.requestFocus();
      }
    });

    // Automatically save tasks to storage every 5 seconds
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveTasks();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveTasks(); // Perform a final save on exit
    for (var item in checkboxes) {
      item.dispose();
    }
    super.dispose();
  }

  Future<File> _getTasksFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tasks.json');
  }

  Future<void> _loadTasks() async {
    try {
      final file = await _getTasksFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        if (decoded.isNotEmpty) {
          final loaded = decoded.map((item) {
            return _createItem(
              text: item['text'] ?? '',
              isChecked: item['isChecked'] ?? false,
            );
          }).toList();
          setState(() {
            checkboxes = loaded;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error loading tasks: $e");
    }

    // Default tasks if no saved tasks or error
    setState(() {
      checkboxes = [
        _createItem(
          text: "🚀 Create mindmap visualization concept",
          isChecked: false,
        ),
        _createItem(
          text: "🎨 Define harmonized amber glow color scheme",
          isChecked: true,
        ),
        _createItem(
          text: "📝 Integrate premium glassmorphism layouts",
          isChecked: false,
        ),
        _createItem(
          text: "🛠 Fix focus nodes and RangeError exceptions",
          isChecked: true,
        ),
      ];
    });
  }

  Future<void> _saveTasks() async {
    try {
      final file = await _getTasksFile();
      final data = jsonEncode(
        checkboxes
            .map(
              (item) => {
                'text': item.controller.text,
                'isChecked': item.isChecked,
              },
            )
            .toList(),
      );
      await file.writeAsString(data);
    } catch (e) {
      debugPrint("Error saving tasks: $e");
    }
  }

  CheckboxItem _createItem({String text = "", bool isChecked = false}) {
    final item = CheckboxItem(text: text, isChecked: isChecked);
    item.node.addListener(() {
      if (mounted) {
        setState(() {}); // Rebuild to update focus indicators
      }
    });
    return item;
  }

  int get totalTasks => checkboxes.length;
  int get completedTasks => checkboxes.where((item) => item.isChecked).length;
  double get progressPercent =>
      totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  void _handleBackspace(int index) {
    if (index == 0) return; // Can't merge the first item upwards

    final currentItem = checkboxes[index];
    final prevItem = checkboxes[index - 1];

    final currentText = currentItem.controller.text;
    final prevText = prevItem.controller.text;
    final junctionPoint = prevText.length;

    // Merge text into the previous item
    prevItem.controller.text = prevText + currentText;

    // Remove the current item
    setState(() {
      checkboxes.removeAt(index);
    });

    // Request focus and place the cursor exactly at the junction point
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prevItem.node.requestFocus();
      prevItem.controller.selection = TextSelection.collapsed(
        offset: junctionPoint,
      );
    });

    // Clean up resources of the deleted item
    currentItem.dispose();
  }

  void _handleEnter(int index) {
    final currentItem = checkboxes[index];
    final currentText = currentItem.controller.text;
    final selection = currentItem.controller.selection;

    String textForCurrent = currentText;
    String textForNew = "";

    // Partition text at cursor position if cursor is active
    if (selection.isValid) {
      final start = selection.start;
      textForCurrent = currentText.substring(0, start);
      textForNew = currentText.substring(start);
    }

    currentItem.controller.text = textForCurrent;

    final newItem = _createItem(text: textForNew);

    setState(() {
      checkboxes.insert(index + 1, newItem);
    });

    // Request focus on the newly inserted item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      newItem.node.requestFocus();
      newItem.controller.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(
          0xFF0F0F15,
        ), // Premium monochromatic dark background
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildHeader(),
              Expanded(
                child: checkboxes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: checkboxes.length,
                        itemBuilder: (context, index) {
                          final item = checkboxes[index];
                          return FadeInLeft(
                            key: ValueKey(item),
                            duration: const Duration(milliseconds: 180),
                            child: _buildItemRow(item, index),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Glassmorphic Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
                "Task Control Center",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "Workspace checklist & progress",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final percent = progressPercent;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.checklist_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Workspace Checklist",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        "Interactive checklist & planning",
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  "${(percent * 100).toInt()}%",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Progress",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              Text(
                "$completedTasks of $totalTasks tasks",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 6,
                    width: constraints.maxWidth * percent,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  final newItem = _createItem(text: "");
                  setState(() {
                    checkboxes.add(newItem);
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    newItem.node.requestFocus();
                  });
                },
                icon: const Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  "Add Task",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              if (completedTasks > 0)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      checkboxes.removeWhere((item) {
                        if (item.isChecked) {
                          item.dispose();
                          return true;
                        }
                        return false;
                      });
                    });
                  },
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 16,
                    color: Colors.white60,
                  ),
                  label: const Text(
                    "Clear Completed",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(CheckboxItem item, int index) {
    final bool hasFocus = item.node.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: hasFocus
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasFocus
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Vertical indicator line
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 2.5,
            height: 18,
            decoration: BoxDecoration(
              color: hasFocus ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          // Custom Interactive Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                item.isChecked = !item.isChecked;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: item.isChecked ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: item.isChecked
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: AnimatedScale(
                scale: item.isChecked ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF0F0F15),
                  size: 13,
                  weight: 3,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // TextField with Keyboard Interceptors
          Expanded(
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.backspace) {
                    final selection = item.controller.selection;
                    if (selection.isCollapsed && selection.start == 0) {
                      _handleBackspace(index);
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                    _handleEnter(index);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    if (index > 0) {
                      final prevItem = checkboxes[index - 1];
                      prevItem.node.requestFocus();
                      prevItem.controller.selection = TextSelection.collapsed(
                        offset: prevItem.controller.text.length,
                      );
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (index < checkboxes.length - 1) {
                      final nextItem = checkboxes[index + 1];
                      nextItem.node.requestFocus();
                      nextItem.controller.selection = TextSelection.collapsed(
                        offset: nextItem.controller.text.length,
                      );
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: item.controller,
                focusNode: item.node,
                minLines: 1,
                maxLines: 10,
                style: TextStyle(
                  color: item.isChecked
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: item.isChecked
                      ? FontWeight.normal
                      : FontWeight.w500,
                  decoration: item.isChecked
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.white.withValues(alpha: 0.35),
                ),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  isDense: true,
                  hintText: "Enter task...",
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                ),
              ),
            ),
          ),
          // Delete button
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
            onPressed: () {
              setState(() {
                checkboxes.removeAt(index);
              });
              item.dispose();
            },
            splashRadius: 14,
            tooltip: "Delete task",
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeInUp(
      duration: const Duration(milliseconds: 250),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                color: Colors.white70,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "All Done!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Press 'Add Task' or hit enter to get started.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckboxItem {
  final TextEditingController controller;
  final FocusNode node;
  bool isChecked;

  CheckboxItem({String text = "", this.isChecked = false})
    : controller = TextEditingController(text: text),
      node = FocusNode();

  void dispose() {
    controller.dispose();
    node.dispose();
  }
}
