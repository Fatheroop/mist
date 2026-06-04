import 'package:flutter/material.dart';

/// The main canvas screen for MIST.
class CanvasHome extends StatefulWidget {
  const CanvasHome({super.key});

  @override
  State<CanvasHome> createState() => _CanvasHomeState();
}

class _CanvasHomeState extends State<CanvasHome> {
  final TransformationController _transformationController =
      TransformationController();

  List<CanvasWidget> widgets = [
    CanvasWidget(
      id: "untitled 1",
      widget: const Text("widget 1"),
      offset: const Offset(100.0, 100.0),
      delete: () {},
      move: () {},
    ),
    CanvasWidget(
      id: "untitled 2",
      widget: const Text("widget 2"),
      offset: const Offset(300.0, 150.0),
      delete: () {},
      move: () {},
    ),
    CanvasWidget(
      id: "untitled 3",
      widget: const Text("widget 3"),
      offset: const Offset(150.0, 350.0),
      delete: () {},
      move: () {},
    ),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      body: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.1,
        maxScale: 2.5,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(3000),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ...widgets.map((e) {
              return Positioned(
                top: e.offset?.dy ?? 0.0,
                left: e.offset?.dx ?? 0.0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      final index = widgets.indexOf(e);
                      if (index != -1) {
                        widgets[index] = CanvasWidget(
                          id: e.id,
                          widget: e.widget,
                          color: e.color,
                          width: e.width,
                          height: e.height,
                          offset: Offset(
                            (e.offset?.dx ?? 0.0) + details.delta.dx,
                            (e.offset?.dy ?? 0.0) + details.delta.dy,
                          ),
                          delete: e.delete,
                          move: e.move,
                        );
                      }
                    });
                  },
                  child: CanvasWidget(
                    id: e.id,
                    widget: e.widget,
                    color: e.color,
                    width: e.width,
                    height: e.height,
                    offset: e.offset,
                    delete: () {
                      setState(() {
                        widgets.remove(e);
                      });
                    },
                    move: e.move,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            widgets.add(
              CanvasWidget(
                id: "untitled ${widgets.length + 1}",
                widget: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("widget ${widgets.length + 1}"),
                ),
                offset: Offset(
                  100.0 + (widgets.length * 30) % 200,
                  100.0 + (widgets.length * 40) % 200,
                ),
                delete: () {},
                move: () {},
              ),
            );
          });
        },
        label: const Text("Add Node"),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: Colors.indigoAccent,
      ),
    );
  }
}

class CanvasWidget extends StatefulWidget {
  final int height;
  final int width;
  final String id;
  final Color color;
  final Widget widget;
  final Offset? offset;
  final VoidCallback delete;
  final VoidCallback move;
  const CanvasWidget({
    super.key,
    this.height = 100,
    this.width = 100,
    required this.id,
    this.color = Colors.black,
    required this.widget,
    this.offset,
    required this.delete,
    required this.move,
  });

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  double height = 100;
  double width = 100;

  @override
  void initState() {
    super.initState();
    height = widget.height.toDouble();
    width = widget.width.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (height < 100) {
      height = 100;
    }
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: widget.color == Colors.black
            ? const Color(0xFF1E1E2F)
            : widget.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.delete,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: widget.widget,
              ),
            ),
          ),
        ],
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
