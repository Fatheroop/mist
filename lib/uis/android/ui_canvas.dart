import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mist/repo/canvas.dart';
import 'package:mist/uis/android/widgets/image_canvas_widget.dart';
import 'package:mist/uis/android/widgets/text_canvas_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Canvas Home — the main infinite-canvas screen for MIST
// ─────────────────────────────────────────────────────────────────────────────

class CanvasHome extends StatefulWidget {
  final File file;
  const CanvasHome({super.key, required this.file});

  @override
  State<CanvasHome> createState() => _CanvasHomeState();
}

class _CanvasHomeState extends State<CanvasHome> {
  // ── Core state ──────────────────────────────────────────────────────────
  final TransformationController _transformCtrl = TransformationController();

  /// True when a node is being dragged/resized so the InteractiveViewer
  /// should not pan or scale.
  bool _isInteractingNode = false;

  /// Offset from the node's top-left to the finger's grab point (canvas space).
  /// Used for position-based dragging that tracks the finger 1:1 at any zoom.
  Offset _dragGrabOffset = Offset.zero;

  /// Gap (canvas px) enforced between nodes.
  static const double _nodeGap = 16.0;

  // ── Nodes ──────────────────────────────────────────────────────────────
  final List<CanvasNodeData> _nodes = [
    CanvasNodeData(
      id: 'untitled 1',
      x: 100,
      y: 100,
      width: 300,
      height: 300,
      canvasChild: TextCanvasWidgetData(text: "this is new child 1"),
    ),
    CanvasNodeData(
      id: 'untitled 2',
      x: 150,
      y: 450,
      width: 300,
      height: 300,
      canvasChild: TextCanvasWidgetData(text: "this is new chld 2"),
    ),
  ];

  int _nextId = 4;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── Collision helpers ──────────────────────────────────────────────────

  Rect _inflated(CanvasNodeData n, {double gap = 0}) => Rect.fromLTWH(
    n.x - gap,
    n.y - gap,
    n.width + gap * 2,
    n.height + gap * 2,
  );

  bool _overlapsAny(Rect candidate, CanvasNodeData self) {
    for (final n in _nodes) {
      if (identical(n, self)) continue;
      if (_inflated(n, gap: _nodeGap / 2).overlaps(candidate)) return true;
    }
    return false;
  }

  Offset _findFreePosition(
    Offset desired,
    double w,
    double h,
    CanvasNodeData self,
  ) {
    final half = _nodeGap / 2;
    final test = Rect.fromLTWH(
      desired.dx - half,
      desired.dy - half,
      w + _nodeGap,
      h + _nodeGap,
    );
    if (!_overlapsAny(test, self)) return desired;

    const double step = 20;
    for (double r = step; r < 2000; r += step) {
      for (double a = 0; a < 360; a += 15) {
        final rad = a * pi / 180;
        final o = Offset(desired.dx + r * cos(rad), desired.dy + r * sin(rad));
        if (o.dx < 0 || o.dy < 0 || o.dx + w > 10000 || o.dy + h > 10000) {
          continue;
        }
        final tr = Rect.fromLTWH(
          o.dx - half,
          o.dy - half,
          w + _nodeGap,
          h + _nodeGap,
        );
        if (!_overlapsAny(tr, self)) return o;
      }
    }
    return desired;
  }

  Size _clampSize(CanvasNodeData self, double newW, double newH) {
    var w = newW;
    var h = newH;
    while (w > 300 || h > 300) {
      final tr = Rect.fromLTWH(
        self.x - _nodeGap / 2,
        self.y - _nodeGap / 2,
        w + _nodeGap,
        h + _nodeGap,
      );
      if (!_overlapsAny(tr, self)) break;
      if (w > 300) w -= 10;
      if (h > 300) h -= 10;
    }
    return Size(w.clamp(300, 1200), h.clamp(300, 1200));
  }

  // ── Node deletion ──────────────────────────────────────────────────────

  void _deleteNode(CanvasNodeData node) {
    setState(() {
      _nodes.remove(node);
    });
  }

  // ── Add node ───────────────────────────────────────────────────────────

  void _addNode(CanvasWidgetChild child) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = _transformCtrl.toScene(
      Offset(box.size.width / 2, box.size.height / 2),
    );
    final desired = Offset(center.dx - 150, center.dy - 150);

    final newNode = CanvasNodeData(
      id: 'untitled $_nextId',
      canvasChild: child,
      x: desired.dx,
      y: desired.dy,
    );

    final free = _findFreePosition(
      desired,
      newNode.width,
      newNode.height,
      newNode,
    );
    newNode.x = free.dx;
    newNode.y = free.dy;

