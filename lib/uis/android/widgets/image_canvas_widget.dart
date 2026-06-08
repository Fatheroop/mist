import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mist/repo/canvas.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImageCanvasWidgetData — serialisable payload for image nodes
// ─────────────────────────────────────────────────────────────────────────────

class ImageCanvasWidgetData implements CanvasWidgetChild {
  String? imagePath;
  bool isPreview;

  ImageCanvasWidgetData({this.imagePath, this.isPreview = true});

  // ── Type registration ──────────────────────────────────────────────────

  static const String type = 'image';

  /// Call once at app startup to register this type with the canvas registry.
  static void register() {
    CanvasWidgetChild.registerType(
      type,
      (map) => ImageCanvasWidgetData.fromMap(map),
    );
  }

  // ── Serialisation ──────────────────────────────────────────────────────

  @override
  String get typeName => type;

  @override
  Map<String, dynamic> toMap() {
    return {'type': typeName, 'imagePath': imagePath, 'isPreview': isPreview};
  }

  factory ImageCanvasWidgetData.fromMap(Map<String, dynamic> map) {
    return ImageCanvasWidgetData(
      imagePath: map['imagePath'] as String?,
      isPreview: (map['isPreview'] as bool?) ?? true,
    );
  }

  // ── Widget builder ─────────────────────────────────────────────────────

  @override
  Widget buildWidget({bool isPreview = true}) {
    return ImageCanvasWidget(data: this, isPreview: isPreview);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ImageCanvasWidget — the Flutter widget rendered inside a canvas node
// ─────────────────────────────────────────────────────────────────────────────

class ImageCanvasWidget extends StatefulWidget {
  final ImageCanvasWidgetData data;
  final bool isPreview;

  const ImageCanvasWidget({
    super.key,
    required this.data,
    this.isPreview = true,
  });

  @override
  State<ImageCanvasWidget> createState() => _ImageCanvasWidgetState();
}

class _ImageCanvasWidgetState extends State<ImageCanvasWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.isPreview) {
      return _previewWidget();
    } else {
      return Scaffold(body: Column(children: [_previewWidget()]));
    }
  }

  Widget _previewWidget() {
    final path = widget.data.imagePath;
    if (path == null || path.isEmpty) {
      return _placeholder('No image selected');
    }

    try {
      final file = File(path);
      if (!file.existsSync()) {
        return _placeholder('File not found');
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _placeholder('Failed to load image'),
        ),
      );
    } catch (e) {
      return _placeholder('Error: $e');
    }
  }

  Widget _placeholder(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
