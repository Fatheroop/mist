import 'package:flutter/material.dart';

/// Mutable data model for a node on the canvas.
///
/// Using a plain class (not a Widget) prevents Flutter from destroying and
/// recreating widget State objects every time the position or size changes
/// during a drag. This is key to eliminating jank.
class CanvasNodeData {
  String id;
  Widget child;
  double x;
  double y;
  double width;
  double height;

  CanvasNodeData({
    required this.id,
    required this.child,
    this.x = 0,
    this.y = 0,
    this.width = 300,
    this.height = 300,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);
  Offset get center => Offset(x + width / 2, y + height / 2);
}