    setState(() {
      _nodes.add(newNode);
      _nextId++;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFF),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.1,
              maxScale: 3.0,
              constrained: false,
              panEnabled: !_isInteractingNode,
              scaleEnabled: !_isInteractingNode,
              child: SizedBox(
                width: 10000,
                height: 10000,
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: ResizeImage(
                        AssetImage('assets/assets_image_1.png'),
                        width: 2560,
                        height: 1440,
                        policy: ResizeImagePolicy.exact,
                      ),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: _nodes
                        .map((node) => _buildNodeWidget(node))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(child: _addNotedashBoard()),
          ),
        ],
      ),
    );
  }

  Widget _addNotedashBoard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      margin: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(93, 47, 47, 47),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color.fromARGB(110, 255, 255, 255)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // nodes in list = images, hyperlink, webview, shortcut's , video, audio, tasks, text's canvas, button canvas, link to another canvas.
          _builddashboardbuttons(FontAwesomeIcons.penToSquare, () {}),
          _builddashboardbuttons(FontAwesomeIcons.penClip, () {
            _addNode(TextCanvasWidgetData(text: "this is new child 3"));
          }),
          _builddashboardbuttons(FontAwesomeIcons.link, () {}),
          _builddashboardbuttons(FontAwesomeIcons.video, () {}),
          _builddashboardbuttons(FontAwesomeIcons.fileImage, () {
            _addNode(ImageCanvasWidgetData());
          }),
        ],
      ),
    );
  }

  Widget _builddashboardbuttons(FaIconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: FaIcon(icon, size: 22, color: Colors.white70),
    );
  }

  // ── Build a single node ────────────────────────────────────────────────

  Widget _buildNodeWidget(CanvasNodeData node) {
    return Positioned(
      left: node.x,
      top: node.y,
      child: RepaintBoundary(
        child: SizedBox(
          width: node.width,
          height: node.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Card background (lightweight, no BackdropFilter) ────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(200, 0, 0, 0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(
                          255,
                          245,
                          245,
                          245,
                        ).withValues(alpha: 0.3),
                        blurRadius: 22,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Header bar (drag handle + delete) ──────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 44,
                child: GestureDetector(
                  onPanStart: (d) {
                    // Record where the finger grabbed relative to node origin
                    // by converting the screen-space pointer to canvas-space.
                    final fingerCanvas = _transformCtrl.toScene(
                      d.globalPosition,
                    );
                    _dragGrabOffset = Offset(
                      fingerCanvas.dx - node.x,
                      fingerCanvas.dy - node.y,
                    );
                    setState(() => _isInteractingNode = true);
                  },

                  onPanEnd: (_) {
                    final snap = _findFreePosition(
                      Offset(node.x, node.y),
                      node.width,
                      node.height,
                      node,
                    );
                    setState(() {
                      node.x = snap.dx;
                      node.y = snap.dy;
                      _isInteractingNode = false;
                    });
                  },
                  onPanCancel: () => setState(() => _isInteractingNode = false),
                  onPanUpdate: (d) {
                    // Convert finger's screen position to canvas coords,
                    // then subtract the grab offset. Clamp to canvas bounds
                    // so nodes can never leave the image area.
                    final fingerCanvas = _transformCtrl.toScene(
                      d.globalPosition,
                    );
                    final newX = (fingerCanvas.dx - _dragGrabOffset.dx).clamp(
                      0.0,
                      10000.0 - node.width,
                    );
                    final newY = (fingerCanvas.dy - _dragGrabOffset.dy).clamp(
                      0.0,
                      10000.0 - node.height,
                    );
                    setState(() {
                      node.x = newX;
                      node.y = newY;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            node.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteNode(node),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Content area ───────────────────────────────────────
              Positioned(
                top: 44,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.fromARGB(143, 0, 0, 0),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.white),
                        child: node.canvasChild.buildWidget(isPreview: true),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Resize handle ──────────────────────────────────────
              Positioned(
                right: 0,
                bottom: 0,
                width: 44,
                height: 44,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _isInteractingNode = true),
                  onPanEnd: (_) {
                    final clamped = _clampSize(node, node.width, node.height);
                    setState(() {
                      node.width = clamped.width;
                      node.height = clamped.height;
                      _isInteractingNode = false;
                    });
                  },
                  onPanCancel: () => setState(() => _isInteractingNode = false),
                  onPanUpdate: (d) {
                    setState(() {
                      node.width = (node.width + d.delta.dx);
                      node.height = (node.height + d.delta.dy);
                    });
                  },
                  child: const MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.zoom_out_map_rounded,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple DTO mapping names, colors, and hex values
class ColorOption {
  final String name;
  final String hex;
  final Color color;

  ColorOption(this.name, this.hex, this.color);
}
