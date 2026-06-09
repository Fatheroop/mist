import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mist/logic/alarms_cubit.dart';
import 'package:mist/logic/unviersalvariables.dart';

class CustomAudioSelectorScreen extends StatefulWidget {
  final VoidCallback callback;
  const CustomAudioSelectorScreen({super.key, required this.callback});

  @override
  State<CustomAudioSelectorScreen> createState() =>
      _CustomAudioSelectorScreenState();
}

class _CustomAudioSelectorScreenState extends State<CustomAudioSelectorScreen> {
  bool _isLoading = false;
  String? _playingPath;
  List<String> _audioFiles = [];
  AudioPlayer player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _isLoading = false;
    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingPath = null;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _audioFiles = await AlarmsCubit.instance.customAudios();
      setState(() {});
    });
  }

  @override
  void dispose() {
    player.stop();
    player.dispose();
    super.dispose();
  }

  Future<void> _importAudio() async {
    String path = (await getApplicationDocumentsDirectory()).path;
    Directory dir = Directory("$path/alarmsandremainder/");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.audio,
      );
      if (result != null) {
        List<String?> paths = result.paths;
        for (String? filePath in paths) {
          if (filePath != null) {
            File file = File(filePath);
            String name = file.uri.pathSegments.last;
            String dest = "$path/alarmsandremainder/$name";
            await file.copy(dest);
            _audioFiles = await AlarmsCubit.instance.customAudios();
            debugPrint(dest);
            for (String paths in _audioFiles) {
              debugPrint(paths);
            }
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint("Error in _importAudio: $e");
    }
  }

  Future<void> _togglePreview(String path) async {
    try {
      if (_playingPath == path) {
        await player.stop();
        setState(() {
          _playingPath = null;
        });
      } else {
        await player.stop();
        bool isasset = path.contains("assets/");
        if (isasset) {
          String assetPath = path.startsWith("assets/")
              ? path.substring(7)
              : path;
          await player.play(AssetSource(assetPath));
        } else {
          await player.play(DeviceFileSource(path));
        }
        setState(() {
          _playingPath = path;
        });
      }
    } catch (e) {
      debugPrint("Error in _togglePreview: $e");
    }
  }

  String _getFileSizeText(String filePath) {
    String extension = "";
    int lastDot = filePath.lastIndexOf('.');
    if (lastDot != -1) {
      extension = filePath.substring(lastDot + 1).toUpperCase();
    }
    String formatText = extension.isNotEmpty ? " • $extension" : "";

    if (filePath.startsWith("assets/") || !filePath.startsWith("/")) {
      return "System Sound$formatText";
    } else {
      try {
        final file = File(filePath);
        if (file.existsSync()) {
          final bytes = file.lengthSync();
          if (bytes >= 1024 * 1024) {
            return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB$formatText";
          } else {
            return "${(bytes / 1024).toStringAsFixed(2)} KB$formatText";
          }
        }
      } catch (e) {
        debugPrint("Error reading file size: $e");
      }
      return "Local File$formatText";
    }
  }

  Widget _audioPlayerItem(String filePath) {
    String toneName = filePath.split("/").last;
    int lastDot = toneName.lastIndexOf('.');
    if (lastDot != -1) {
      toneName = toneName.substring(0, lastDot);
    }
    toneName = toneName
        .split(RegExp(r'[-_]'))
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');

    bool isSelected = Unviersalvariables().audiopath == filePath;
    bool isPlaying = _playingPath == filePath;
    bool isAsset = filePath.startsWith("assets/") || !filePath.startsWith("/");

    return GestureDetector(
      onTap: () {
        _togglePreview(filePath);
        setState(() {
          Unviersalvariables().audiopath = filePath;
        });
        widget.callback();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.06),
              ),
              child: Icon(
                isPlaying
                    ? Icons.volume_up_rounded
                    : (isAsset
                          ? Icons.music_note_rounded
                          : Icons.audiotrack_rounded),
                color: isSelected ? Colors.black87 : Colors.white60,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          isAsset ? "SYSTEM" : "IMPORTED",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFileSizeText(filePath),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    toneName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isPlaying
                ? Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                : isSelected
                ? Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.black87,
                      size: 16,
                    ),
                  )
                : Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ALARM & TIMER SOUNDS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              "Choose system tones or manage custom audio",
              style: TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: "Rebuild Audios List",
            onPressed: () async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF111115),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: const Text(
                    "Audios list rebuilt successfully!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(
                          left: 4,
                          top: 12,
                          bottom: 8,
                        ),
                        child: Text(
                          "SYSTEM BUILT-IN TONES",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      ...AlarmsCubit.instance
                          .getDefaultAssetsAudio()
                          .map((tone) => _audioPlayerItem(tone)),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "IMPORTED CUSTOM AUDIO",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      if (_audioFiles.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.music_off_rounded,
                                  color: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "No custom audios imported yet",
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._audioFiles.map((file) {
                          return _audioPlayerItem(file);
                        }),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFEEEEEE)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: _importAudio,
                  icon: const Icon(
                    Icons.cloud_upload_rounded,
                    color: Colors.black87,
                  ),
                  label: const Text(
                    "Import Audio File",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
