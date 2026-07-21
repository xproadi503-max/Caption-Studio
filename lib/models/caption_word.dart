/// A single transcribed word with its start/end time (in milliseconds)
/// relative to the start of the video. This word-level granularity is
/// what enables karaoke-style / word-highlight animations like Zeemo,
/// CapCut, and similar caption tools use.
class CaptionWord {
  final String text;
  final int startMs;
  final int endMs;
  final double confidence;
  final int? speaker; // speaker index if diarization is enabled

  CaptionWord({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.confidence = 1.0,
    this.speaker,
  });

  factory CaptionWord.fromAssemblyAiJson(Map<String, dynamic> json) {
    return CaptionWord(
      text: json['text'] as String,
      startMs: json['start'] as int,
      endMs: json['end'] as int,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      speaker: json['speaker'] != null
          ? int.tryParse(json['speaker'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'start': startMs,
        'end': endMs,
        'confidence': confidence,
        'speaker': speaker,
      };
}

/// A group of words shown together as one caption "card" on screen
/// (e.g. 3-6 words at a time), which is how short-form video captions
/// are typically chunked rather than showing a whole sentence at once.
class CaptionLine {
  final List<CaptionWord> words;

  CaptionLine(this.words);

  int get startMs => words.first.startMs;
  int get endMs => words.last.endMs;
  String get fullText => words.map((w) => w.text).join(' ');

  /// Groups a flat list of words into caption lines, breaking on
  /// [maxWordsPerLine] words or [maxGapMs] of silence between words.
  static List<CaptionLine> groupWords(
    List<CaptionWord> words, {
    int maxWordsPerLine = 5,
    int maxGapMs = 700,
    int maxCharsPerLine = 28,
  }) {
    final lines = <CaptionLine>[];
    var current = <CaptionWord>[];
    int currentChars = 0;

    for (final word in words) {
      final wouldBreakOnGap = current.isNotEmpty &&
          (word.startMs - current.last.endMs) > maxGapMs;
      final wouldBreakOnCount = current.length >= maxWordsPerLine;
      final wouldBreakOnChars =
          (currentChars + word.text.length + 1) > maxCharsPerLine;

      if (current.isNotEmpty &&
          (wouldBreakOnGap || wouldBreakOnCount || wouldBreakOnChars)) {
        lines.add(CaptionLine(List.of(current)));
        current = [];
        currentChars = 0;
      }
      current.add(word);
      currentChars += word.text.length + 1;
    }
    if (current.isNotEmpty) {
      lines.add(CaptionLine(List.of(current)));
    }
    return lines;
  }
}
