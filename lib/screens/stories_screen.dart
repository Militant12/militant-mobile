import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';

class StoriesScreen extends StatefulWidget {
  final List<dynamic> stories;
  final int initialIndex;

  const StoriesScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _timer;
  final int _durationSeconds = 5;
  VideoPlayerController? _currentVideoController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _currentVideoController?.dispose();
    super.dispose();
  }

  bool _isVideo(String? media) {
    if (media == null || media.isEmpty) return false;
    final ext = media.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv'].contains(ext);
  }

  void _startTimer() {
    _timer?.cancel();

    // Si c'est une vidéo, on laisse le contrôleur vidéo gérer la progression
    // sauf si la vidéo n'est pas encore initialisée
    final story = widget.stories[_currentIndex];
    final media = story['media'] ?? '';

    if (_isVideo(media)) {
      // Le timer sera relancé par le StoryVideoPlayer quand la vidéo sera prête
      // ou si elle échoue
      return;
    }

    _timer = Timer(Duration(seconds: _durationSeconds), _nextStory);
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _onVideoControllerCreated(VideoPlayerController controller) {
    _currentVideoController = controller;
    // La vidéo gère elle-même l'appel à _nextStory à la fin
  }

  void _pauseStory() {
    _timer?.cancel();
    _currentVideoController?.pause();
  }

  void _resumeStory() {
    final story = widget.stories[_currentIndex];
    final media = story['media'] ?? '';

    if (_isVideo(media)) {
      _currentVideoController?.play();
    } else {
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _pauseStory(), // Pause lors de l'appui
        onTapUp: (_) => _resumeStory(), // Reprise au relâchement
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.stories.length,
          onPageChanged: (index) {
            // Nettoyer l'ancien contrôleur si nécessaire
            _currentVideoController = null;
            setState(() => _currentIndex = index);
            _startTimer();
          },
          itemBuilder: (context, index) {
            return _buildStoryView(
              widget.stories[index],
              index == _currentIndex,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoryView(dynamic story, bool isActive) {
    final username = story['username'] ?? 'Utilisateur';
    final avatar = story['avatar'];
    final media = story['media'] ?? '';
    final text = story['text'] ?? '';
    final createdAt = story['created_at'] ?? '';

    return GestureDetector(
      onTapUp: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          // Tap gauche - story précédente
          if (_currentIndex > 0) {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            Navigator.pop(context);
          }
        } else {
          // Tap droite - story suivante
          if (_currentIndex < widget.stories.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            Navigator.pop(context);
          }
        }
      },
      child: Stack(
        children: [
          // Image/Vidéo
          Center(child: _buildMediaWidget(media, isActive)),

          // Texte overlay
          if (text.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    FutureBuilder<String>(
                      future: _getAvatarUrl(avatar),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          return CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(snapshot.data!),
                            backgroundColor: const Color(0xFFBE1E1E),
                          );
                        }
                        return CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFBE1E1E),
                          child: Text(
                            username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            _formatTime(createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Progress bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: List.generate(
                    widget.stories.length,
                    (index) => Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentIndex
                              ? Colors.white
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget(String media, bool isActive) {
    if (media.isEmpty) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Color(0xFF888888)),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _getMediaUrl(media),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
          );
        }

        final url = snapshot.data!;

        if (_isVideo(media)) {
          return StoryVideoPlayer(
            url: url,
            isActive: isActive,
            onFinished: _nextStory,
            onControllerCreated: _onVideoControllerCreated,
          );
        }

        return Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1E1E1E),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                size: 64,
                color: Color(0xFF888888),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String> _getMediaUrl(String media) async {
    final api = await ApiService.getInstance();
    return api.getImageUrl(media) ?? media;
  }

  Future<String> _getAvatarUrl(String? avatar) async {
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    final api = await ApiService.getInstance();
    return api.getImageUrl(avatar) ?? avatar;
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inHours < 1) {
        return '${diff.inMinutes}min';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h';
      } else {
        return '${diff.inDays}j';
      }
    } catch (e) {
      return '';
    }
  }
}

class StoryVideoPlayer extends StatefulWidget {
  final String url;
  final bool isActive;
  final VoidCallback onFinished;
  final Function(VideoPlayerController) onControllerCreated;

  const StoryVideoPlayer({
    super.key,
    required this.url,
    required this.isActive,
    required this.onFinished,
    required this.onControllerCreated,
  });

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasCalledFinished = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(StoryVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _controller.dispose();
      _initializeVideo();
    }

    // Gérer play/pause quand la page devient active/inactive
    if (_initialized) {
      if (widget.isActive && !oldWidget.isActive) {
        _controller.play();
      } else if (!widget.isActive && oldWidget.isActive) {
        _controller.pause();
        _controller.seekTo(Duration.zero);
      }
    }
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          widget.onControllerCreated(_controller);

          if (widget.isActive) {
            _controller.play();
          }
        }
      })
      ..addListener(_checkVideoEnded);
  }

  void _checkVideoEnded() {
    if (_controller.value.isInitialized &&
        _controller.value.position >= _controller.value.duration &&
        !_hasCalledFinished) {
      _hasCalledFinished = true;
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoEnded);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFBE1E1E)),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
