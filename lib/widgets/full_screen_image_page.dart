import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/language_service.dart';
import '../services/media_download_service.dart';

class FullScreenImagePage extends StatefulWidget {
  final String imageUrl;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
  });

  @override
  State<FullScreenImagePage> createState() => _FullScreenImagePageState();
}

class _FullScreenImagePageState extends State<FullScreenImagePage> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    final result = await MediaDownloadService.saveImage(widget.imageUrl);
    if (!mounted) return;
    setState(() => _isDownloading = false);

    final lang = LanguageService.instance;
    if (result.success) {
      if (result.savedDirectly) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.translate('image_saved'))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.translate('image_download_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Zoomable image container
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  clipBehavior: Clip.none,
                  child: Hero(
                    tag: widget.imageUrl,
                    child: Image(
                      image: CachedNetworkImageProvider(widget.imageUrl),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Close button at top-left
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: SafeArea(
              child: ClipOval(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    tooltip: lang.translate('a11y_back'),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
          // Download button at top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: SafeArea(
              child: ClipOval(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    tooltip: lang.translate('download_image'),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, color: Colors.white),
                    onPressed: _isDownloading ? null : _downloadImage,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
