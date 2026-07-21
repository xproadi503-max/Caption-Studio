import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/project_provider.dart';
import '../services/ass_generator.dart';
import '../services/video_export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  double _progress = 0.0;
  String _status = 'Preparing export...';
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _export());
  }

  Future<void> _export() async {
    final project = context.read<ProjectProvider>();
    try {
      setState(() => _status = 'Generating subtitle file...');
      final assContent = AssGenerator.generate(
        words: project.words,
        template: project.selectedTemplate,
        positionOverrides: project.linePositionOverrides,
        textOverrides: project.lineTextOverrides,
        videoWidth: project.videoWidth,
        videoHeight: project.videoHeight,
      );
      final tempDir = await getTemporaryDirectory();
      final assFile = File('${tempDir.path}/captions_${DateTime.now().millisecondsSinceEpoch}.ass');
      await assFile.writeAsString(assContent);

      setState(() => _status = 'Burning captions into video...');
      final outputPath = await VideoExportService.burnCaptions(
        videoPath: project.videoPath!,
        assFilePath: assFile.path,
        durationMs: project.videoDurationMs,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      project.setExportedVideo(outputPath);
      setState(() {
        _done = true;
        _status = 'Export complete!';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _saveToGallery() async {
    final project = context.read<ProjectProvider>();
    if (project.exportedVideoPath == null) return;
    try {
      await Gal.putVideo(project.exportedVideoPath!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to gallery!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _shareVideo() async {
    final project = context.read<ProjectProvider>();
    if (project.exportedVideoPath == null) return;
    await Share.shareXFiles([XFile(project.exportedVideoPath!)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ] else if (!_done) ...[
                CircularProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 20),
                Text(_status),
                const SizedBox(height: 8),
                Text('${(_progress * 100).toStringAsFixed(0)}%'),
              ] else ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const SizedBox(height: 16),
                const Text('Your captioned video is ready!'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.download),
                  label: const Text('Save to gallery'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _shareVideo,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
