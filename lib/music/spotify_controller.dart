import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

/// Contrôle de Spotify via l'appli Spotify installée (App Remote SDK).
class SpotifyController extends ChangeNotifier {
  static const clientId = 'fe48c6ba2f9f4251a80ea582e97decff';
  static const redirectUrl = 'course-appli://spotify-callback';

  bool connected = false;
  bool connecting = false;
  bool paused = true;
  String? track;
  String? artist;
  String? error;
  StreamSubscription<PlayerState>? _sub;

  Future<bool> connect() async {
    if (connected) return true;
    connecting = true;
    error = null;
    notifyListeners();
    try {
      if (!await SpotifySdk.isSpotifyInstalled()) {
        error = "Installe l'appli Spotify pour contrôler ta musique.";
        return false;
      }
      connected = await SpotifySdk.connectToSpotifyRemote(clientId: clientId, redirectUrl: redirectUrl);
      if (connected) {
        _sub = SpotifySdk.subscribePlayerState().listen((s) {
          paused = s.isPaused;
          track = s.track?.name;
          artist = s.track?.artist.name;
          notifyListeners();
        }, onError: (_) {
          connected = false;
          notifyListeners();
        });
      }
      return connected;
    } catch (e) {
      error = 'Connexion à Spotify impossible : $e';
      connected = false;
      return false;
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    if (!connected && !await connect()) return;
    try {
      await f();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> playPause() => _run(() => paused ? SpotifySdk.resume() : SpotifySdk.pause());
  Future<void> play() => _run(SpotifySdk.resume);
  Future<void> pause() => _run(SpotifySdk.pause);
  Future<void> next() => _run(SpotifySdk.skipNext);
  Future<void> previous() => _run(SpotifySdk.skipPrevious);

  /// Lance une playlist (ex. "spotify:playlist:37i9dQZF1DX76t638V6CA8").
  Future<void> playUri(String uri) => _run(() => SpotifySdk.play(spotifyUri: uri));

  Future<void> disconnect() async {
    await _sub?.cancel();
    if (connected) await SpotifySdk.disconnect();
    connected = false;
    notifyListeners();
  }
}
