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
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        _waveController.stop();
        _waveController.reset();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
      _waveController.stop();
    } else {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
        if (mounted) setState(() => _isPlaying = true);
        _waveController.repeat();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seekTo(double value) async {
    final target = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    await _audioPlayer.seek(target);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final accentColor = widget.isMine ? Colors.white : const Color(0xFFBE1E1E);
    final dimColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.grey.shade400;
    final timeColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.75)
        : Colors.grey.shade600;

    return SizedBox(
      width: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Bouton Play / Pause ──────────────────────────────
          GestureDetector(
            onTap: _togglePlayPause,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor, width: 1.5),
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: accentColor,
                      size: 22,
                    ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Forme d'onde + slider + durée ───────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Forme d'onde animée
                SizedBox(
                  height: 28,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) => CustomPaint(
                      painter: _VoiceWavePainter(
                        progress: progress,
                        isPlaying: _isPlaying,
                        animValue: _waveController.value,
                        activeColor: accentColor,
                        inactiveColor: dimColor,
                      ),
                      size: const Size(double.infinity, 28),
                    ),
                  ),
                ),

                // Slider de progression
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: dimColor,
                    thumbColor: accentColor,
                    overlayColor: accentColor.withValues(alpha: 0.15),
                  ),
                  child: SizedBox(
                    height: 18,
                    child: Slider(
                      value: progress,
                      onChanged: _seekTo,
                    ),
                  ),
                ),

                // Durée
                Text(
                  _isPlaying || _position > Duration.zero
                      ? _formatDuration(_position)
                      : _formatDuration(_duration),
                  style: TextStyle(
                    color: timeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // ── Icône micro (badge vocal) ────────────────────────
          Icon(
            Icons.mic_rounded,
            size: 16,
            color: dimColor,
          ),
        ],
      ),
    );
  }
}

// ── Painter forme d'onde style Signal ──────────────────────────────────────
class _VoiceWavePainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final double animValue;
  final Color activeColor;
  final Color inactiveColor;

  _VoiceWavePainter({
    required this.progress,
    required this.isPlaying,
    required this.animValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  // Forme d'onde fixe réaliste (simulée)
  static const List<double> _wave = [
    0.30, 0.45, 0.55, 0.70, 0.60, 0.80, 0.95, 0.85, 0.70, 0.60,
    0.50, 0.65, 0.80, 0.90, 1.00, 0.88, 0.72, 0.58, 0.45, 0.60,
    0.75, 0.85, 0.70, 0.55, 0.40, 0.50, 0.65, 0.48, 0.35, 0.28,
    0.40, 0.55, 0.60, 0.45, 0.30, 0.40, 0.55, 0.42, 0.28, 0.20,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 40;
    const barW = 2.5;
    const gap = 1.5;
    final totalW = barCount * barW + (barCount - 1) * gap;
    final startX = (size.width - totalW) / 2;
    final midY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final norm = i / barCount;
      final isActive = norm <= progress;

      double h = _wave[i % _wave.length] * (size.height * 0.85);

      // Animation légère sur les barres actives lors de la lecture
      if (isPlaying && isActive) {
        h *= 1.0 + 0.15 * math.sin(animValue * 2 * math.pi + i * 0.6);
      }
      h = h.clamp(3.0, size.height);

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..strokeWidth = barW
        ..strokeCap = StrokeCap.round;

      final x = startX + i * (barW + gap) + barW / 2;
      canvas.drawLine(
        Offset(x, midY - h / 2),
        Offset(x, midY + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavePainter old) =>
      old.progress != progress ||
      old.isPlaying != isPlaying ||
      old.animValue != animValue;
}
