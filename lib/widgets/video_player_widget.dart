import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double maxHeight;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.maxHeight = 400,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    print('[VideoPlayer] Initializing with URL: ${widget.videoUrl}');

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    newController.setVolume(0);
    newController.setLooping(true);

    newController
        .initialize()
        .then((_) {
          print('[VideoPlayer] OK - Size: ${newController.value.size}');
          if (mounted) {
            setState(() {
              _controller = newController;
              _isInitialized = true;
              _hasError = false;
              _errorMessage = null;
            });
            _controller.play();
          } else {
            newController.dispose();
          }
        })
        .catchError((error) {
          print('[VideoPlayer] ERROR: $error');
          print('[VideoPlayer] URL: ${widget.videoUrl}');
          newController.dispose();

          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = error.toString();
            });
          }
        });

    _controller = newController;
    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.hasError && !_hasError && mounted) {
      print(
        '[VideoPlayer] Playback error: ${_controller.value.errorDescription}',
      );
      setState(() {
        _hasError = true;
        _errorMessage = _controller.value.errorDescription;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),

              // Play/pause button center overlay
              AnimatedOpacity(
                opacity: _showControls || !_controller.value.isPlaying
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 250),
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBE1E1E).withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // Video badge (top-left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Vidéo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom controls bar
              if (_showControls || !_controller.value.isPlaying)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Color(0xFFBE1E1E),
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        // Time + mute
                        Row(
                          children: [
                            // Current time
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: _controller,
                              builder: (context, value, _) {
                                return Text(
                                  '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Mute toggle
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFF2A2A2A),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFBE1E1E)),
              SizedBox(height: 12),
              Text(
                'Chargement de la vidéo...',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        width: double.infinity,
        color: const Color(0xFF2A2A2A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                color: Color(0xFF888888),
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Impossible de lire la vidéo',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Erreur: ${_errorMessage!.contains('unsupported') ? 'Format non supporté' : 'Erreur de lecture'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Ouvrir dans le navigateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBE1E1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
