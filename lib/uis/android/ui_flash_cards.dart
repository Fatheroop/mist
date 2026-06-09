import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/logic/folder_cubit.dart';
import 'package:mist/uis/android/widgets/study_flashcard.dart';

class UiFlashCards extends StatefulWidget {
  final String? filename;
  const UiFlashCards({super.key, this.filename});

  @override
  State<UiFlashCards> createState() => _UiFlashCardsState();
}

class QuestionAnswer {
  String question;
  String answer;
  final TextEditingController questionController = TextEditingController();
  final TextEditingController answerController = TextEditingController();
  final FocusNode questionFocusNode = FocusNode();

  void disposeControllers() {
    questionController.dispose();
    answerController.dispose();
    questionFocusNode.dispose();
  }

  QuestionAnswer({required this.question, required this.answer});
}

class _UiFlashCardsState extends State<UiFlashCards>
    with TickerProviderStateMixin {
  late final FolderCubit folderCubit;
  final TextEditingController _titleController = TextEditingController();
  List<QuestionAnswer> qa = [];
  bool _isEditing = false;
  bool _isLoading = false;
  int _currentStudyIndex = 0;
  Timer? timer;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    folderCubit = context.read<FolderCubit>();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.linear,
    );
    if (widget.filename != null) {
      _isEditing = false;
      _loadFlashcards();
    } else {
      _isEditing = true;
      qa.add(QuestionAnswer(question: "", answer: ""));
      _shimmerController.repeat();
    }
    timer = Timer.periodic(const Duration(seconds: 5), (second) {
      if (_isEditing == true) {
        _saveFlashcards(isAutoSave: true);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var item in qa) {
      item.disposeControllers();
    }
    timer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadFlashcards() async {
    setState(() {
      _isLoading = true;
      _titleController.text = widget.filename!;
    });
    try {
      final jsonStr = await folderCubit.getFlashcards(widget.filename!);
      if (jsonStr != "File not found") {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final loaded = decoded.map((item) {
          final q = item['question'] ?? '';
          final a = item['answer'] ?? '';
          final qaObj = QuestionAnswer(question: q, answer: a);
          qaObj.questionController.text = q;
          qaObj.answerController.text = a;
          return qaObj;
        }).toList();

        setState(() {
          qa = loaded;
        });
      }
    } catch (e) {
      debugPrint("Error loading flashcards: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFlashcards({bool isAutoSave = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a title for your flashcard set"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final validCards = qa
        .where(
          (item) =>
              item.questionController.text.trim().isNotEmpty ||
              item.answerController.text.trim().isNotEmpty,
        )
        .toList();

    if (validCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one question and answer"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final data = jsonEncode(
      validCards
          .map(
            (item) => {
              'question': item.questionController.text.trim(),
              'answer': item.answerController.text.trim(),
            },
          )
          .toList(),
    );

    try {
      await folderCubit.updateFlashcards(title, data);
      await folderCubit.refreshFiles();
      if (!mounted) return;
      if (!isAutoSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Flashcard saved successfully"),
            backgroundColor: Colors.white24,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _questionAnswerWidget(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CARD ${index + 1}",
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      qa[index].disposeControllers();
                      qa.removeAt(index);
                      if (qa.isEmpty) {
                        qa.add(QuestionAnswer(question: "", answer: ""));
                      }
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white30,
                    size: 16,
                  ),
                  splashRadius: 16,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: qa[index].questionController,
                  focusNode: qa[index].questionFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Question...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white30,
                        size: 16,
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                TextField(
                  controller: qa[index].answerController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: Colors.white,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "Answer...",
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                    border: InputBorder.none,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white30,
                        size: 16,
                      ),
                    ),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditing(String? filename) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () {
            if (widget.filename != null) {
              setState(() {
                _isEditing = false;
              });
              _shimmerController.stop();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.filename == null ? "Create Flashcards" : "Edit Flashcards",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.filename != null)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                });
                _shimmerController.stop();
              },
              tooltip: "Study Now",
            ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.white),
            onPressed: () async {
              await _saveFlashcards();
              if (!mounted) return;
              if (widget.filename != null) {
                setState(() {
                  _isEditing = false;
                });
                _shimmerController.stop();
              } else {
                Navigator.pop(context);
              }
            },
            tooltip: "Save Set",
          ),
        ],
        shape: const Border(
          bottom: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  if (_shimmerAnimation.value == 0.0 ||
                      _shimmerAnimation.value == 1.0) {
                    return const SizedBox.shrink();
                  }
                  return IgnorePointer(
                    child: CustomPaint(
                      painter: WaterRipplePainter(_shimmerAnimation.value),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 20, bottom: 100),
                      itemCount: qa.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141416),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white12,
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: TextField(
                                controller: _titleController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                cursorColor: Colors.white,
                                decoration: const InputDecoration(
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: FaIcon(
                                      FontAwesomeIcons.penToSquare,
                                      size: 16,
                                      color: Colors.white38,
                                    ),
                                  ),
                                  prefixIconConstraints: BoxConstraints(
                                    minWidth: 0,
                                    minHeight: 0,
                                  ),
                                  border: InputBorder.none,
                                  hintText: "Title (e.g., Biology Core)",
                                  hintStyle: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return _questionAnswerWidget(index - 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final newCard = QuestionAnswer(question: "", answer: "");
          setState(() {
            qa.add(newCard);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            newCard.questionFocusNode.requestFocus();
          });
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          "Add Card",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildReading(String? filename) {
    if (qa.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            "No cards in this set",
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final isLastCard = _currentStudyIndex == qa.length - 1;
    final isFirstCard = _currentStudyIndex == 0;
    final currentQA = qa[_currentStudyIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.filename ?? "Study",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
              _shimmerController.repeat();
            },
            child: const Text(
              "Edit",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: const Border(
          bottom: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "CARD ${_currentStudyIndex + 1} OF ${qa.length}",
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${((_currentStudyIndex + 1) / qa.length * 100).toInt()}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStudyIndex + 1) / qa.length,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              ),
              const Expanded(child: SizedBox()),
              StudyFlashcard(
                key: ValueKey(_currentStudyIndex),
                question: currentQA.questionController.text,
                answer: currentQA.answerController.text,
              ),
              const Expanded(child: SizedBox()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: isFirstCard ? 0.3 : 1.0,
                      child: TextButton(
                        onPressed: isFirstCard
                            ? null
                            : () {
                                setState(() {
                                  _currentStudyIndex--;
                                });
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withValues(alpha: 0.04),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Previous",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        if (isLastCard) {
                          _showCompletionDialog();
                        } else {
                          setState(() {
                            _currentStudyIndex++;
                          });
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastCard ? "Finish" : "Next",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastCard
                                ? Icons.done_all_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141416),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.white12, width: 1),
          ),
          title: const Text(
            "Study Session Complete",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                "You have successfully reviewed all ${qa.length} cards!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentStudyIndex = 0;
                });
              },
              child: const Text(
                "Study Again",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Finish",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_isEditing) {
      return _buildEditing(widget.filename);
    } else {
      return _buildReading(widget.filename);
    }
  }
}

