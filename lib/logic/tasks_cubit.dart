import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mist/repo/models.dart';

class TasksState {
  final List<TaskItem> tasks;
  final bool isLoading;

  TasksState({
    this.tasks = const [],
    this.isLoading = false,
  });

  TasksState copyWith({
    List<TaskItem>? tasks,
    bool? isLoading,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TasksCubit extends Cubit<TasksState> {
  TasksCubit() : super(TasksState()) {
    loadTasks();
  }

  Future<File> _getTasksFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/tasks.json');
  }

  Future<void> loadTasks() async {
    emit(state.copyWith(isLoading: true));
    try {
      final file = await _getTasksFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        if (decoded.isNotEmpty) {
          final loaded = decoded.map((item) => TaskItem.fromJson(item)).toList();
          emit(TasksState(tasks: loaded, isLoading: false));
          return;
        }
      }
    } catch (e) {
      debugPrint("Error loading tasks: $e");
    }

    // Default tasks
    final defaultTasks = [
      TaskItem(
        id: '1',
        text: "🚀 Create mindmap visualization concept",
        isChecked: false,
      ),
      TaskItem(
        id: '2',
        text: "🎨 Define harmonized amber glow color scheme",
        isChecked: true,
      ),
      TaskItem(
        id: '3',
        text: "📝 Integrate premium glassmorphism layouts",
        isChecked: false,
      ),
      TaskItem(
        id: '4',
        text: "🛠 Fix focus nodes and RangeError exceptions",
        isChecked: true,
      ),
    ];
    emit(TasksState(tasks: defaultTasks, isLoading: false));
  }

  Future<void> saveTasks() async {
    try {
      final file = await _getTasksFile();
      final data = jsonEncode(state.tasks.map((item) => item.toJson()).toList());
      await file.writeAsString(data);
    } catch (e) {
      debugPrint("Error saving tasks: $e");
    }
  }

  void addTask({required String text, bool isChecked = false, String? id}) {
    final newTasks = List<TaskItem>.from(state.tasks)
      ..add(TaskItem(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        isChecked: isChecked,
      ));
    emit(state.copyWith(tasks: newTasks));
    saveTasks();
  }

  void insertTask(int index, {required String text, bool isChecked = false, String? id}) {
    final newTasks = List<TaskItem>.from(state.tasks);
    if (index >= 0 && index <= newTasks.length) {
      newTasks.insert(
        index,
        TaskItem(
          id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
          isChecked: isChecked,
        ),
      );
    } else {
      newTasks.add(TaskItem(
        id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        isChecked: isChecked,
      ));
    }
    emit(state.copyWith(tasks: newTasks));
    saveTasks();
  }

  void updateTaskText(String id, String text) {
    final newTasks = state.tasks.map((item) {
      if (item.id == id) {
        return item.copyWith(text: text);
      }
      return item;
    }).toList();
    emit(state.copyWith(tasks: newTasks));
  }

  void toggleTask(String id) {
    final newTasks = state.tasks.map((item) {
      if (item.id == id) {
        return item.copyWith(isChecked: !item.isChecked);
      }
      return item;
    }).toList();
    emit(state.copyWith(tasks: newTasks));
    saveTasks();
  }

  void deleteTask(String id) {
    final newTasks = state.tasks.where((item) => item.id != id).toList();
    emit(state.copyWith(tasks: newTasks));
    saveTasks();
  }

  void clearCompleted() {
    final newTasks = state.tasks.where((item) => !item.isChecked).toList();
    emit(state.copyWith(tasks: newTasks));
    saveTasks();
  }
}
