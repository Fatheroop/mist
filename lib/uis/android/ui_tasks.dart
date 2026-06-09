import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/logic/tasks_cubit.dart';
import 'package:mist/repo/models.dart';

class UiTasks extends StatefulWidget {
  const UiTasks({super.key});

  @override
  State<UiTasks> createState() => _UiTasksState();
}

class _UiTasksState extends State<UiTasks> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  Timer? _saveTimer;
  late final TasksCubit _tasksCubit;

  @override
  void initState() {
    super.initState();
    _tasksCubit = context.read<TasksCubit>();
    final tasks = _tasksCubit.state.tasks;
    _updateControllers(tasks);

    // Auto-focus the first incomplete item after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _tasksCubit.state;
      if (state.tasks.isNotEmpty) {
        _focusNodes[state.tasks[0].id]?.requestFocus();
      }
    });

    // Automatically save tasks to storage every 5 seconds
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _tasksCubit.saveTasks();
      }
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _tasksCubit.saveTasks();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _updateControllers(List<TaskItem> tasks) {
    final Set<String> activeIds = tasks.map((t) => t.id).toSet();

    // Clean up disposed/deleted tasks
    _controllers.keys.toList().forEach((id) {
      if (!activeIds.contains(id)) {
        _controllers[id]?.dispose();
        _controllers.remove(id);
      }
    });
    _focusNodes.keys.toList().forEach((id) {
      if (!activeIds.contains(id)) {
        _focusNodes[id]?.dispose();
        _focusNodes.remove(id);
      }
    });

    // Add controllers for new tasks
    for (final task in tasks) {
      if (!_controllers.containsKey(task.id)) {
        final controller = TextEditingController(text: task.text);
        controller.addListener(() {
          _tasksCubit.updateTaskText(task.id, controller.text);
        });
        _controllers[task.id] = controller;
      }
      if (!_focusNodes.containsKey(task.id)) {
        final node = FocusNode();
        node.addListener(() {
          if (mounted) {
            setState(() {}); // Rebuild to update focus indicators
          }
        });
        _focusNodes[task.id] = node;
      }
    }
  }

  void _handleBackspace(int index, List<TaskItem> tasks) {
    if (index == 0) return;

    final currentItem = tasks[index];
    final prevItem = tasks[index - 1];

    final currentCtrl = _controllers[currentItem.id];
    final prevCtrl = _controllers[prevItem.id];
    if (currentCtrl == null || prevCtrl == null) return;

    final currentText = currentCtrl.text;
    final prevText = prevCtrl.text;
    final junctionPoint = prevText.length;

    prevCtrl.text = prevText + currentText;
    context.read<TasksCubit>().updateTaskText(prevItem.id, prevText + currentText);
    context.read<TasksCubit>().deleteTask(currentItem.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[prevItem.id]?.requestFocus();
      _controllers[prevItem.id]?.selection = TextSelection.collapsed(
        offset: junctionPoint,
      );
    });
  }

  void _handleEnter(int index, List<TaskItem> tasks) {
    final currentItem = tasks[index];
    final currentCtrl = _controllers[currentItem.id];
    if (currentCtrl == null) return;

    final currentText = currentCtrl.text;
    final selection = currentCtrl.selection;

    String textForCurrent = currentText;
    String textForNew = "";

    if (selection.isValid) {
      final start = selection.start;
      textForCurrent = currentText.substring(0, start);
      textForNew = currentText.substring(start);
    }

    currentCtrl.text = textForCurrent;
    context.read<TasksCubit>().updateTaskText(currentItem.id, textForCurrent);

    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    context.read<TasksCubit>().insertTask(index + 1, text: textForNew, id: newId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[newId]?.requestFocus();
      _controllers[newId]?.selection = const TextSelection.collapsed(offset: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TasksCubit, TasksState>(
      listener: (context, state) {
        _updateControllers(state.tasks);
      },
      child: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          final totalTasks = state.tasks.length;
          final completedTasks = state.tasks.where((t) => t.isChecked).length;
          final percent = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Scaffold(
              backgroundColor: const Color(0xFF0F0F15),
              resizeToAvoidBottomInset: true,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(context),
                    _buildHeader(totalTasks, completedTasks, percent),
                    Expanded(
                      child: state.tasks.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 40),
                              itemCount: state.tasks.length,
                              itemBuilder: (context, index) {
                                final item = state.tasks[index];
                                return FadeInLeft(
                                  key: ValueKey(item.id),
                                  duration: const Duration(milliseconds: 180),
                                  child: _buildItemRow(item, index, state.tasks),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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

  Widget _buildHeader(int totalTasks, int completedTasks, double percent) {
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
                  final newId = DateTime.now().microsecondsSinceEpoch.toString();
                  context.read<TasksCubit>().addTask(text: "", id: newId);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _focusNodes[newId]?.requestFocus();
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
                    context.read<TasksCubit>().clearCompleted();
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

  Widget _buildItemRow(TaskItem item, int index, List<TaskItem> tasks) {
    final focusNode = _focusNodes[item.id];
    final controller = _controllers[item.id];
    if (focusNode == null || controller == null) return const SizedBox();

    final bool hasFocus = focusNode.hasFocus;

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
          GestureDetector(
            onTap: () {
              context.read<TasksCubit>().toggleTask(item.id);
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
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.backspace) {
                    final selection = controller.selection;
                    if (selection.isCollapsed && selection.start == 0) {
                      _handleBackspace(index, tasks);
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                    _handleEnter(index, tasks);
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    if (index > 0) {
                      final prevItem = tasks[index - 1];
                      final prevNode = _focusNodes[prevItem.id];
                      final prevCtrl = _controllers[prevItem.id];
                      if (prevNode != null && prevCtrl != null) {
                        prevNode.requestFocus();
                        prevCtrl.selection = TextSelection.collapsed(
                          offset: prevCtrl.text.length,
                        );
                      }
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (index < tasks.length - 1) {
                      final nextItem = tasks[index + 1];
                      final nextNode = _focusNodes[nextItem.id];
                      final nextCtrl = _controllers[nextItem.id];
                      if (nextNode != null && nextCtrl != null) {
                        nextNode.requestFocus();
                        nextCtrl.selection = TextSelection.collapsed(
                          offset: nextCtrl.text.length,
                        );
                      }
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
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
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
            onPressed: () {
              context.read<TasksCubit>().deleteTask(item.id);
            },
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
