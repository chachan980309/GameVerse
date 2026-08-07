// ignore_for_file: undefined_function, undefined_method
import 'dart:html';
import 'dart:js' as js;
import 'dart:convert';

class SpotifyWebPlayer {
  SpotifyWebPlayer._();
  static final instance = SpotifyWebPlayer._();

  Future<void> initialize({
    required String? Function() token,
    required void Function(String deviceId) onReady,
    required void Function(Map<String, dynamic> state) onState,
    required void Function(String message) onError,
  }) async {
    final bridge = js.context['nubzzzSpotify'] as js.JsObject?;
    if (bridge == null) return;
    bridge.callMethod('init', [
      js.allowInterop(() => token() ?? ''),
      js.allowInterop((String id) => onReady(id)),
      js.allowInterop((String rawState) {
        final state = jsonDecode(rawState) as Map<String, dynamic>;
        final trackWindow = state['track_window'] as Map<String, dynamic>?;
        final track = trackWindow?['current_track'] as Map<String, dynamic>?;
        if (track == null) return;
        final artists = track['artists'] as List<dynamic>? ?? const [];
        final album = track['album'] as Map<String, dynamic>?;
        final images = album?['images'] as List<dynamic>? ?? const [];
        onState({
          'title': track['name'] as String? ?? 'Sin canción activa',
          'artist': artists
              .whereType<Map<String, dynamic>>()
              .map((artist) => artist['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .join(', '),
          'artworkUrl': images.isEmpty
              ? null
              : (images.first as Map<String, dynamic>)['url'] as String?,
          'isPlaying': !(state['paused'] as bool? ?? true),
          'positionMs': state['position'] as int?,
          'durationMs': track['duration_ms'] as int?,
        });
      }),
      js.allowInterop((String message) => onError(message)),
    ]);
  }
}
