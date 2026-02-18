import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMine;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.isMine = false,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _position = position);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
      _animationController.stop();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      _animationController.stop();
    } else {
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      setState(() => _isPlaying = true);
      _animationController.repeat();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inSeconds > 0
        ? _position.inSeconds / _duration.inSeconds
        : 0.0;

    final buttonColor = widget.isMine ? Colors.white : const Color(0xFFBE1E1E);
    final waveColor =
        widget.isMine ? Colors.white.withOpacity(0.8) : const Color(0xFFBE1E1E);
    final textColor =
        widget.isMine ? Colors.white.withOpacity(0.9) : Colors.black87;

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Play/Pause circulaire style Facebook
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: buttonColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: buttonColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Forme d'onde et durée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Forme d'onde animée
                SizedBox(
                  height: 24,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WaveformPainter(
                          progress: progress,
                          isPlaying: _isPlaying,
                          animationValue: _animationController.value,
                          color: waveColor,
                        ),
                        size: const Size(double.infinity, 24),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                // Durée
                Text(
                  _isPlaying || _position.inSeconds > 0
                      ? _formatDuration(_position)
                      : _formatDuration(_duration),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painter pour la forme d'onde style Facebook Messenger
class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double animationValue;
  final Color color;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const barCount = 30;
    final barWidth = 2.5;
    final spacing = (size.width - (barCount * barWidth)) / (barCount - 1);

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      final normalizedPosition = i / barCount;

      // Hauteur variable pour simuler une forme d'onde
      final baseHeight = _getBarHeight(i, barCount);
      final animatedHeight = isPlaying
          ? baseHeight *
              (1.0 +
                  0.2 *
                      math.sin(
                        (animationValue * 2 * math.pi) + (i * 0.5),
                      ))
          : baseHeight;

      final barHeight = (size.height * animatedHeight).clamp(4.0, size.height);
      final y = (size.height - barHeight) / 2;

      // Utiliser la couleur active pour les barres déjà lues
      final barPaint = normalizedPosition <= progress ? activePaint : paint;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + barHeight),
        barPaint,
      );
    }
  }

  double _getBarHeight(int index, int total) {
    // Créer une forme d'onde variée et naturelle
    final normalized = index / total;
    final wave1 = math.sin(normalized * math.pi * 2) * 0.3;
    final wave2 = math.sin(normalized * math.pi * 4) * 0.2;
    final wave3 = math.sin(normalized * math.pi * 8) * 0.15;
    return (0.4 + wave1 + wave2 + wave3).clamp(0.2, 1.0);
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
