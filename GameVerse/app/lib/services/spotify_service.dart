import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spotify_web_player.dart';

class SpotifyPlayback {
  const SpotifyPlayback({
    required this.title,
    required this.artist,
    required this.isPlaying,
    this.artworkUrl,
    this.positionMs,
    this.durationMs,
  });

  final String title;
  final String artist;
  final String? artworkUrl;
  final bool isPlaying;
  final int? positionMs;
  final int? durationMs;

  SpotifyPlayback copyWith({bool? isPlaying}) => SpotifyPlayback(
    title: title,
    artist: artist,
    artworkUrl: artworkUrl,
    isPlaying: isPlaying ?? this.isPlaying,
    positionMs: positionMs,
    durationMs: durationMs,
  );
}

class SpotifyTrackResult {
  const SpotifyTrackResult({
    required this.title,
    required this.artist,
    required this.uri,
    this.artworkUrl,
  });
  final String title;
  final String artist;
  final String uri;
  final String? artworkUrl;
}

/// Cliente Spotify para web usando Authorization Code con PKCE.
/// El Client ID es público por diseño; no se usa ni almacena Client Secret.
class SpotifyService extends ChangeNotifier {
  SpotifyService._();

  static final instance = SpotifyService._();

  static const _clientId = '3fc7ca94a72940ada5c8a6d83eef2fde';
  // La raíz es una ruta existente en el hosting y evita un 404 al volver de
  // Spotify en despliegues que no tengan configurado un SPA fallback.
  static const _redirectUri = 'https://nubzzz.site';
  static const _scopes = [
    'user-read-playback-state',
    'user-read-currently-playing',
    'user-modify-playback-state',
    'user-library-read',
    'streaming',
  ];
  static const _tokenKey = 'spotify_access_token';
  static const _refreshTokenKey = 'spotify_refresh_token';
  static const _expiryKey = 'spotify_token_expiry';
  static const _verifierKey = 'spotify_pkce_verifier';
  static const _stateKey = 'spotify_oauth_state';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  SpotifyPlayback? playback;
  String? errorMessage;
  bool isLoading = false;
  double volume = .75;
  String? _webDeviceId;
  final List<SpotifyTrackResult> queue = [];
  String? jamUrl;

  bool get isConnected => _accessToken != null;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    final expiry = prefs.getString(_expiryKey);
    _expiresAt = expiry == null ? null : DateTime.tryParse(expiry);

