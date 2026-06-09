import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mist/repo/permission_handler.dart';
import 'package:mist/logic/folder_cubit.dart';
import 'package:mist/uis/android/ui_canvas.dart';
import 'package:mist/uis/android/ui_flash_cards.dart';
import 'package:mist/uis/android/widgets/filegrid_widget.dart';
import 'package:mist/uis/android/widgets/json_viewer.dart';
import 'package:mist/uis/android/widgets/premium_toast.dart';
import 'package:mist/uis/android/widgets/study_note_editor.dart';
import 'package:mist/uis/android/widgets/tactile_vault_card.dart';

class UiFolderScreen extends StatefulWidget {
  const UiFolderScreen({super.key});

  @override
  State<UiFolderScreen> createState() => _UiFolderScreenState();
}

class _UiFolderScreenState extends State<UiFolderScreen> {
  late final FolderCubit _logic;

  @override
  void initState() {
    super.initState();
    _logic = context.read<FolderCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic.checkPermissionAndInit();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Premium Toast System
  void _showPremiumToast(String message, {bool isError = false}) {
    if (!mounted) return;

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => PremiumToastWidget(
        message: message,
        isError: isError,
        isWarning: false,
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  // File system CRUD UI wrappers calling the Logic Layer
  Future<void> _createNewFolder(String name) async {
    final err = await _logic.createNewFolder(name);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Folder '$name' created successfully!");
    }
  }

  Future<void> _createNewVault(
    String name,
    String pin,
    String decoyPin,
    String securityQuestion,
    String securityAnswer,
    String passcodeHint,
    String colorName,
    String iconName,
  ) async {
    final err = await _logic.createNewVault(
      name: name,
      pin: pin,
      decoyPin: decoyPin,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      passcodeHint: passcodeHint,
      colorName: colorName,
      iconName: iconName,
    );
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Secure Vault '$name' created!");
    }
  }

  Future<void> _createNewNote(String name) async {
    final file = await _logic.createNewNote(
      name,
      onError: (err) {
        _showPremiumToast(err, isError: true);
      },
    );
    if (file != null) {
      _showPremiumToast("Note '$name' created!");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudyNoteEditorScreen(
              file: file,
              onSave: () => _logic.refreshFiles(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _createNewCanvas(String name) async {
    final file = await _logic.createNewCanvas(
      name,
      onError: (err) {
        _showPremiumToast(err, isError: true);
      },
    );
    if (file != null) {
      _showPremiumToast("Canvas '$name' created!");
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CanvasHome(file: file)),
        ).then((_) => _logic.refreshFiles());
      }
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final name = entity.path.split('/').last.replaceAll(".txt", "");
    final err = await _logic.deleteEntity(entity);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("'$name' deleted successfully.");
    }
  }

  Future<void> _renameEntity(FileSystemEntity entity, String newName) async {
    final err = await _logic.renameEntity(entity, newName);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Renamed successfully!");
    }
  }

  Future<void> _lockFolder(
    Directory dir,
    String pin,
    String decoyPin,
    String securityQuestion,
    String securityAnswer,
    String passcodeHint,
  ) async {
    final err = await _logic.lockFolder(
      dir: dir,
      pin: pin,
      decoyPin: decoyPin,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      passcodeHint: passcodeHint,
    );
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Folder encrypted successfully!");
    }
  }

