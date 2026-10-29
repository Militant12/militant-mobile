# Appels Audio/Vidéo - Exclusif Flutter

## Vue d'ensemble

Les appels audio et vidéo sont une fonctionnalité **exclusive à l'application mobile Militant Flutter**. La version web n'a pas accès à cette fonctionnalité.

## Architecture

### Technologie
- **WebRTC** pour la communication peer-to-peer
- **Signaling** via l'API REST Militant
- **STUN/TURN servers** pour la traversée NAT

### Sécurité
- Header `X-Flutter-App: militant-flutter-v1` requis pour tous les appels API
- L'API rejette toute requête sans ce header avec une erreur 403
- Authentification JWT standard en plus du header Flutter

## Structure de la base de données

```sql
-- Table des appels
CREATE TABLE calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(32) UNIQUE NOT NULL,
    caller_id INT NOT NULL,
    recipient_id INT NOT NULL,
    call_type ENUM('audio', 'video') NOT NULL,
    status ENUM('ringing', 'active', 'ended', 'rejected', 'missed') NOT NULL,
    offer_sdp TEXT,
    answer_sdp TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    answered_at TIMESTAMP NULL,
    ended_at TIMESTAMP NULL,
    duration INT DEFAULT 0
);

-- Table des ICE candidates
CREATE TABLE call_ice_candidates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    call_id VARCHAR(32) NOT NULL,
    user_id INT NOT NULL,
    candidate TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Préférence de confidentialité
ALTER TABLE user_preferences 
ADD COLUMN privacy_allow_calls TINYINT(1) DEFAULT 1;
```

## Flux d'appel

### 1. Initiation d'un appel

```dart
final callService = CallService(apiService: apiService);

// Appel audio
String callId = await callService.initiateAudioCall(recipientUserId);

// Appel vidéo
String callId = await callService.initiateVideoCall(recipientUserId);
```

**Côté API :**
1. Vérifie le header `X-Flutter-App`
2. Vérifie les préférences de confidentialité du destinataire
3. Crée un enregistrement d'appel avec status 'ringing'
4. Envoie une notification push au destinataire
5. Retourne le `call_id`

### 2. Réception d'un appel

Le destinataire reçoit une notification avec :
- `call_id` : identifiant unique de l'appel
- `call_type` : 'audio' ou 'video'
- Informations de l'appelant

```dart
// Répondre à l'appel
await callService.answerCall(
  callId,
  offerSdp, // SDP reçu dans la notification
  callType,
);

// Rejeter l'appel
await callService.rejectCall(callId);
```

### 3. Échange WebRTC

**ICE Candidates :**
```dart
// Les ICE candidates sont automatiquement envoyés
// via le CallService lors de la négociation WebRTC
```

**Polling :**
Le CallService poll automatiquement toutes les 2 secondes pour :
- Récupérer les nouveaux ICE candidates
- Vérifier le statut de l'appel
- Obtenir l'answer SDP (pour l'appelant)

### 4. Fin d'appel

```dart
await callService.endCall();
```

## Utilisation dans l'UI

### Exemple d'écran d'appel

```dart
class CallScreen extends StatefulWidget {
  final String callId;
  final bool isVideo;
  final bool isIncoming;
  
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late CallService _callService;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _isMuted = false;
  bool _isCameraOff = false;
  
  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupCallService();
  }
  
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  
  void _setupCallService() {
    _callService = CallService(apiService: apiService);
    
    _callService.onLocalStream = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };
    
    _callService.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
      });
    };
    
    _callService.onCallEnded = (reason) {
      Navigator.pop(context);
    };
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Vue distante (plein écran)
          RTCVideoView(_remoteRenderer, mirror: false),
          
          // Vue locale (petit coin)
          if (widget.isVideo)
            Positioned(
              top: 50,
              right: 20,
              width: 120,
              height: 160,
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
          
          // Contrôles
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton micro
                IconButton(
                  icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                  onPressed: () {
                    _callService.toggleMicrophone();
                    setState(() => _isMuted = !_isMuted);
                  },
                ),
                
                // Bouton caméra (si vidéo)
                if (widget.isVideo)
                  IconButton(
                    icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
                    onPressed: () {
                      _callService.toggleCamera();
                      setState(() => _isCameraOff = !_isCameraOff);
                    },
                  ),
                
                // Bouton raccrocher
                IconButton(
                  icon: Icon(Icons.call_end, color: Colors.red),
                  onPressed: () async {
                    await _callService.endCall();
                    Navigator.pop(context);
                  },
                ),
                
                // Bouton changer de caméra
                if (widget.isVideo)
                  IconButton(
                    icon: Icon(Icons.flip_camera_ios),
                    onPressed: () => _callService.switchCamera(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.cleanup();
    super.dispose();
  }
}
```

