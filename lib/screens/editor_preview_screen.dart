import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/caption_word.dart';
import '../providers/project_provider.dart';
import '../widgets/caption_preview_overlay.dart';
import 'export_screen.dart';

class EditorPreviewScreen extends StatefulWidget {
  const EditorPreviewScreen({super.key});

  @override
  State<EditorPreviewScreen> createState() => _EditorPreviewScreenState();
}

class _EditorPreviewScreenState extends State<EditorPreviewScreen> {
  VideoPlayerController? _controller;
  Timer? _ticker;
  int _positionMs = 0;
  late List<CaptionLine> _lines;

  @override
  void initState() {
    super.initState();
    final project = context.read<ProjectProvider>();
    _lines = CaptionLine.groupWords(project.words);
    _controller = VideoPlayerController.file(File(project.videoPath!))
      ..initialize().then((_) {
        setState(() {});
        _controller!.play();
      });

    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_controller != null && _controller!.value.isInitialized) {
        setState(() {
          _positionMs = _controller!.value.position.inMilliseconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Preview — ${project.selectedTemplate.name}'),
      ),
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                      Positioned.fill(
                        child: CaptionPreviewOverlay(
                          lines: _lines,
                          positionMs: _positionMs,
                          template: project.selectedTemplate,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(_controller!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () {
                        setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        });
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.movie_creation_outlined),
                      label: const Text('Export video with captions'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        _controller?.pause();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ExportScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
