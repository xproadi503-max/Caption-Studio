import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caption_word.dart';
import '../models/caption_style.dart';
import '../models/caption_templates.dart';

enum PipelineStage {
  idle,
  extractingAudio,
  uploading,
  transcribing,
  ready,
  exporting,
  done,
  error,
}

/// Central state for the current captioning project: the picked video,
/// its transcription result, the chosen template, and pipeline status.
/// Kept as a single ChangeNotifier so every screen (picker, editor,
/// export) reflects the same project state without re-fetching.
class ProjectProvider extends ChangeNotifier {
  String? videoPath;
  int videoDurationMs = 0;
  List<CaptionWord> words = [];
  CaptionTemplate selectedTemplate = CaptionTemplates.all.first;
  PipelineStage stage = PipelineStage.idle;
  String statusMessage = '';
  double progress = 0.0;
  String? exportedVideoPath;
  String? errorMessage;
  String? _apiKey;

  static const _prefsKey = 'assemblyai_api_key';

  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefsKey);
    notifyListeners();
  }

  String? get apiKey => _apiKey;

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, key);
    notifyListeners();
  }

  void setVideo(String path, int durationMs) {
    videoPath = path;
    videoDurationMs = durationMs;
    words = [];
    exportedVideoPath = null;
    stage = PipelineStage.idle;
    notifyListeners();
  }

  void setTemplate(CaptionTemplate template) {
    selectedTemplate = template;
    notifyListeners();
  }

  void updateStage(PipelineStage newStage, {String message = ''}) {
    stage = newStage;
    statusMessage = message;
    notifyListeners();
  }

  void updateProgress(double value) {
    progress = value;
    notifyListeners();
  }

  void setWords(List<CaptionWord> newWords) {
    words = newWords;
    stage = PipelineStage.ready;
    notifyListeners();
  }

  void setError(String message) {
    errorMessage = message;
    stage = PipelineStage.error;
    notifyListeners();
  }

  void setExportedVideo(String path) {
    exportedVideoPath = path;
    stage = PipelineStage.done;
    notifyListeners();
  }

  void reset() {
    videoPath = null;
    videoDurationMs = 0;
    words = [];
    exportedVideoPath = null;
    stage = PipelineStage.idle;
    progress = 0.0;
    errorMessage = null;
    notifyListeners();
  }
}
