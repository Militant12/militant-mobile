import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'full_screen_video_page.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double maxHeight;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.maxHeight = 440,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  static _VideoPlayerWidgetState? _activePlayer;

  VideoPlayerController? _controller;
  Timer? _hideControlsTimer;
  bool _isInitialized = false;
  bool _isStarted = false;
  bool _isPreparing = false;
  bool _isBuffering = false;
  bool _hasError = false;
  bool _showControls = false;
  bool _isMuted = true;
  bool _isDesktop = false;

  @override
  void initState() {
    super.initState();
    _isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    if (_isDesktop) {
      _hasError = true;
    }
  }

  void _pauseOtherPlayers() {
    if (_activePlayer != null && _activePlayer != this && _activePlayer!.mounted) {
      _activePlayer!._pauseFromExternal();
    }
    _activePlayer = this;
  }

  void _pauseFromExternal() {
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.isPlaying) {
      ctrl.pause();
      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    }
  }

  void _scheduleControlsHide() {
    _hideControlsTimer?.cancel();
    if (_controller != null && _controller!.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller != null && _controller!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _startPlayback() {
    if (_isPreparing) return;
    _pauseOtherPlayers();
    if (!_isInitialized) {
      _initializePlayer(autoPlay: true);
      return;
    }
    setState(() {
      _isStarted = true;
      _showControls = true;
    });
    _controller?.play();
    _scheduleControlsHide();
  }

  void _initializePlayer({bool autoPlay = false}) {
    if (_isPreparing || _controller != null) return;

    setState(() {
      _isPreparing = true;
      _hasError = false;
    });

    try {
      final newController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      newController.setVolume(_isMuted ? 0 : 1);
      newController.setLooping(true);

      newController
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _controller = newController;
                _isInitialized = true;
                _isPreparing = false;
                _hasError = false;
                if (autoPlay) {
                  _isStarted = true;
                  _showControls = true;
                  newController.play();
                  _scheduleControlsHide();
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
                _isPreparing = false;
                _hasError = true;
              });
            }
          });
    } catch (e) {
      debugPrint('[VideoPlayer] INIT ERROR: $e');
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    final ctrl = _controller;
    if (ctrl == null || !mounted) return;
    if (ctrl.value.hasError && !_hasError) {
      debugPrint('[VideoPlayer] Playback error: ${ctrl.value.errorDescription}');
      setState(() => _hasError = true);
      return;
    }
    if (ctrl.value.isBuffering != _isBuffering) {
      setState(() => _isBuffering = ctrl.value.isBuffering);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    if (_activePlayer == this) {
      _activePlayer = null;
    }
    final ctrl = _controller;
    if (ctrl != null) {
      ctrl.removeListener(_videoListener);
      ctrl.pause();
      ctrl.dispose();
      _controller = null;
    }
    super.dispose();
  }

  void _togglePlayPause() {
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    if (ctrl.value.isPlaying) {
      _hideControlsTimer?.cancel();
      ctrl.pause();
      setState(() => _showControls = true);
    } else {
      _pauseOtherPlayers();
      ctrl.play();
      setState(() {
        _isStarted = true;
        _showControls = true;
      });
      _scheduleControlsHide();
    }
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() {
      _isMuted = !_isMuted;
      ctrl.setVolume(_isMuted ? 0 : 1);
    });
    _scheduleControlsHide();
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
    final ctrl = _controller;
    if (ctrl == null || !_isInitialized) return;
    _hideControlsTimer?.cancel();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPage(controller: ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    if (!_isInitialized) {
      return _buildPreviewCard(isLoading: _isPreparing);
    }

    final ctrl = _controller!;
    final rawRatio = ctrl.value.aspectRatio;
    final safeRatio = (rawRatio.isFinite && rawRatio > 0)
        ? rawRatio.clamp(0.6, 2.0)
        : 16 / 9;
    final isPlaying = ctrl.value.isPlaying;
    final controlsVisible = !_isStarted || !isPlaying || _showControls;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0E),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_isStarted) {
                _startPlayback();
              } else {
                setState(() => _showControls = !_showControls);
                if (_showControls) _scheduleControlsHide();
              }
            },
            onDoubleTap: _enterFullScreen,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: safeRatio,
                    child: VideoPlayer(ctrl),
                  ),
                ),
                if (_isBuffering && isPlaying)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                if (!_isStarted || !isPlaying)
                  AnimatedOpacity(
                    opacity: controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Semantics(
                      button: true,
                      label: LanguageService.instance.translate('a11y_play'),
                      child: GestureDetector(
                        onTap: _isStarted ? _togglePlayPause : _startPlayback,
                        child: _PlayCircleButton(
                          icon: Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ),
                // Bouton son discret permanent pendant la lecture (style X / Facebook)
                if (_isStarted && !controlsVisible)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: GestureDetector(
                      onTap: _toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                if (_isStarted && controlsVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VideoProgressIndicator(
                            ctrl,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.militantRed,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white12,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _togglePlayPause,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: ctrl,
                                builder: (context, value, _) {
                                  return Text(
                                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: AppTokens.fontLabelSmall,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              Semantics(
                                button: true,
                                label: LanguageService.instance.translate(
                                  _isMuted ? 'a11y_unmute' : 'a11y_mute',
                                ),
                                child: GestureDetector(
                                  onTap: _toggleMute,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                button: true,
                                label: LanguageService.instance.translate('a11y_fullscreen'),
                                child: GestureDetector(
                                  onTap: _enterFullScreen,
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.fullscreen_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
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

  Widget _buildPreviewCard({required bool isLoading}) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: GestureDetector(
          onTap: isLoading ? null : _startPlayback,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C0C0E),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: _VideoThumbnailBackground(
                        thumbnailUrl: widget.thumbnailUrl,
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    else
                      const _PlayCircleButton(icon: Icons.play_arrow_rounded),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VIDÉO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
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
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: LanguageService.instance.translate('a11y_open_in_browser'),
                  onPressed: _openInBrowser,
                  icon: const Icon(
                    Icons.video_library_outlined,
                    color: AppColors.militantRed,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LanguageService.instance.translate('video_preview_unavailable'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: AppTokens.fontBodyMedium,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: Text(LanguageService.instance.translate('video_open')),
                  style: TextButton.styleFrom(foregroundColor: AppColors.militantRed),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayCircleButton extends StatelessWidget {
  final IconData icon;

  const _PlayCircleButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}

class _VideoThumbnailBackground extends StatelessWidget {
  final String? thumbnailUrl;

  const _VideoThumbnailBackground({this.thumbnailUrl});

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl == null || thumbnailUrl!.trim().isEmpty) {
      return _buildFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: CachedNetworkImageProvider(thumbnailUrl!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D1D22),
            Color(0xFF0E0E11),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.04),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.25),
            ],
          ),
        ),
      ),
    );
  }
}
