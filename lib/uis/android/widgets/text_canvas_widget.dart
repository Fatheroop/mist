import 'package:flutter/material.dart';
import 'package:mist/repo/canvas.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TextCanvasWidgetData — serialisable payload for text nodes
// ─────────────────────────────────────────────────────────────────────────────

class TextCanvasWidgetData implements CanvasWidgetChild {
  String text;

  TextCanvasWidgetData({required this.text});

  // ── Type registration ──────────────────────────────────────────────────

  static const String type = 'text';

  /// Call once at app startup to register this type with the canvas registry.
  static void register() {
    CanvasWidgetChild.registerType(type, (map) => TextCanvasWidgetData.fromMap(map));
  }

  // ── Serialisation ──────────────────────────────────────────────────────

  @override
  String get typeName => type;

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': typeName,
      'text': text,
    };
  }

  factory TextCanvasWidgetData.fromMap(Map<String, dynamic> map) {
    return TextCanvasWidgetData(
      text: (map['text'] as String?) ?? '',
    );
  }

  // ── Widget builder ─────────────────────────────────────────────────────

  @override
  Widget buildWidget({bool isPreview = true}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
