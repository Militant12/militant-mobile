import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';

class CallScreen extends StatefulWidget {
  final String? callId;
  final int? recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final bool isVideo;
  final bool isIncoming;
  final String? offerSdp;

  const CallScreen({
    super.key,
    this.callId,
    this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.isVideo,
    required this.isIncoming,
    this.offerSdp,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallService _callService;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isConnected = false;
  bool _isRinging = true;
  String _callStatus = '';

  @override
  void initState() {
    super.initState();
    _callStatus = LanguageService.instance.translate('call_connecting');
    _initRenderers();
    _setupCallService();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupCallService() async {
    try {
      final apiService = await ApiService.getInstance();
      _callService = CallService(apiService: apiService);

      _callService.onLocalStream = (stream) {
        if (mounted) {
          setState(() {
            _localRenderer.srcObject = stream;
          });
        }
      };

      _callService.onRemoteStream = (stream) {
        if (mounted) {
          setState(() {
            _remoteRenderer.srcObject = stream;
            _isConnected = true;
            _isRinging = false;
            _callStatus = LanguageService.instance.translate('call_active');
          });
        }
      };

      _callService.onCallEnded = (reason) async {
        if (!mounted) return;
        // Annuler les vidéos locales proprement
        setState(() {
          _isConnected = false;
          _callStatus = '📵 Appel terminé';
        });
        // Attendre 2s pour que l'utilisateur voie le message
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      };

      _callService.onCallRejected = (reason) async {
        if (!mounted) return;
        setState(() => _callStatus = '❌ Appel refusé');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.instance.translate('call_rejected')),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      };

      _callService.onNetworkChange = (message) {
        if (mounted) {
          setState(
            () => _callStatus = LanguageService.instance.translate(
              'call_network_reconnecting',
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), duration: Duration(seconds: 2)),
          );
        }
      };

      // Initier ou répondre à l'appel
      if (widget.isIncoming && widget.callId != null) {
        if (mounted) {
          setState(
            () => _callStatus = LanguageService.instance.translate(
              'call_connecting',
            ),
          );
        }

        String remoteSdp = widget.offerSdp ?? '';

        // Si le SDP n'est pas fourni (cas CallKit), on le récupère via l'API
        if (remoteSdp.isEmpty) {
          try {
            final callInfo = await apiService.getCallInfo(widget.callId!);
            remoteSdp = callInfo['offer_sdp'] ?? '';
          } catch (e) {
            print('Erreur récupération infos appel: $e');
            if (mounted) Navigator.pop(context);
            return;
          }
        }

        if (remoteSdp.isNotEmpty) {
          await _callService.answerCall(
            widget.callId!,
            remoteSdp,
            widget.isVideo ? 'video' : 'audio',
          );
        }
      } else if (!widget.isIncoming && widget.recipientId != null) {
        if (mounted) {
          setState(
            () => _callStatus = LanguageService.instance.translate(
              'call_ringing',
            ),
          );
        }
        if (widget.isVideo) {
          await _callService.initiateVideoCall(widget.recipientId!);
        } else {
          await _callService.initiateAudioCall(widget.recipientId!);
        }
      }
    } catch (e) {
      print('Erreur lors de la configuration de l\'appel: $e');
      if (mounted) {
        String errorMessage = e.toString().replaceAll('Exception: ', '');

        // Messages d'erreur plus clairs
        if (errorMessage.contains('Permission') ||
            errorMessage.contains('permission')) {
          errorMessage =
              'Permission refusée. Veuillez autoriser l\'accès au microphone et à la caméra.';
        } else if (errorMessage.contains('NotFoundError') ||
            errorMessage.contains('not found')) {
          errorMessage = 'Aucun microphone ou caméra trouvé sur cet appareil.';
        } else if (errorMessage.contains('NotAllowedError')) {
          errorMessage =
              'Accès refusé. Veuillez autoriser les permissions dans les paramètres.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );

        // Attendre un peu avant de fermer pour que l'utilisateur puisse lire le message
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Vue distante (plein écran)
            if (_isConnected && widget.isVideo)
              Positioned.fill(
                child: RTCVideoView(_remoteRenderer, mirror: false),
              )
            else
              _buildWaitingView(),

            // Vue locale (petit coin)
            if (widget.isVideo && _localRenderer.srcObject != null)
              Positioned(
                top: 50,
                right: 20,
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),

            // Informations en haut
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _callStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Contrôles en bas
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Bouton micro
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: () {
                      _callService.toggleMicrophone();
                      setState(() => _isMuted = !_isMuted);
                    },
                    color: _isMuted ? Colors.red : Colors.white,
                  ),

                  // Bouton caméra (si vidéo)
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: () {
                        _callService.toggleCamera();
                        setState(() => _isCameraOff = !_isCameraOff);
                      },
                      color: _isCameraOff ? Colors.red : Colors.white,
                    ),

                  // Bouton raccrocher
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: () async {
                      await _callService.endCall();
                      if (mounted) Navigator.pop(context);
                    },
                    color: Colors.white,
                    backgroundColor: Colors.red,
                  ),

                  // Bouton changer de caméra
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () => _callService.switchCamera(),
                      color: Colors.white,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.recipientAvatar != null)
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(widget.recipientAvatar!),
            )
          else
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFBE1E1E),
              child: Text(
                widget.recipientName.isNotEmpty
                    ? widget.recipientName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 40),
          if (_isRinging) const CircularProgressIndicator(color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white24,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 32,
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    // Nettoyer le service d'appel de manière asynchrone
    _callService.cleanup().catchError((e) {
      print('Erreur lors du nettoyage du service d\'appel: $e');
    });
    super.dispose();
  }
}
