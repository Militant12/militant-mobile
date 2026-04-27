import 'package:flutter/material.dart';

class SignalTypingIndicator extends StatefulWidget {
  const SignalTypingIndicator({
    super.key,
    required this.text,
    this.compact = false,
  });

  final String text;
  final bool compact;

  @override
  State<SignalTypingIndicator> createState() => _SignalTypingIndicatorState();
}

class _SignalTypingIndicatorState extends State<SignalTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.72,
    );
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.45);
    final textColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, widget.compact ? 4 : 8, 20, 0),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDots(controller: _controller, color: textColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({
    required this.controller,
    required this.color,
  });

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (controller.value - (index * 0.18)) % 1.0;
            final normalized = phase < 0 ? phase + 1.0 : phase;
            final scale = 0.72 + ((_triangle(normalized)) * 0.38);
            final opacity = 0.35 + ((_triangle(normalized)) * 0.65);

            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 4),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _triangle(double value) {
    if (value < 0.5) return value * 2;
    return (1 - value) * 2;
  }
}
