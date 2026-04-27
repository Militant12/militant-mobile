import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/private_call_session.dart';

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
  final PrivateCallSession _callSession = PrivateCallSession.instance;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isConnected = false;
  bool _isRinging = true;
  String _callStatus = '';
  String? _resolvedRecipientAvatar;
  PrivateCallTerminalState _lastHandledTerminalState =
      PrivateCallTerminalState.none;

  @override
  void initState() {
    super.initState();
    _callStatus = LanguageService.instance.translate('call_connecting');
    unawaited(_resolveRecipientAvatar());
    _setupSession();
  }

  Future<void> _resolveRecipientAvatar() async {
    final avatar = widget.recipientAvatar?.trim();
    if (avatar == null || avatar.isEmpty) return;

    try {
      final api = await ApiService.getInstance();
      final resolved =
          api.getImageUrl(avatar) ??
          ApiService.resolveImageUrl(avatar) ??
          avatar;
      if (!mounted) return;
      setState(() {
        _resolvedRecipientAvatar = resolved;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvedRecipientAvatar =
            ApiService.resolveImageUrl(avatar) ?? avatar;
      });
    }
  }

  Future<void> _setupSession() async {
    debugPrint(
      '[WebRTC][private][screen] setup incoming=${widget.isIncoming} callId=${widget.callId} recipientId=${widget.recipientId} video=${widget.isVideo}',
    );
    if (widget.isVideo) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    }
    if (!mounted) return;

    _callSession.addListener(_handleSessionChanged);

    await _callSession.configure(
      callId: widget.callId,
      recipientId: widget.recipientId,
      recipientName: widget.recipientName,
      recipientAvatar: widget.recipientAvatar,
      isVideo: widget.isVideo,
      isIncoming: widget.isIncoming,
      offerSdp: widget.offerSdp,
    );
    if (!mounted) return;

    _handleSessionChanged();
    await _callSession.ensureStarted();
  }

  void _handleSessionChanged() {
    if (!mounted) return;

    setState(() {
      if (widget.isVideo) {
        _localRenderer.srcObject = _callSession.localStream;
        _remoteRenderer.srcObject = _callSession.remoteStream;
      }
      _isMuted = _callSession.isMuted;
      _isCameraOff = _callSession.isCameraOff;
      _isConnected = _callSession.isConnected;
      _isRinging = _callSession.isRinging;
      _callStatus = _callSession.callStatus;
    });

    if (_callSession.terminalState != PrivateCallTerminalState.none &&
        _callSession.terminalState != _lastHandledTerminalState) {
      _lastHandledTerminalState = _callSession.terminalState;
      unawaited(_handleTerminalState(_callSession.terminalState));
    }
  }

  Future<void> _handleTerminalState(PrivateCallTerminalState state) async {
    if (!mounted) return;

    switch (state) {
      case PrivateCallTerminalState.localEnded:
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        return;
      case PrivateCallTerminalState.remoteEnded:
        await Future.delayed(const Duration(seconds: 2));
        break;
      case PrivateCallTerminalState.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService.instance.translate('call_rejected')),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        break;
      case PrivateCallTerminalState.error:
        final message =
            _callSession.errorMessage ??
            LanguageService.instance.translate('call_ended');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        break;
      case PrivateCallTerminalState.none:
        return;
    }

    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
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
                      _callSession.toggleMicrophone();
                    },
                    color: _isMuted ? Colors.red : Colors.white,
                  ),

                  // Bouton caméra (si vidéo)
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onPressed: () {
                        _callSession.toggleCamera();
                      },
                      color: _isCameraOff ? Colors.red : Colors.white,
                    ),

                  // Bouton raccrocher
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: () async {
                      debugPrint(
                        '[WebRTC][private][screen] hangup button pressed callId=${_callSession.callId}',
                      );
                      await _callSession.endCall();
                    },
                    color: Colors.white,
                    backgroundColor: Colors.red,
                  ),

                  // Bouton changer de caméra
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.flip_camera_ios,
                      onPressed: () => _callSession.switchCamera(),
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
          if (_resolvedRecipientAvatar != null)
            CircleAvatar(
              radius: 60,
              backgroundImage: NetworkImage(_resolvedRecipientAvatar!),
            )
          else
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFFBE1E1E),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: SvgPicture.asset(
                  'assets/logo.svg',
                  fit: BoxFit.contain,
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
    debugPrint(
      '[WebRTC][private][screen] dispose callId=${_callSession.callId} terminal=${_callSession.terminalState}',
    );
    _callSession.removeListener(_handleSessionChanged);
    if (widget.isVideo) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }
}
