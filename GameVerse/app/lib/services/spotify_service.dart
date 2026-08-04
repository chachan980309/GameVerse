import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyPlayback {
  const SpotifyPlayback({
    required this.title,
    required this.artist,
    required this.isPlaying,
    this.artworkUrl,
  });

  final String title;
  final String artist;
  final String? artworkUrl;
  final bool isPlaying;

  SpotifyPlayback copyWith({bool? isPlaying}) => SpotifyPlayback(
    title: title,
    artist: artist,
    artworkUrl: artworkUrl,
    isPlaying: isPlaying ?? this.isPlaying,
  );
}

/// Cliente Spotify para web usando Authorization Code con PKCE.
/// El Client ID es público por diseño; no se usa ni almacena Client Secret.
class SpotifyService extends ChangeNotifier {
  SpotifyService._();

  static final instance = SpotifyService._();

  static const _clientId = '3fc7ca94a72940ada5c8a6d83eef2fde';
  static const _redirectUri = 'https://nubzzz.site/callback';
  static const _scopes = [
    'user-read-playback-state',
    'user-read-currently-playing',
    'user-modify-playback-state',
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
    if (isConnected) await refreshPlayback();
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

  Future<void> previous() => _sendPlayerCommand('previous');
  Future<void> next() => _sendPlayerCommand('next');

  Future<void> togglePlayback() async {
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
      final url = Uri.parse('https://api.spotify.com/v1/me/player/$command');
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
      await _saveTokens(jsonDecode(response.body) as Map<String, dynamic>, prefs);
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
    if (_refreshToken != null) await prefs.setString(_refreshTokenKey, _refreshToken!);
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
