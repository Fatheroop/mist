import 'dart:math' as math;
import 'package:flutter/material.dart';

class StudyFlashcard extends StatefulWidget {
  final String question;
  final String answer;

  const StudyFlashcard({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  State<StudyFlashcard> createState() => _StudyFlashcardState();
}

class _StudyFlashcardState extends State<StudyFlashcard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant StudyFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question) {
      setState(() {
        _showAnswer = false;
      });
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_showAnswer) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * math.pi;
          final isFront = angle < math.pi / 2;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isFront
                ? _buildCardFace(widget.question, "QUESTION", isFront: true)
                : Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildCardFace(
                      widget.answer,
                      "ANSWER",
                      isFront: false,
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFace(
    String text,
    String typeLabel, {
    required bool isFront,
  }) {
    return Container(
      width: double.infinity,
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFront ? Colors.white24 : Colors.white,
          width: isFront ? 1.2 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                typeLabel,
                style: TextStyle(
                  color: isFront ? Colors.white38 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              Icon(
                isFront
                    ? Icons.help_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isFront ? Colors.white30 : Colors.white,
                size: 18,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Text(
            isFront ? "Tap to flip & reveal" : "Tap to flip back",
            style: TextStyle(
              color: isFront ? Colors.white30 : Colors.white54,
              fontSize: 11,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class WaterRipplePainter extends CustomPainter {
  final double animationValue;

  WaterRipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width > size.height
        ? size.width / 1.1
        : size.height / 1.1;

    for (int i = 0; i < 3; i++) {
      final ringProgress = (animationValue + i / 3.0) % 1.0;
      final radius = ringProgress * maxRadius;

      double opacity = 0.0;
      if (ringProgress < 0.15) {
        opacity = (ringProgress / 0.15) * 0.12;
      } else {
        opacity = (1.0 - ringProgress) * 0.12;
      }

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 + (1.0 - ringProgress) * 4.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaterRipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
