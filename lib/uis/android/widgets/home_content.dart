import 'dart:async';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mist/uis/android/ui_tasks.dart';
import 'package:mist/uis/android/widgets/alarms_and_settings.dart';
import 'package:mist/uis/android/widgets/premium_settings.dart';
import 'package:mist/uis/android/widgets/remainder_widget.dart';

class UiHomeContent extends StatefulWidget {
  const UiHomeContent({super.key});

  @override
  State<UiHomeContent> createState() => _UiHomeContentState();
}

class _UiHomeContentState extends State<UiHomeContent> {
  double _scale = 1.0;
  String currentRemainder = "Swipe left or Right";
  int currentoptions = 0;

  String getTime() {
    var hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 18) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  void _changeRemainder(int side) {
    currentoptions = currentoptions + side;
    if (currentoptions > 2) {
      currentoptions = 0;
    }
    if (currentoptions < 0) {
      currentoptions = 2;
    }
    switch (currentoptions) {
      case 0:
        currentRemainder = "Alarms";
        break;
      case 1:
        currentRemainder = "Reminders";
        break;
      case 2:
        currentRemainder = "Settings";
        break;
      default:
        side = 1;
        currentRemainder = "Alarms";
        break;
    }
    setState(() {});
  }

  Widget _getCurrentWidget() {
    switch (currentoptions) {
      case 0:
        return const Alarms();
      case 1:
        return const RemainderWidget();
      case 2:
        return const AlarmsSetting();
      default:
        return const Text(
          "Hello, an error occurred",
          style: TextStyle(color: Colors.red),
        );
    }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.96;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
    });
  }

  Future<void> _sendFeedbackEmail(UserFeedback feedback) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String screenshotPath =
          '${tempDir.path}/mist_feedback_${DateTime.now().millisecondsSinceEpoch}.png';
      final File screenshotFile = File(screenshotPath);
      await screenshotFile.writeAsBytes(feedback.screenshot);

      final Email email = Email(
        subject: 'Mist App — Bug Report / Feedback',
        body: feedback.text,
        recipients: ['t8268826@gmail.com'],
        attachmentPaths: [screenshotPath],
      );

      await FlutterEmailSender.send(email);
    } catch (e) {
      debugPrint('📧 Error sending feedback email: $e');
    }
  }

  Widget _buildFeedbackButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        BetterFeedback.of(context).show((feedback) async {
          await _sendFeedbackEmail(feedback);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFFB347)],
              ).createShader(bounds),
              child: const Icon(
                Icons.bug_report_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Feedback',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bordercolor = Color.fromARGB(42, 255, 255, 255);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${getTime()}, Yogesh",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              _buildFeedbackButton(context),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const UiTasks(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOutCubic;

                        var tween = Tween(
                          begin: begin,
                          end: end,
                        ).chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
                        var fadeAnimation = animation.drive(fadeTween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: FadeTransition(
                            opacity: fadeAnimation,
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: bordercolor, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: const FaIcon(
                        FontAwesomeIcons.listCheck,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Tasks Workspace",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Organize checklists & daily tracking",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                _changeRemainder(1);
              }
              if (details.primaryVelocity! < 0) {
                _changeRemainder(-1);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bordercolor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                currentRemainder,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color.fromARGB(209, 255, 255, 255),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bordercolor),
            ),
            child: _getCurrentWidget(),
          ).fadeIn(
            duration: const Duration(milliseconds: 500),
            key: ValueKey<int>(currentoptions),
          ),
        ],
      ),
    );
  }
}
