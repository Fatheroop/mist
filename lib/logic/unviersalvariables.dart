import 'package:flutter/widgets.dart';

class Unviersalvariables {
  // singleton class
  static final Unviersalvariables _instance = Unviersalvariables._();
  factory Unviersalvariables() => _instance;
  Unviersalvariables._();
  String audiopath = "assets/gangnam_style.mp3";
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
