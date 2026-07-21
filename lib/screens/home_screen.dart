import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/project_provider.dart';
import '../services/audio_extractor.dart';
import '../services/transcription_service.dart';
import '../utils/permissions.dart';
import 'template_picker_screen.dart';

// PASTE YOUR OWN ASSEMBLYAI API KEY BELOW (between the quotes).
// Once set, the app pre-fills it automatically so you never have to
// type it again. Get a free key at https://www.assemblyai.com/
const String kDefaultApiKey = 'ed4b43fd15ec46e48c00eb95e2aa18aa';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final project = context.read<ProjectProvider>();
    project.loadApiKey().then((_) {
      _apiKeyController.text = project.apiKey?.isNotEmpty == true
          ? project.apiKey!
          : kDefaultApiKey;
    });
  }

  Future<void> _pickVideo(BuildContext context) async {
    final project = context.read<ProjectProvider>();

    if (_apiKeyController.text.trim().isEmpty) {
      _showMessage('Enter your AssemblyAI API key first.');
      return;
    }
    await project.setApiKey(_apiKeyController.text.trim());

    final granted = await AppPermissions.requestMediaPermissions();
    if (!granted) {
      _showMessage('Storage/media permission is required to pick a video.');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final controller = VideoPlayerController.file(File(picked.path));
    await controller.initialize();
    final durationMs = controller.value.duration.inMilliseconds;
    final size = controller.value.size;
    await controller.dispose();

    project.setVideo(
      picked.path,
      durationMs,
      width: size.width.round(),
      height: size.height.round(),
    );
    await _runPipeline(context, picked.path);
  }

  Future<void> _runPipeline(BuildContext context, String videoPath) async {
    final project = context.read<ProjectProvider>();
    try {
      project.updateStage(PipelineStage.extractingAudio,
          message: 'Extracting audio from video...');
      final audioPath = await AudioExtractor.extractAudio(videoPath);

      project.updateStage(PipelineStage.uploading,
          message: 'Uploading audio for transcription...');
      final service = TranscriptionService(project.apiKey!);
      final words = await service.transcribeAudioFile(
        File(audioPath),
        onStatus: (status) {
          project.updateStage(PipelineStage.transcribing,
              message: 'Transcription status: $status');
        },
      );

      if (words.isEmpty) {
        project.setError(
            'No speech was detected in this video. Try a clip with clearer audio.');
        return;
      }

      project.setWords(words);

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TemplatePickerScreen()),
        );
      }
    } catch (e) {
      project.setError(e.toString());
      _showMessage('Something went wrong: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final project = context.watch<ProjectProvider>();
    final isBusy = project.stage != PipelineStage.idle &&
        project.stage != PipelineStage.error &&
        project.stage != PipelineStage.ready;

    return Scaffold(
      appBar: AppBar(title: const Text('Caption Studio')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Auto-generate animated captions for your videos.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'AssemblyAI API Key',
                helperText: 'Get a free key at assemblyai.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isBusy ? null : () => _pickVideo(context),
              icon: const Icon(Icons.video_library),
              label: const Text('Pick a video & generate captions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (isBusy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  project.statusMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (project.stage == PipelineStage.error &&
                project.errorMessage != null) ...[
              Text(
                project.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
