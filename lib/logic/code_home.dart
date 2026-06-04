import 'package:flutter/material.dart';
import 'package:mist/uis/android/ui_home.dart';
import 'package:mist/uis/android/ui_folder.dart';
import 'package:mist/uis/android/ui_nodes.dart';

class CodeHome extends ChangeNotifier {
  int index = 0;

  /// provide screen based on index
  Widget getScreen() {
    if (index == 0) {
      return const UiHomeScreen();
    } else if (index == 1) {
      return const UiFolderScreen();
    } else if (index == 2) {
      return const UiNodesScreen();
    } else {
      return const UiHomeScreen();
    }
  }

  /// change index and notifiy listener
  void changeindex(int num) async {
    index = num;
    notifyListeners();
  }
}
