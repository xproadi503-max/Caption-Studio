import 'package:flutter/material.dart';
import '../models/caption_word.dart';
import '../models/caption_style.dart';

/// Renders the currently-active caption line on top of the video
/// preview, matching (approximately) how the same line + template will
/// look once burned into the exported video via the ASS generator.
/// This is a live Flutter re-implementation of the animation styles
/// (not a literal ASS renderer), so it stays smooth during scrubbing.
class CaptionPreviewOverlay extends StatelessWidget {
  final List<CaptionLine> lines;
  final int positionMs;
  final CaptionTemplate template;

  const CaptionPreviewOverlay({
    super.key,
    required this.lines,
    required this.positionMs,
    required this.template,
  });

  CaptionLine? get _activeLine {
    for (final line in lines) {
      if (positionMs >= line.startMs && positionMs <= line.endMs + 200) {
        return line;
      }
    }
    return null;
  }

  int get _activeWordIndex {
    final line = _activeLine;
    if (line == null) return -1;
    for (int i = 0; i < line.words.length; i++) {
      final w = line.words[i];
      final nextStart =
          i < line.words.length - 1 ? line.words[i + 1].startMs : line.endMs + 200;
      if (positionMs >= w.startMs && positionMs < nextStart) return i;
    }
    return line.words.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final line = _activeLine;
    if (line == null) return const SizedBox.shrink();
    final activeIndex = _activeWordIndex;

    return Align(
      alignment: template.position,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Container(
          padding: template.backgroundColor != null
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              : EdgeInsets.zero,
          decoration: template.backgroundColor != null
              ? BoxDecoration(
                  color: template.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: List.generate(line.words.length, (i) {
              final visible = _isWordVisible(i, activeIndex);
              if (!visible) return const SizedBox.shrink();
              return _AnimatedWord(
                text: line.words[i].text,
                isActive: i == activeIndex,
                template: template,
              );
            }),
          ),
        ),
      ),
    );
  }

  bool _isWordVisible(int index, int activeIndex) {
    if (template.animation == CaptionAnimation.typewriter ||
        template.animation == CaptionAnimation.fadeWord) {
      return index <= activeIndex;
    }
    return true;
  }
}

class _AnimatedWord extends StatelessWidget {
  final String text;
  final bool isActive;
  final CaptionTemplate template;

  const _AnimatedWord({
    required this.text,
    required this.isActive,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: isActive && template.animation == CaptionAnimation.wordHighlight
          ? template.highlightColor
          : template.textColor,
      fontFamily: template.fontFamily,
      fontWeight: template.fontWeight,
      fontSize: 22 * template.fontSize,
      shadows: template.strokeWidth > 0
          ? [
              Shadow(
                  color: template.strokeColor,
                  offset: const Offset(-1, -1)),
              Shadow(color: template.strokeColor, offset: const Offset(1, -1)),
              Shadow(color: template.strokeColor, offset: const Offset(1, 1)),
              Shadow(color: template.strokeColor, offset: const Offset(-1, 1)),
            ]
          : null,
    );

    Widget textWidget = Text(text, style: baseStyle);

    if (isActive) {
      switch (template.animation) {
        case CaptionAnimation.popIn:
          return TweenAnimationBuilder<double>(
            key: ValueKey(text + isActive.toString()),
            tween: Tween(begin: 1.3, end: 1.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: Text(text,
                  style: baseStyle.copyWith(color: template.highlightColor)),
            ),
          );
        case CaptionAnimation.bounce:
          return TweenAnimationBuilder<double>(
            key: ValueKey(text + isActive.toString()),
            tween: Tween(begin: -6.0, end: 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.elasticOut,
            builder: (context, dy, child) => Transform.translate(
              offset: Offset(0, dy),
              child: Text(text,
                  style: baseStyle.copyWith(color: template.highlightColor)),
            ),
          );
        case CaptionAnimation.fadeWord:
          return TweenAnimationBuilder<double>(
            key: ValueKey(text + isActive.toString()),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, opacity, child) => Opacity(
              opacity: opacity,
              child: Text(text,
                  style: baseStyle.copyWith(color: template.highlightColor)),
            ),
          );
        default:
          return textWidget;
      }
    }

    return textWidget;
  }
}
