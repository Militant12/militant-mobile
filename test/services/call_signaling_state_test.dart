import 'package:flutter_test/flutter_test.dart';
import 'package:militant/services/call_signaling_state.dart';

void main() {
  group('normalizeRemoteSdp', () {
    test('rejette null, vide, "null" et "undefined"', () {
      expect(normalizeRemoteSdp(null), '');
      expect(normalizeRemoteSdp(''), '');
      expect(normalizeRemoteSdp('   '), '');
      expect(normalizeRemoteSdp('null'), '');
      expect(normalizeRemoteSdp('undefined'), '');
    });

    test('ajoute une fin de ligne CRLF si elle manque', () {
      expect(normalizeRemoteSdp('v=0'), 'v=0\r\n');
    });

    test('ne modifie pas un SDP déjà terminé par un saut de ligne', () {
      expect(normalizeRemoteSdp('v=0\r\n'), 'v=0\r\n');
      expect(normalizeRemoteSdp('v=0\n'), 'v=0\n');
    });
  });

  group('sameNormalizedSdp', () {
    test('compare après normalisation', () {
      expect(sameNormalizedSdp('v=0', 'v=0\r\n'), isTrue);
      expect(sameNormalizedSdp('v=0', 'v=1'), isFalse);
    });

    test('jamais identique si un des deux SDP est vide ou invalide', () {
      expect(sameNormalizedSdp(null, null), isFalse);
      expect(sameNormalizedSdp('', ''), isFalse);
      expect(sameNormalizedSdp('v=0', null), isFalse);
      expect(sameNormalizedSdp('undefined', 'undefined'), isFalse);
    });
  });

  group('AnswerSdpTracker', () {
    test('ignore une réponse vide', () {
      expect(AnswerSdpTracker().shouldSkip(''), isTrue);
    });

    test('accepte une première réponse puis ignore sa répétition', () {
      final tracker = AnswerSdpTracker();
      expect(tracker.shouldSkip('answer-1'), isFalse);
      tracker.markApplied('answer-1');
      expect(tracker.shouldSkip('answer-1'), isTrue);
    });

    test('accepte une réponse différente après la première', () {
      final tracker = AnswerSdpTracker()..markApplied('answer-1');
      expect(tracker.shouldSkip('answer-2'), isFalse);
    });

    test('après un redémarrage ICE, l\'ancienne réponse reste ignorée', () {
      final tracker = AnswerSdpTracker()..markApplied('answer-1');
      tracker.beginIceRestart();

      expect(tracker.applied, isNull);
      expect(tracker.shouldSkip('answer-1'), isTrue);
    });

    test('après un redémarrage ICE, la nouvelle réponse est acceptée', () {
      final tracker = AnswerSdpTracker()..markApplied('answer-1');
      tracker.beginIceRestart();

      expect(tracker.shouldSkip('answer-2'), isFalse);
      tracker.markApplied('answer-2');
      expect(tracker.shouldSkip('answer-2'), isTrue);
    });

    test('deux redémarrages ICE de suite gardent la mémoire de l\'ancienne '
        'réponse', () {
      final tracker = AnswerSdpTracker()..markApplied('answer-1');
      tracker.beginIceRestart();
      tracker.beginIceRestart();

      expect(tracker.previousBeforeRestart, 'answer-1');
      expect(tracker.shouldSkip('answer-1'), isTrue);
      expect(tracker.shouldSkip('answer-2'), isFalse);
    });

    test('un redémarrage sans réponse appliquée ne plante pas', () {
      final tracker = AnswerSdpTracker();
      tracker.beginIceRestart();

      expect(tracker.previousBeforeRestart, isNull);
      expect(tracker.shouldSkip('answer-1'), isFalse);
    });

    test(
      'clearCurrent oublie la réponse courante sans toucher à l\'ancienne',
      () {
        final tracker = AnswerSdpTracker()..markApplied('answer-1');
        tracker.beginIceRestart();
        tracker.markApplied('answer-2');
        tracker.clearCurrent();

        expect(tracker.applied, isNull);
        expect(tracker.previousBeforeRestart, 'answer-1');
      },
    );

    test('reset remet tout à zéro entre deux appels', () {
      final tracker = AnswerSdpTracker()..markApplied('answer-1');
      tracker.beginIceRestart();
      tracker.reset();

      expect(tracker.applied, isNull);
      expect(tracker.previousBeforeRestart, isNull);
      expect(tracker.shouldSkip('answer-1'), isFalse);
    });
  });

  group('MediaStallDetector', () {
    bool record(
      MediaStallDetector detector,
      int bytes, {
      bool canJudge = true,
      bool restarting = false,
    }) {
      return detector.record(
        totalInboundBytes: bytes,
        canJudge: canJudge,
        isRestartingIce: restarting,
      );
    }

    test('ne redémarre pas tant que les octets entrants augmentent', () {
      final detector = MediaStallDetector();
      for (var bytes = 1000; bytes <= 20000; bytes += 1000) {
        expect(record(detector, bytes), isFalse);
      }
      expect(detector.stalledPolls, 0);
    });

    test('redémarre après 6 relevés sans nouvelle donnée', () {
      final detector = MediaStallDetector();
      record(detector, 5000);

      for (var i = 1; i <= 5; i++) {
        expect(record(detector, 5000), isFalse, reason: 'relevé $i');
      }
      expect(record(detector, 5000), isTrue);
    });

    test('un relevé avec données remet le compteur à zéro', () {
      final detector = MediaStallDetector();
      record(detector, 5000);
      for (var i = 0; i < 4; i++) {
        record(detector, 5000);
      }
      expect(detector.stalledPolls, 4);

      record(detector, 6000);
      expect(detector.stalledPolls, 0);
    });

    test('compte les relevés à zéro octet quand le flux est jugeable', () {
      final detector = MediaStallDetector();
      var restart = false;
      for (var i = 0; i < 6; i++) {
        restart = record(detector, 0);
      }
      expect(restart, isTrue);
    });

    test('ne compte rien tant que le flux n\'est pas jugeable', () {
      final detector = MediaStallDetector();
      for (var i = 0; i < 20; i++) {
        expect(record(detector, 0, canJudge: false), isFalse);
      }
      expect(detector.stalledPolls, 0);
    });

    test('ne redémarre pas si un redémarrage ICE est déjà en cours', () {
      final detector = MediaStallDetector();
      record(detector, 5000);
      for (var i = 0; i < 10; i++) {
        expect(record(detector, 5000, restarting: true), isFalse);
      }
    });

    test('reset remet le détecteur à zéro entre deux appels', () {
      final detector = MediaStallDetector();
      record(detector, 5000);
      for (var i = 0; i < 5; i++) {
        record(detector, 5000);
      }
      detector.reset();

      expect(detector.stalledPolls, 0);
      expect(record(detector, 100), isFalse);
    });
  });
}
