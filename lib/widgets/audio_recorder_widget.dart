import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/error_helper.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(File audioFile) onRecordingComplete;
  final VoidCallback onCancel;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Vérifier si le microphone est disponible (demande auto la permission sur mobile, et renvoie true sur Linux)
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
        });

        // Mettre à jour la durée toutes les secondes
        _updateDuration();
      }
    } catch (e) {
      print('Erreur enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
        widget.onCancel();
      }
    }
  }

  void _updateDuration() {
    if (!_isRecording || _startTime == null) return;

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isRecording) {
        setState(() {
          _recordDuration = DateTime.now().difference(_startTime!);
        });
        _updateDuration();
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        final file = File(path);
        widget.onRecordingComplete(file);
      }
    } catch (e) {
      print('Erreur arrêt enregistrement: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getFriendlyErrorMessage(e))));
      }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: LanguageService.instance.translate('a11y_cancel_recording'),
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              await _audioRecorder.stop();
              widget.onCancel();
            },
          ),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.militantRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTokens.fontBodyLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: LanguageService.instance.translate('send'),
            icon: const Icon(Icons.send, color: AppColors.militantRed),
            onPressed: _stopRecording,
          ),
        ],
      ),
    );
  }
}
