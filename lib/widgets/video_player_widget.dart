import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'full_screen_video_page.dart';

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
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isStarted = false; // Flag to know if the video is actually PLAYING (not just thumbnailed)
  bool _hasError = false;
  bool _showControls = true;
  bool _isMuted = true;
  bool _isDesktop = false;

  @override
  void initState() {
    super.initState();
    _isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    if (_isDesktop) {
      _hasError = true;
    } else {
      // AUTO-THUMBNAIL: Start initialization immediately but stay PAUSED
      _initializePlayer(autoPlay: false);
    }
  }

  void _startPlayback() {
    if (!_isInitialized) {
      _initializePlayer(autoPlay: true);
      return;
    }
    setState(() {
      _isStarted = true;
      _controller?.play();
      _showControls = false; // Hide controls when starting play
    });
  }

  void _initializePlayer({bool autoPlay = false}) {
    debugPrint('[VideoPlayer] Initializing thumbnail for: ${widget.videoUrl}');

    try {
      final newController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      newController.setVolume(0);
      newController.setLooping(true);

      newController
          .initialize()
          .then((_) {
            debugPrint('[VideoPlayer] Thumb Ready - Size: ${newController.value.size}');
            if (mounted) {
              setState(() {
                _controller = newController;
                _isInitialized = true;
                _hasError = false;
                if (autoPlay) {
                  _isStarted = true;
                  newController.play();
                }
              });
              newController.addListener(_videoListener);
            } else {
              newController.dispose();
            }
          })
          .catchError((error) {
            debugPrint('[VideoPlayer] ERROR: $error');
            try {
              newController.dispose();
            } catch (_) {}

            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          });
    } catch (e) {
      debugPrint('[VideoPlayer] INIT ERROR: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.hasError && !_hasError && mounted) {
      debugPrint('[VideoPlayer] Playback error: ${ctrl.value.errorDescription}');
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    final ctrl = _controller;
    // VERY IMPORTANT: Release immediately to avoid EGL_BAD_ALLOC in next items
    if (ctrl != null) {
      ctrl.removeListener(_videoListener);
      ctrl.pause();
      ctrl.dispose();
      _controller = null;
    }
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isStarted = false;
      } else {
        _controller!.play();
        _isStarted = true;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 1);
    });
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.videoUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  void _enterFullScreen() {
    if (_controller == null || !_isInitialized) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPage(
          controller: _controller!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildLoadingWidget();
    }

    return RepaintBoundary( // Optimization for scrolling
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: GestureDetector(
            onTap: () {
              if (!_isStarted) {
                _startPlayback();
              } else {
                setState(() => _showControls = !_showControls);
              }
            },
            onDoubleTap: _enterFullScreen,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video (Displays first frame when paused = THUMBNAIL)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),

                // Overlay when not started (Play Icon)
                if (!_isStarted)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black26,
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBE1E1E).withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),

                // Video badge (top-left) - Always show it looks professional
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'VIDÉO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Play/pause button center overlay (when started)
                if (_isStarted && (_showControls || !_controller!.value.isPlaying))
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 250),
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBE1E1E).withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _controller!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),

                // Bottom controls bar
                if (_isStarted && (_showControls || !_controller!.value.isPlaying))
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
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFBE1E1E),
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          Row(
                            children: [
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: _controller!,
                                builder: (context, value, _) {
                                  return Text(
                                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _toggleMute,
                                child: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _enterFullScreen,
                                child: const Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: 24,
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
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xFF111111),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFBE1E1E),
                strokeWidth: 2,
              ),
              SizedBox(height: 16),
              Text(
                'Préparation de l\'aperçu...',
                style: TextStyle(color: Colors.white38, fontSize: 12),
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
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _openInBrowser,
                icon: const Icon(
                  Icons.video_library_outlined,
                  color: Color(0xFFBE1E1E),
                  size: 40,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aperçu indisponible',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Voir la vidéo'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFBE1E1E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
