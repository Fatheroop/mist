import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Canvas child-type registry
// ─────────────────────────────────────────────────────────────────────────────

/// Registry that maps a type-name string to a factory function so we can
/// deserialise any [CanvasWidgetChild] subclass from JSON.
///
/// Every concrete subclass must call
/// `CanvasWidgetChild.registerType('myType', (map) => MyType.fromMap(map))`
/// once at startup (usually from `main()` or a static initialiser).
typedef CanvasChildFactory =
    CanvasWidgetChild Function(Map<String, dynamic> map);

// ─────────────────────────────────────────────────────────────────────────────
// CanvasWidgetChild — abstract base for every embeddable node payload
// ─────────────────────────────────────────────────────────────────────────────

abstract class CanvasWidgetChild {
  // ── Type registry ──────────────────────────────────────────────────────
  static final Map<String, CanvasChildFactory> _registry = {};

  /// Register a concrete child type so [fromMap] can reconstruct it.
  static void registerType(String typeName, CanvasChildFactory factory) {
    _registry[typeName] = factory;
  }

  /// Reconstruct a [CanvasWidgetChild] from its serialised map.
  /// The map **must** contain a `'type'` key matching a registered name.
  static CanvasWidgetChild fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;
    if (type == null || !_registry.containsKey(type)) {
      throw ArgumentError(
        'Unknown or missing CanvasWidgetChild type: "$type". '
        'Registered types: ${_registry.keys.toList()}',
      );
    }
    return _registry[type]!(map);
  }

  // ── Contract ───────────────────────────────────────────────────────────

  /// A unique type name used as the `'type'` key during serialisation.
  String get typeName;

  /// Serialise this child's data to a JSON-compatible map.
  /// Implementations **must** include `'type': typeName` in the returned map.
  Map<String, dynamic> toMap();

  /// Build the Flutter widget tree for this child.
  Widget buildWidget({bool isPreview = true});
}

// ─────────────────────────────────────────────────────────────────────────────
// Childtype enum — kept for potential future use / UI toolbar hints
// ─────────────────────────────────────────────────────────────────────────────

enum Childtype {
  text,
  image,
  audio,
  video,
  hyperlinks,
  buttons,
  webview,
  tasks,
}

// ─────────────────────────────────────────────────────────────────────────────
// CanvasNodeData — mutable data model for a single canvas node
// ─────────────────────────────────────────────────────────────────────────────

/// Mutable data model for a node on the canvas.
///
/// Using a plain class (not a Widget) prevents Flutter from destroying and
/// recreating widget State objects every time the position or size changes
/// during a drag.  This is key to eliminating jank.
class CanvasNodeData {
  String id;
  CanvasWidgetChild canvasChild;
  double x;
  double y;
  double width;
  double height;

  CanvasNodeData({
    required this.id,
    required this.canvasChild,
    this.x = 0,
    this.y = 0,
    this.width = 300,
    this.height = 300,
  });

  // ── Serialisation ──────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child': canvasChild.toMap(),
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory CanvasNodeData.fromMap(Map<String, dynamic> map) {
    return CanvasNodeData(
      id: map['id'] as String,
      canvasChild: CanvasWidgetChild.fromMap(
        map['child'] as Map<String, dynamic>,
      ),
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CanvasNodeData.fromJson(String json) =>
      CanvasNodeData.fromMap(jsonDecode(json) as Map<String, dynamic>);

  // ── Geometry helpers ───────────────────────────────────────────────────

  Rect get rect => Rect.fromLTWH(x, y, width, height);
  Offset get center => Offset(x + width / 2, y + height / 2);
}

// ─────────────────────────────────────────────────────────────────────────────
// CanvasFileManager — save / load entire canvas to a specific .canvas file
// ─────────────────────────────────────────────────────────────────────────────

class CanvasFileManager {
  /// Persist the full list of [CanvasNodeData] to the given [file] as JSON.
  static Future<void> save(List<CanvasNodeData> nodes, File file) async {
    final list = nodes.map((n) => n.toMap()).toList();
    final json = const JsonEncoder.withIndent('  ').convert(list);
    await file.writeAsString(json);
  }

  /// Load all nodes from the given [file].
  /// Returns an empty list if the file does not exist or is empty.
  static Future<List<CanvasNodeData>> load(File file) async {
    try {
      if (!await file.exists()) return [];
      final json = await file.readAsString();
      if (json.trim().isEmpty) return [];
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list
          .map((item) => CanvasNodeData.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete the canvas file.
  static Future<void> delete(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
