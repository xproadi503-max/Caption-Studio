import 'package:flutter/material.dart';
import '../models/caption_word.dart';
import '../models/caption_style.dart';

/// Renders the currently-active caption line on top of the video
/// preview, matching (approximately) how the same line + template will
/// look once burned into the exported video via the ASS generator.
/// This is a live Flutter re-implementation of the animation styles
/// (not a literal ASS renderer), so it stays smooth during scrubbing.
///
/// When [onPositionChanged] is provided, the caption becomes draggable:
/// the user can drag it anywhere over the video and the new fractional
/// position (0.0-1.0 for both axes) is reported back, letting the
/// editor screen store a per-line custom position (Zeemo-style manual
/// caption placement).
class CaptionPreviewOverlay extends StatelessWidget {
  final List<CaptionLine> lines;
  final int positionMs;
  final CaptionTemplate template;
  final Offset? positionOverride; // fractional 0-1, null = use template default
  final ValueChanged<Offset>? onPositionChanged;

  const CaptionPreviewOverlay({
    super.key,
    required this.lines,
    required this.positionMs,
    required this.template,
    this.positionOverride,
    this.onPositionChanged,
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

    final captionContent = Padding(
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        Widget positioned;
        if (positionOverride != null) {
          positioned = Positioned(
            left: (positionOverride!.dx * width) - (width * 0.4),
            top: (positionOverride!.dy * height) - 24,
            width: width * 0.8,
            child: captionContent,
          );
        } else {
          positioned = Positioned.fill(
            child: Align(alignment: template.position, child: captionContent),
          );
        }

        if (onPositionChanged == null) {
          return Stack(children: [positioned]);
        }

        // Draggable mode: wrap in a gesture detector covering the caption
        // area so the user can grab and reposition it anywhere on screen.
        return Stack(
          children: [
            Positioned(
              left: positionOverride != null
                  ? (positionOverride!.dx * width) - (width * 0.4)
                  : null,
              top: positionOverride != null
                  ? (positionOverride!.dy * height) - 24
                  : null,
              width: width * 0.8,
              child: positionOverride == null
                  ? Align(alignment: template.position, child: _wrapDraggable(captionContent, width, height))
                  : _wrapDraggable(captionContent, width, height),
            ),
          ],
        );
      },
    );
  }

  Widget _wrapDraggable(Widget child, double width, double height) {
    return GestureDetector(
      onPanUpdate: (details) {
        final dx = ((positionOverride?.dx ?? 0.5) * width + details.delta.dx) / width;
        final dy = ((positionOverride?.dy ?? 0.8) * height + details.delta.dy) / height;
        onPositionChanged?.call(Offset(dx.clamp(0.05, 0.95), dy.clamp(0.05, 0.95)));
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
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