  Future<void> _unlockFolder(Directory dir) async {
    final err = await _logic.unlockFolder(dir);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Folder decrypted successfully!");
    }
  }

  Future<void> _copyEntity(FileSystemEntity source, Directory target) async {
    final err = await _logic.copyEntity(source, target);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Copied successfully!");
    }
  }

  Future<void> _moveEntity(FileSystemEntity source, Directory target) async {
    final err = await _logic.moveEntity(source, target);
    if (err != null) {
      _showPremiumToast(err, isError: true);
    } else {
      _showPremiumToast("Moved successfully!");
    }
  }

  void _onFolderTap(Directory dir) {
    if (_logic.isFolderLocked(dir)) {
      _showPINPadModal(dir);
    } else {
      _logic.navigateToDirectory(dir);
    }
  }

  // Modal Dialogs & Keypads
  void _showPINPadModal(Directory dir) {
    final expectedPIN = _logic.getFolderPIN(dir);
    final decoyPIN = _logic.getDecoyPIN(dir);
    final vaultColor = _logic.getVaultColor(dir);
    final vaultIcon = _logic.getVaultIcon(dir);
    String enteredPIN = "";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C16).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: vaultColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: vaultColor.withValues(alpha: 0.05),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: vaultColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(vaultIcon, color: vaultColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Secure Folder Vault",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter the 4-digit PIN to unlock",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final hasValue = index < enteredPIN.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasValue ? vaultColor : Colors.transparent,
                              border: Border.all(
                                color: vaultColor.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 12,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, index) {
                          if (index == 9) {
                            return IconButton(
                              onPressed: () {
                                if (enteredPIN.isNotEmpty) {
                                  setModalState(() {
                                    enteredPIN = enteredPIN.substring(
                                      0,
                                      enteredPIN.length - 1,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.backspace_rounded,
                                color: Colors.white54,
                              ),
                            );
                          }
                          if (index == 11) {
                            return IconButton(
                              onPressed: () {
                                setModalState(() {
                                  enteredPIN = "";
                                });
                              },
                              icon: const Icon(
                                Icons.clear_all_rounded,
                                color: Colors.white54,
                              ),
                            );
                          }
                          final number = index == 10 ? 0 : index + 1;
                          return TextButton(
                            onPressed: () {
                              if (enteredPIN.length < 4) {
                                setModalState(() {
                                  enteredPIN += number.toString();
                                });
                                if (enteredPIN.length == 4) {
                                  if (enteredPIN == expectedPIN) {
                                    Navigator.pop(context);
                                    _logic.isDecoyActive = false;
                                    _logic.navigateToDirectory(dir);
                                    _showPremiumToast("Access Granted!");
                                  } else if (decoyPIN != null &&
                                      decoyPIN.isNotEmpty &&
                                      enteredPIN == decoyPIN) {
                                    Navigator.pop(context);
                                    _logic.isDecoyActive = true;
                                    _logic.navigateToDirectory(
                                      dir,
                                      keepDecoy: true,
                                    );
                                    _showPremiumToast(
                                      "Access Granted! (Decoy)",
                                    );
                                  } else {
                                    setModalState(() {
                                      enteredPIN = "";
                                    });
                                    _showPremiumToast(
                                      "Incorrect PIN. Try again.",
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.03,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              number.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _showRecoveryDialog(dir);
                        },
                        child: Text(
                          "Forgot PIN?",
                          style: TextStyle(
                            color: vaultColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRecoveryDialog(Directory dir) {
    final recovery = _logic.getVaultRecoveryInfo(dir);
    final question = recovery["question"] ?? "";
    final answer = recovery["answer"] ?? "";
    final hint = recovery["hint"] ?? "";
    final pin = recovery["pin"] ?? "";

    String enteredAnswer = "";

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              "Vault Recovery",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (question.isNotEmpty) ...[
                    const Text(
                      "Security Question:",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => enteredAnswer = val,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.amberAccent,
                      decoration: InputDecoration(
                        hintText: "Enter your answer...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      "No security question configured for this vault.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      "Passcode Hint:",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        hint,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              if (question.isNotEmpty)
                TextButton(
                  onPressed: () {
                    if (enteredAnswer.trim().toLowerCase() ==
                        answer.trim().toLowerCase()) {
                      Navigator.pop(context); // Close recovery dialog
                      Navigator.pop(context); // Close PIN Pad dialog

                      _showPremiumToast("Recovery Successful! Unlocked vault.");
                      _logic.navigateToDirectory(dir);

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF131324),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          title: const Text(
                            "Recovery Successful",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            "Passcode verified. Your vault PIN is: $pin\n\nEnsure to remember it or customize it.",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "OK",
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _showPremiumToast(
                        "Incorrect answer. Try again.",
                        isError: true,
                      );
                    }
                  },
                  child: const Text(
                    "Verify Answer",
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    String folderName = "";

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.create_new_folder_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 10),
                Text(
                  "Create Folder",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: TextField(
              onChanged: (val) => folderName = val,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.amberAccent,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter folder name...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.amberAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (folderName.trim().isEmpty) return;
                  Navigator.pop(context);
                  _createNewFolder(folderName.trim());
                },
                child: const Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateVaultDialog() {
    String vaultName = "";
    String pin = "";
    String decoyPin = "";
    String selectedQuestion = "What was the name of your first school?";
    String securityAnswer = "";
    String passcodeHint = "";
    String selectedColor = "amber";
    String selectedIcon = "vault";

    final iconOptions = [
      {"name": "vault", "icon": FontAwesomeIcons.vault},
      {"name": "lock", "icon": FontAwesomeIcons.lock},
      {"name": "shield", "icon": FontAwesomeIcons.shieldHalved},
      {"name": "key", "icon": FontAwesomeIcons.key},
      {"name": "secret", "icon": FontAwesomeIcons.userSecret},
      {"name": "graduate", "icon": FontAwesomeIcons.userGraduate},
      {"name": "book", "icon": FontAwesomeIcons.bookOpen},
      {"name": "eye-slash", "icon": FontAwesomeIcons.eyeSlash},
    ];

    final securityQuestionsList = [
      "What was the name of your first school?",
      "What is your favorite book?",
      "What city were you born in?",
      "What is your mother's maiden name?",
      "What was the name of your first pet?",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeColor = Colors.white;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: const Color(0xFF131324),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  "Create Secure Vault",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vault Name input
                      TextField(
                        onChanged: (val) => vaultName = val,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: activeColor,
                        decoration: InputDecoration(
                          hintText: "Enter vault name...",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // PIN input
                      TextField(
                        onChanged: (val) => pin = val,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        cursorColor: activeColor,
                        decoration: InputDecoration(
                          hintText: "Enter 4-digit PIN",
                          counterText: "",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Decoy PIN input
                      TextField(
                        onChanged: (val) => decoyPin = val,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        cursorColor: activeColor,
                        decoration: InputDecoration(
                          hintText: "Decoy PIN (Optional)",
                          counterText: "",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Security Question Dropdown
                      const Text(
                        "Recovery Security Question",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(canvasColor: const Color(0xFF131324)),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedQuestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          items: securityQuestionsList.map((q) {
                            return DropdownMenuItem<String>(
                              value: q,
                              child: Text(
                                q,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedQuestion = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Security Answer input
                      TextField(
                        onChanged: (val) => securityAnswer = val,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: activeColor,
                        decoration: InputDecoration(
                          hintText: "Answer to security question",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Passcode Hint input
                      TextField(
                        onChanged: (val) => passcodeHint = val,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: activeColor,
                        decoration: InputDecoration(
                          hintText: "Passcode Hint (Optional)",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: activeColor),
                          ),
                        ),
                      ),

                      // Icon selection header
                      const Text(
                        "Select Vault Emblem",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Icon selections (Wrap to avoid overflow)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: iconOptions.map((opt) {
                          final isSelected = selectedIcon == opt["name"];
                          final icon = opt["icon"] as FaIconData;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedIcon = opt["name"] as String;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? activeColor.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? activeColor
                                      : Colors.white10,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: FaIcon(
                                  icon,
                                  color: isSelected
                                      ? activeColor
                                      : Colors.white38,
                                  size: 16,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (vaultName.trim().isEmpty) {
                        _showPremiumToast(
                          "Vault name cannot be empty",
                          isError: true,
                        );
                        return;
                      }
                      if (pin.length != 4) {
                        _showPremiumToast(
                          "Passcode must be exactly 4 digits",
                          isError: true,
                        );
                        return;
                      }
                      if (decoyPin.isNotEmpty && decoyPin.length != 4) {
                        _showPremiumToast(
                          "Decoy PIN must be exactly 4 digits",
                          isError: true,
                        );
                        return;
                      }
                      if (securityAnswer.isEmpty) {
                        _showPremiumToast(
                          "Security answer is required",
                          isError: true,
                        );
                        return;
                      }
                      Navigator.pop(context);
                      _createNewVault(
                        vaultName.trim(),
                        pin,
                        decoyPin,
                        selectedQuestion,
                        securityAnswer,
                        passcodeHint,
                        selectedColor,
                        selectedIcon,
                      );
                    },
                    child: Text(
                      "Create",
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLockFolderDialog(Directory dir) {
    String pin = "";
    String decoyPin = "";
    String selectedQuestion = "What was the name of your first school?";
    String securityAnswer = "";
    String passcodeHint = "";

    final securityQuestionsList = [
      "What was the name of your first school?",
      "What is your favorite book?",
      "What city were you born in?",
      "What is your mother's maiden name?",
      "What was the name of your first pet?",
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF131324),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  "Encrypt Folder into Vault",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PIN input
                      TextField(
                        onChanged: (val) => pin = val,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.amberAccent,
                        decoration: InputDecoration(
                          hintText: "Enter 4-digit PIN",
                          counterText: "",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Decoy PIN input
                      TextField(
                        onChanged: (val) => decoyPin = val,
                        maxLength: 4,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.amberAccent,
                        decoration: InputDecoration(
                          hintText: "Decoy PIN (Optional)",
                          counterText: "",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Security Question Dropdown
                      const Text(
                        "Recovery Security Question",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(canvasColor: const Color(0xFF131324)),
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedQuestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.03),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          items: securityQuestionsList.map((q) {
                            return DropdownMenuItem<String>(
                              value: q,
                              child: Text(
                                q,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedQuestion = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Security Answer input
                      TextField(
                        onChanged: (val) => securityAnswer = val,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.amberAccent,
                        decoration: InputDecoration(
                          hintText: "Answer to security question",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Passcode Hint input
                      TextField(
                        onChanged: (val) => passcodeHint = val,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.amberAccent,
                        decoration: InputDecoration(
                          hintText: "Passcode Hint (Optional)",
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.amberAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (pin.length != 4) {
                        _showPremiumToast(
                          "Passcode must be exactly 4 digits",
                          isError: true,
                        );
                        return;
                      }
                      if (decoyPin.isNotEmpty && decoyPin.length != 4) {
                        _showPremiumToast(
                          "Decoy PIN must be exactly 4 digits",
                          isError: true,
                        );
                        return;
                      }
                      if (securityAnswer.isEmpty) {
                        _showPremiumToast(
                          "Security answer is required",
                          isError: true,
                        );
                        return;
                      }
                      Navigator.pop(context);
                      await _lockFolder(
                        dir,
                        pin,
                        decoyPin,
                        selectedQuestion,
                        securityAnswer,
                        passcodeHint,
                      );
                    },
                    child: const Text(
                      "Encrypt",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateNoteDialog() {
    String noteName = "";

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.note_add_outlined, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  "Create Study Note",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: TextField(
              onChanged: (val) => noteName = val,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.amberAccent,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter note title...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.amberAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createNewNote(noteName.trim());
                },
                child: const Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateCanvasDialog() {
    String canvasName = "";

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.borderAll,
                  color: Colors.orangeAccent,
                  size: 18,
                ),
                SizedBox(width: 10),
                Text(
                  "Create Canvas",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: TextField(
              onChanged: (val) => canvasName = val,
              style: const TextStyle(color: Colors.white),
              autocorrect: true,
              autofocus: true,
              cursorColor: Colors.orangeAccent,
              decoration: InputDecoration(
                hintText: "Enter canvas name...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.orangeAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _createNewCanvas(canvasName.trim());
                },
                child: const Text(
                  "Create",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOperationsSheet(FileSystemEntity item) {
    final isDir = item is Directory;
    final name = item.path.split('/').last.replaceAll(".txt", "");
    final isLocked = isDir && _logic.isFolderLocked(item);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F15).withValues(alpha: 0.75),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDir
                        ? (isLocked ? "🔒 Secure Vault Folder" : "📁 Folder")
                        : "📝 Study Note",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Open Option
                  ListTile(
                    leading: Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    title: const Text(
                      "Open",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      FilegridWidget(
                        entity: item,
                        actiononfolder: () {
                          _onFolderTap(item as Directory);
                        },
                        folderCubit: _logic,
                      ).navigate(context);
                      if (item is Directory) {
                        Navigator.pop(context);
                      }
                    },
                  ),

                  if (!isDir)
                    ListTile(
                      leading: Icon(
                        Icons.javascript_outlined,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      title: const Text(
                        "Json View",
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) {
                              return JsonViewer(file: item as File);
                            },
                          ),
                        );
                      },
                    ),

                  // Rename Option
                  ListTile(
                    leading: Icon(
                      Icons.edit_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    title: const Text(
                      "Rename",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showRenameDialog(item);
                    },
                  ),

                  // Move Option
                  ListTile(
                    leading: Icon(
                      Icons.drive_file_move_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    title: const Text(
                      "Move to...",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showTargetSelector(item, isMove: true);
                    },
                  ),

                  // Copy Option
                  if (!isDir)
                    ListTile(
                      leading: Icon(
                        Icons.copy_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      title: const Text(
                        "Copy to...",
                        style: TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showTargetSelector(item, isMove: false);
                      },
                    ),

                  // Lock/Unlock Options (Folders only)
                  if (isDir)
                    ListTile(
                      leading: Icon(
                        isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      title: Text(
                        isLocked
                            ? "Decrypt Folder"
                            : "Encrypt Folder into Vault",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (isLocked) {
                          _verifyVaultAccessAndExecute(item, () {
                            _unlockFolder(item);
                          });
                        } else {
                          _showLockFolderDialog(item);
                        }
                      },
                    ),

                  // Delete Option
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "Delete",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteConfirmDialog(item);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(FileSystemEntity entity) {
    final currentName = entity.path.split('/').last.replaceAll(".txt", "");
    String newName = currentName;

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              "Rename Item",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: TextEditingController(text: currentName),
              onChanged: (val) => newName = val,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.amberAccent,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.amberAccent),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _renameEntity(entity, newName);
                },
                child: const Text(
                  "Rename",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _verifyVaultAccessAndExecute(Directory vault, VoidCallback onSuccess) {
    if (!_logic.isFolderLocked(vault)) {
      onSuccess();
      return;
    }

    final expectedPIN = _logic.getFolderPIN(vault);
    final vaultColor = _logic.getVaultColor(vault);
    final vaultIcon = _logic.getVaultIcon(vault);
    String enteredPIN = "";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0C16).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: vaultColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: vaultColor.withValues(alpha: 0.05),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: vaultColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(vaultIcon, color: vaultColor, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Unlock Destination Vault",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter the 4-digit PIN to authorize action",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final hasValue = index < enteredPIN.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasValue ? vaultColor : Colors.transparent,
                              border: Border.all(
                                color: vaultColor.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 12,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, index) {
                          if (index == 9) {
                            return IconButton(
                              onPressed: () {
                                if (enteredPIN.isNotEmpty) {
                                  setModalState(() {
                                    enteredPIN = enteredPIN.substring(
                                      0,
                                      enteredPIN.length - 1,
                                    );
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.backspace_rounded,
                                color: Colors.white54,
                              ),
                            );
                          }
                          if (index == 11) {
                            return IconButton(
                              onPressed: () {
                                setModalState(() {
                                  enteredPIN = "";
                                });
                              },
                              icon: const Icon(
                                Icons.clear_all_rounded,
                                color: Colors.white54,
                              ),
                            );
                          }
                          final number = index == 10 ? 0 : index + 1;
                          return TextButton(
                            onPressed: () {
                              if (enteredPIN.length < 4) {
                                setModalState(() {
                                  enteredPIN += number.toString();
                                });
                                if (enteredPIN.length == 4) {
                                  if (enteredPIN == expectedPIN) {
                                    Navigator.pop(context);
                                    onSuccess();
                                  } else {
                                    setModalState(() {
                                      enteredPIN = "";
                                    });
                                    _showPremiumToast(
                                      "Incorrect PIN. Try again.",
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.03,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              number.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTargetSelector(FileSystemEntity item, {required bool isMove}) {
    final dirs = _logic.getAllSubfolders();
    if (dirs.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color(0xFF131324),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              isMove ? "Move File" : "Copy File",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dirs.length,
                itemBuilder: (context, idx) {
                  final dir = dirs[idx];
                  final relativePath = dir.path.replaceAll(
                    _logic.baseDirectory!.path,
                    "",
                  );
                  final displayName = relativePath.isEmpty
                      ? "/ (Explorer Root)"
                      : relativePath;

                  return ListTile(
                    leading: const FaIcon(
                      FontAwesomeIcons.folder,
                      color: Colors.amberAccent,
                      size: 16,
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _verifyVaultAccessAndExecute(dir, () {
                        if (isMove) {
                          _moveEntity(item, dir);
                        } else {
                          _copyEntity(item, dir);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(FileSystemEntity entity) {
    final name = entity.path.split('/').last.replaceAll(".txt", "");
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF131324),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            "Delete Item",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Are you sure you want to permanently delete '$name'?",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteEntity(entity);
              },
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Toolbar Builder
  Widget _buildToolBAR() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 5,
        runSpacing: 8,
        children: [
          _buildToolbarButton(
            label: "Notes",
            icon: FontAwesomeIcons.solidFileLines,
            color: Colors.purpleAccent,
            onTap: _showCreateNoteDialog,
          ),
          _buildToolbarButton(
            label: "Folder",
            icon: FontAwesomeIcons.folderPlus,
            color: Colors.amberAccent,
            onTap: _showCreateFolderDialog,
          ),
          _buildToolbarButton(
            label: "Vault",
            icon: FontAwesomeIcons.vault,
            color: Colors.tealAccent,
            onTap: _showCreateVaultDialog,
          ),
          _buildToolbarButton(
            label: "Flash Card",
            icon: FontAwesomeIcons.solidNoteSticky,
            color: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UiFlashCards()),
              );
            },
          ),
          _buildToolbarButton(
            label: "Canvas",
            icon: FontAwesomeIcons.borderAll,
            color: Colors.orangeAccent,
            onTap: _showCreateCanvasDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required FaIconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Primary UI components
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FolderCubit, FolderState>(
      builder: (context, state) {
        final isRoot = state.isRoot;

        return PopScope(
          canPop: isRoot,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _logic.goBack();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0C0C16),
            body: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purpleAccent.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                    child: const SizedBox.shrink(),
                  ),
                ),

                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            if (!isRoot)
                              IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () => _logic.goBack(),
                              ),
                            Expanded(child: _buildBreadcrumbs()),
                          ],
                        ),
                      ),

                      const Divider(color: Colors.white10, height: 1),
                      if (state.isStoragePermissionGranted && !state.isLoading)
                        _buildToolBAR(),
                      if (state.isStoragePermissionGranted && !state.isLoading)
                        const Divider(color: Colors.white10, height: 1),

                      Expanded(
                        child: state.isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.amberAccent,
                                ),
                              )
                            : (!state.isStoragePermissionGranted
                                  ? _buildPermissionWarning()
                                  : ((state.items.isEmpty && isRoot)
                                        ? _buildEmptyState()
                                        : _buildFilesGrid())),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumbs() {
    if (_logic.baseDirectory == null || _logic.currentDirectory == null) {
      return const SizedBox.shrink();
    }

    final relativePath = _logic.currentDirectory!.path.replaceAll(
      _logic.baseDirectory!.path,
      "",
    );
    final segments = relativePath
        .split('/')
        .where((s) => s.isNotEmpty && s != '.decoy_data')
        .toList();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          GestureDetector(
            onTap: () {
              if (_logic.currentDirectory!.path != _logic.baseDirectory!.path) {
                _logic.navigateToDirectory(_logic.baseDirectory!);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.folderOpen,
                  color:
                      _logic.currentDirectory!.path ==
                          _logic.baseDirectory!.path
                      ? Colors.amberAccent
                      : Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(
                  "Folders",
                  style: TextStyle(
                    color:
                        _logic.currentDirectory!.path ==
                            _logic.baseDirectory!.path
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...segments.asMap().entries.map((entry) {
            final idx = entry.key;
            final segmentName = entry.value;
            final isLast = idx == segments.length - 1;

            final pathBuilder = segments.sublist(0, idx + 1).join('/');
            final targetPath = Directory(
              '${_logic.baseDirectory!.path}/$pathBuilder',
            );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 16,
                ),
                GestureDetector(
                  onTap: () {
                    if (!isLast) {
                      _logic.navigateToDirectory(targetPath);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      segmentName,
                      style: TextStyle(
                        color: isLast ? Colors.white : Colors.white54,
                        fontSize: 13,
                        fontWeight: isLast
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.circleExclamation,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Storage Access Required",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "MIST Folders requires storage permissions to create local study folders and note files.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              TextButton(
                onPressed: () async {
                  await PermissionHandler().requestAllPermissions();
                  await _logic.checkPermissionAndInit();
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Grant Access",
                  style: TextStyle(
                    color: Color(0xFF0C0C16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amberAccent.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: const FaIcon(
                FontAwesomeIcons.folderOpen,
                color: Colors.amberAccent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Folders are Empty",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create study folders or notes to get started.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesGrid() {
    final showParentTile = !_logic.isRoot;
    final totalCount = _logic.items.length + (showParentTile ? 1 : 0);

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: totalCount,
      itemBuilder: (context, idx) {
        if (showParentTile && idx == 0) {
          return FadeInUp(
            duration: const Duration(milliseconds: 200),
            child: TactileParentFolderCard(
              onTap: () {
                _logic.goBack();
              },
            ),
          );
        }

        final itemIdx = showParentTile ? idx - 1 : idx;
        final item = _logic.items[itemIdx];
        FilegridWidget widget = FilegridWidget(
          entity: item,
          actiononfolder: () {
            _onFolderTap(item as Directory);
          },
          folderCubit: _logic,
        );
        return FadeInUp(
          key: ValueKey(item.path),
          duration: Duration(milliseconds: 200 + (idx * 50)),
          child: TactileVaultCard(
            item: item,
            widget: widget,
            onTap: () {
              widget.navigate(context);
            },
            onLongPress: () => _showOperationsSheet(item),
          ),
        );
      },
    );
  }
}

