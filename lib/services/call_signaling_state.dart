// Logique pure de signalisation d'appel, isolée de flutter_webrtc pour
// pouvoir être testée sans connexion réelle.

/// Normalise un SDP reçu du serveur. Retourne une chaîne vide si le SDP est
/// absent ou invalide (`null`, `undefined`, vide).
String normalizeRemoteSdp(String? sdp) {
  if (sdp == null) return '';
  final trimmed = sdp.trim();
  if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
    return '';
  }
  return sdp.endsWith('\n') ? sdp : '$sdp\r\n';
}

/// Deux SDP sont identiques après normalisation (jamais si l'un est vide).
bool sameNormalizedSdp(String? left, String? right) {
  final normalizedLeft = normalizeRemoteSdp(left);
  final normalizedRight = normalizeRemoteSdp(right);
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }
  return normalizedLeft == normalizedRight;
}

/// Suit les réponses SDP distantes déjà appliquées, y compris pendant un
/// redémarrage ICE, pour ne jamais réappliquer une ancienne réponse.
class AnswerSdpTracker {
  String? _applied;
  String? _previousBeforeRestart;

  String? get applied => _applied;
  String? get previousBeforeRestart => _previousBeforeRestart;

  /// Vrai si cette réponse (déjà normalisée) doit être ignorée.
  bool shouldSkip(String normalizedAnswer) {
    if (normalizedAnswer.isEmpty) return true;
    return _applied == normalizedAnswer ||
        _previousBeforeRestart == normalizedAnswer;
  }

  void markApplied(String normalizedAnswer) {
    _applied = normalizedAnswer;
  }

  /// Avant un redémarrage ICE : mémorise la dernière réponse connue et
  /// oublie la réponse courante. Un second redémarrage avant l'arrivée d'une
  /// nouvelle réponse conserve la mémoire de l'ancienne.
  void beginIceRestart() {
    _previousBeforeRestart = _applied ?? _previousBeforeRestart;
    _applied = null;
  }

  /// Un nouvel échange d'offre/réponse commence côté appelé.
  void clearCurrent() {
    _applied = null;
  }

  void reset() {
    _applied = null;
    _previousBeforeRestart = null;
  }
}

/// Détecte un flux média bloqué à partir des octets entrants cumulés.
class MediaStallDetector {
  MediaStallDetector({this.stalledPollsBeforeRestart = 6});

  final int stalledPollsBeforeRestart;
  int _lastInboundBytes = -1;
  int _stalledPolls = 0;

  int get stalledPolls => _stalledPolls;

  /// Enregistre un relevé de statistiques. Retourne vrai si un redémarrage
  /// ICE doit être déclenché.
  ///
  /// [canJudge] : un flux distant existe et la connexion est établie ou en
  /// négociation. Sinon le relevé n'est pas compté comme un blocage.
  bool record({
    required int totalInboundBytes,
    required bool canJudge,
    required bool isRestartingIce,
  }) {
    final mediaFlowing =
        totalInboundBytes > 0 &&
        (_lastInboundBytes < 0 || totalInboundBytes > _lastInboundBytes);

    var shouldRestart = false;
    if (mediaFlowing) {
      _stalledPolls = 0;
    } else if (canJudge) {
      _stalledPolls++;
      shouldRestart =
          _stalledPolls >= stalledPollsBeforeRestart && !isRestartingIce;
    }

    _lastInboundBytes = totalInboundBytes;
    return shouldRestart;
  }

  void reset() {
    _lastInboundBytes = -1;
    _stalledPolls = 0;
  }
}