    final callback = Uri.base;
    final code = callback.queryParameters['code'];
    final receivedState = callback.queryParameters['state'];
    if (code != null) {
      final expectedState = prefs.getString(_stateKey);
      if (receivedState == null || receivedState != expectedState) {
        errorMessage = 'No se pudo validar la conexión con Spotify.';
      } else {
        await _exchangeCode(code, prefs);
      }
    }
    if (isConnected) {
      await _startWebPlayback();
      await refreshPlayback();
    }
    notifyListeners();
  }

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(32);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    await prefs.setString(_verifierKey, verifier);
    await prefs.setString(_stateKey, state);

    final authorizationUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': state,
      'scope': _scopes.join(' '),
    });
    final opened = await launchUrl(
      authorizationUrl,
      mode: LaunchMode.platformDefault,
    );
    if (!opened) {
      errorMessage = 'No se pudo abrir Spotify para conectar la cuenta.';
      notifyListeners();
    }
  }

  Future<void> openSpotify() async {
    await launchUrl(
      Uri.parse('https://open.spotify.com/'),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<bool> setJamUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      errorMessage = 'Pega un enlace HTTPS válido.';
      notifyListeners();
      return false;
    }
    jamUrl = uri.toString();
    notifyListeners();
    return true;
  }

  Future<void> openJam() async {
    if (jamUrl == null) return;
    await launchUrl(Uri.parse(jamUrl!), mode: LaunchMode.platformDefault);
  }

  Future<void> previous() => _sendPlayerCommand('previous');
  Future<void> next() async {
    if (queue.isNotEmpty) {
      final nextTrack = queue.removeAt(0);
      notifyListeners();
      await playTrack(nextTrack);
      return;
    }
    await _playRandomLikedTrack();
  }

  Future<void> playRandomLikedTrack() => _playRandomLikedTrack();

  Future<void> addToQueue(SpotifyTrackResult track) async {
    if (!await _ensureToken()) return;
    // Reflejar la acción al instante; Spotify puede tardar unos segundos en
    // confirmar la cola del dispositivo web.
    queue.add(track);
    notifyListeners();
    if (_webDeviceId == null) return;
    final response = await http.post(
      Uri.parse(
        'https://api.spotify.com/v1/me/player/queue?device_id=$_webDeviceId&uri=${Uri.encodeComponent(track.uri)}',
      ),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    if (response.statusCode != 204) {
      await _handleApiError(response);
    }
  }

  Future<void> setVolume(double value) async {
    if (!await _ensureToken() || _webDeviceId == null) return;
    volume = value;
    notifyListeners();
    final response = await http.put(
      Uri.parse(
        'https://api.spotify.com/v1/me/player/volume?device_id=$_webDeviceId&volume_percent=${(value * 100).round()}',
      ),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    if (response.statusCode != 204) await _handleApiError(response);
  }

  Future<List<SpotifyTrackResult>> searchTracks(String query) async {
    if (query.trim().isEmpty || !await _ensureToken()) return [];
    final response = await http.get(
      Uri.https('api.spotify.com', '/v1/search', {
        'q': query,
        'type': 'track',
        'limit': '8',
      }),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    if (response.statusCode != 200) return [];
    final tracks =
        ((jsonDecode(response.body) as Map<String, dynamic>)['tracks']
                as Map<String, dynamic>)['items']
            as List<dynamic>;
    return tracks.map((raw) {
      final track = raw as Map<String, dynamic>;
      final artists = track['artists'] as List<dynamic>? ?? [];
      final images =
          (track['album'] as Map<String, dynamic>)['images']
              as List<dynamic>? ??
          [];
      return SpotifyTrackResult(
        title: track['name'] as String,
        artist: artists
            .map((a) => (a as Map<String, dynamic>)['name'])
            .join(', '),
        uri: track['uri'] as String,
        artworkUrl: images.isEmpty
            ? null
            : (images.first as Map<String, dynamic>)['url'] as String?,
      );
    }).toList();
  }

  Future<void> playTrack(SpotifyTrackResult track) async {
    if (!await _ensureToken() || _webDeviceId == null) return;
    playback = SpotifyPlayback(
      title: track.title,
      artist: track.artist,
      artworkUrl: track.artworkUrl,
      isPlaying: true,
    );
    notifyListeners();
    await http.put(
      Uri.parse(
        'https://api.spotify.com/v1/me/player/play?device_id=$_webDeviceId',
      ),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'uris': [track.uri],
      }),
    );
  }

  Future<void> togglePlayback() async {
    if (playback == null) {
      await _playRandomLikedTrack();
      return;
    }
    if (playback?.isPlaying == true) {
      await _sendPlayerCommand('pause');
    } else {
      await _sendPlayerCommand('play');
    }
  }

  Future<void> refreshPlayback() async {
    if (!await _ensureToken()) return;
    isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/player/currently-playing'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (response.statusCode == 204) {
        playback = null;
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final item = data['item'] as Map<String, dynamic>?;
        final album = item?['album'] as Map<String, dynamic>?;
        final images = album?['images'] as List<dynamic>? ?? [];
        final artists = item?['artists'] as List<dynamic>? ?? [];
        playback = SpotifyPlayback(
          title: item?['name'] as String? ?? 'Sin canción activa',
          artist: artists
              .map((artist) => (artist as Map<String, dynamic>)['name'])
              .whereType<String>()
              .join(', '),
          artworkUrl: images.isEmpty
              ? null
              : (images.first as Map<String, dynamic>)['url'] as String?,
          isPlaying: data['is_playing'] as bool? ?? false,
          positionMs: data['progress_ms'] as int?,
          durationMs: item?['duration_ms'] as int?,
        );
      } else {
        await _handleApiError(response);
      }
    } catch (_) {
      errorMessage = 'No fue posible consultar el reproductor de Spotify.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendPlayerCommand(String command) async {
    if (!await _ensureToken()) return;
    try {
      final url = Uri.parse('https://api.spotify.com/v1/me/player/$command')
          .replace(
            queryParameters: _webDeviceId == null
                ? null
                : {'device_id': _webDeviceId!},
          );
      final headers = {'Authorization': 'Bearer $_accessToken'};
      final response = command == 'next' || command == 'previous'
          ? await http.post(url, headers: headers)
          : await http.put(url, headers: headers);
      if (response.statusCode != 204 && response.statusCode != 202) {
        await _handleApiError(response);
      }
      await refreshPlayback();
    } catch (_) {
      errorMessage = 'No fue posible controlar Spotify.';
      notifyListeners();
    }
  }

  Future<void> _startWebPlayback() async {
    if (!await _ensureToken()) return;
    await SpotifyWebPlayer.instance.initialize(
      token: () => _accessToken,
      onReady: (deviceId) {
        _webDeviceId = deviceId;
        unawaited(_transferToWebPlayer());
      },
      onState: (state) {
        playback = SpotifyPlayback(
          title: state['title'] as String,
          artist: state['artist'] as String,
          artworkUrl: state['artworkUrl'] as String?,
          isPlaying: state['isPlaying'] as bool,
          positionMs: state['positionMs'] as int?,
          durationMs: state['durationMs'] as int?,
        );
        notifyListeners();
      },
      onError: (message) {
        errorMessage = message;
        notifyListeners();
      },
    );
  }

  Future<void> _transferToWebPlayer() async {
    if (_webDeviceId == null || !await _ensureToken()) return;
    final response = await http.put(
      Uri.parse('https://api.spotify.com/v1/me/player'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'device_ids': [_webDeviceId],
        'play': false,
      }),
    );
    if (response.statusCode != 204) await _handleApiError(response);
  }

  Future<void> _playRandomLikedTrack() async {
    if (!await _ensureToken()) return;
    if (_webDeviceId == null) {
      errorMessage =
          'El reproductor de nubzzz se está preparando. Intenta otra vez.';
      notifyListeners();
      return;
    }
    try {
      final saved = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/tracks?limit=50'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      final items =
          (jsonDecode(saved.body) as Map<String, dynamic>)['items']
              as List<dynamic>? ??
          [];
      if (saved.statusCode != 200 || items.isEmpty) {
        errorMessage =
            'Guarda canciones con “Me gusta” en Spotify para reproducir una al azar.';
        notifyListeners();
        return;
      }
      final track =
          items[Random.secure().nextInt(items.length)] as Map<String, dynamic>;
      final item = track['track'] as Map<String, dynamic>;
      final uri = item['uri'] as String;
      final images =
          (item['album'] as Map<String, dynamic>)['images'] as List<dynamic>? ??
          [];
      final artists = item['artists'] as List<dynamic>? ?? [];
      playback = SpotifyPlayback(
        title: item['name'] as String? ?? 'Canción aleatoria',
        artist: artists
            .map((artist) => (artist as Map<String, dynamic>)['name'])
            .join(', '),
        artworkUrl: images.isEmpty
            ? null
            : (images.first as Map<String, dynamic>)['url'] as String?,
        isPlaying: true,
      );
      notifyListeners();
      final response = await http.put(
        Uri.parse(
          'https://api.spotify.com/v1/me/player/play?device_id=$_webDeviceId',
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'uris': [uri],
        }),
      );
      if (response.statusCode != 204) await _handleApiError(response);
    } catch (_) {
      errorMessage = 'No fue posible iniciar una canción aleatoria.';
      notifyListeners();
    }
  }

  Future<void> _exchangeCode(String code, SharedPreferences prefs) async {
    final verifier = prefs.getString(_verifierKey);
    if (verifier == null) {
      errorMessage = 'La conexión expiró. Intenta conectar Spotify otra vez.';
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': verifier,
        },
      );
      if (response.statusCode != 200) {
        errorMessage = 'Spotify no aceptó la conexión. Inténtalo de nuevo.';
        return;
      }
      await _saveTokens(
        jsonDecode(response.body) as Map<String, dynamic>,
        prefs,
      );
      await prefs.remove(_verifierKey);
      await prefs.remove(_stateKey);
    } catch (_) {
      errorMessage = 'No fue posible completar la conexión con Spotify.';
    }
  }

  Future<bool> _ensureToken() async {
    if (_accessToken == null) return false;
    if (_expiresAt == null || DateTime.now().isBefore(_expiresAt!)) return true;
    if (_refreshToken == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
      },
    );
    if (response.statusCode != 200) return false;
    await _saveTokens(jsonDecode(response.body) as Map<String, dynamic>, prefs);
    return true;
  }

  Future<void> _saveTokens(
    Map<String, dynamic> data,
    SharedPreferences prefs,
  ) async {
    _accessToken = data['access_token'] as String?;
    _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn - 30));
    await prefs.setString(_tokenKey, _accessToken!);
    await prefs.setString(_expiryKey, _expiresAt!.toIso8601String());
    if (_refreshToken != null) {
      await prefs.setString(_refreshTokenKey, _refreshToken!);
    }
  }

  Future<void> _handleApiError(http.Response response) async {
    if (response.statusCode == 401) {
      _expiresAt = DateTime.now().subtract(const Duration(seconds: 1));
    } else if (response.statusCode == 404) {
      errorMessage = 'Abre Spotify y empieza a reproducir algo primero.';
    } else {
      errorMessage = 'Spotify no pudo ejecutar ese control.';
    }
  }

  String _randomUrlSafe(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