## Configuration des serveurs STUN/TURN

Par défaut, le CallService utilise les serveurs STUN publics de Google. Pour une meilleure fiabilité en production, configurez vos propres serveurs TURN :

```dart
final Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:votre-serveur-turn.com:3478',
      'username': 'username',
      'credential': 'password'
    },
  ]
};
```

## Permissions Android

Ajoutez dans `android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Permissions iOS

Ajoutez dans `ios/Runner/Info.plist` :

```xml
<key>NSCameraUsageDescription</key>
<string>Militant a besoin d'accéder à votre caméra pour les appels vidéo</string>
<key>NSMicrophoneUsageDescription</key>
<string>Militant a besoin d'accéder à votre microphone pour les appels</string>
```

## Migration de la base de données

Exécutez le script SQL :

```bash
mysql -u root -p militant < database/migrations/add_calls_tables.sql
```

## Préférences de confidentialité

Les utilisateurs peuvent contrôler qui peut les appeler :

```dart
// Permettre les appels de tous
await apiService.updatePreferences({'privacy_allow_calls': 1});

// Permettre uniquement les appels des personnes suivies
await apiService.updatePreferences({'privacy_allow_calls': 0});
```

## Historique des appels

```dart
final history = await apiService.getCallHistory(page: 1);

// Chaque entrée contient :
// - call_id
// - caller_username, caller_avatar
// - recipient_username, recipient_avatar
// - call_type ('audio' ou 'video')
// - status ('ended', 'rejected', 'missed')
// - direction ('incoming' ou 'outgoing')
// - created_at, answered_at, ended_at
// - duration (en secondes)
```

## Notifications push

Lorsqu'un appel est initié, une notification est envoyée au destinataire avec :

```json
{
  "type": "call",
  "call_id": "abc123...",
  "call_type": "video",
  "caller_id": 42,
  "caller_username": "militant_user",
  "caller_avatar": "avatar_123.jpg"
}
```

L'application doit gérer cette notification pour afficher l'écran d'appel entrant.

## Limitations

- Appels 1-to-1 uniquement (pas de conférence pour le moment)
- Durée maximale recommandée : 2 heures
- Qualité dépend de la connexion réseau des deux parties
- Nécessite une connexion internet stable

## Dépannage

### L'appel ne se connecte pas
- Vérifiez que les deux utilisateurs ont une connexion internet
- Vérifiez les permissions caméra/micro
- Vérifiez les logs pour les erreurs ICE candidates

### Pas de vidéo/audio
- Vérifiez les permissions de l'appareil
- Vérifiez que la caméra/micro n'est pas utilisé par une autre app
- Testez avec un appel audio d'abord

### Erreur 403 "FLUTTER_ONLY"
- Le header `X-Flutter-App` n'est pas envoyé
- Vérifiez que vous utilisez `_flutterHeaders` dans ApiService

## Roadmap

- [ ] Appels de groupe (conférence)
- [ ] Enregistrement d'appels (avec consentement)
- [ ] Partage d'écran
- [ ] Effets de fond virtuels
- [ ] Chiffrement end-to-end des appels
