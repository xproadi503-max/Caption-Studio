import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/caption_word.dart';
import '../providers/project_provider.dart';
import '../widgets/caption_preview_overlay.dart';

/// Lets the user fine-tune generated captions before export:
/// - Drag the caption directly on the video preview to place it anywhere
///   (per caption line, like Zeemo's manual positioning).
/// - Tap a line in the list below to jump the video to that moment and
///   select it for dragging.
/// - Edit the text of any line to fix transcription mistakes.
class CaptionEditorScreen extends StatefulWidget {
  const CaptionEditorScreen({super.key});

  @override
  State<CaptionEditorScreen> createState() => _CaptionEditorScreenState();
}

class _CaptionEditorScreenState extends State<CaptionEditorScreen> {
  VideoPlayerController? _controller;
  Timer? _ticker;
  int _positionMs = 0;
  late List<CaptionLine> _lines;
  int? _selectedLineIndex;
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    final project = context.read<ProjectProvider>();
    _lines = CaptionLine.applyTextOverrides(
      CaptionLine.groupWords(project.words),
      project.lineTextOverrides,
    );

    for (int i = 0; i < _lines.length; i++) {
      _textControllers[i] = TextEditingController(text: _lines[i].fullText);
    }

    _controller = VideoPlayerController.file(File(project.videoPath!))
      ..initialize().then((_) => setState(() {}));

    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_controller != null && _controller!.value.isInitialized) {
        final ms = _controller!.value.position.inMilliseconds;
        setState(() {
          _positionMs = ms;
          _selectedLineIndex = _lineIndexAt(ms) ?? _selectedLineIndex;
        });
      }
    });
  }

  int? _lineIndexAt(int ms) {
    for (int i = 0; i < _lines.length; i++) {
      if (ms >= _lines[i].startMs && ms <= _lines[i].endMs + 200) return i;
    }
    return null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller?.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seekToLine(int index) {
    _controller?.pause();
    _controller?.seekTo(Duration(milliseconds: _lines[index].startMs));
    setState(() => _selectedLineIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit captions'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                      if (_selectedLineIndex != null)
                        Positioned.fill(
                          child: CaptionPreviewOverlay(
                            lines: [_lines[_selectedLineIndex!]],
                            positionMs: _lines[_selectedLineIndex!].startMs,
                            template: project.selectedTemplate,
                            positionOverride:
                                project.linePositionOverrides[_selectedLineIndex!],
                            onPositionChanged: (offset) {
                              project.setLinePosition(_selectedLineIndex!, offset);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap a line below to select & drag it on the video. Edit text to fix mistakes.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedLineIndex == index;
                      final hasCustomPos =
                          project.linePositionOverrides.containsKey(index);
                      return Card(
                        color: isSelected
                            ? Colors.blueAccent.withOpacity(0.15)
                            : null,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline),
                                onPressed: () => _seekToLine(index),
                                tooltip: 'Jump to this line',
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _textControllers[index],
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    project.setLineText(index, value);
                                  },
                                  onTap: () => _seekToLine(index),
                                ),
                              ),
                              if (hasCustomPos)
                                IconButton(
                                  icon: const Icon(Icons.restart_alt, size: 20),
                                  tooltip: 'Reset position to default',
                                  onPressed: () => project.clearLinePosition(index),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
