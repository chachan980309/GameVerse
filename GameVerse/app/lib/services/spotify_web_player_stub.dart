class SpotifyWebPlayer {
  SpotifyWebPlayer._();
  static final instance = SpotifyWebPlayer._();

  Future<void> initialize({
    required String? Function() token,
    required void Function(String deviceId) onReady,
    required void Function(Map<String, dynamic> state) onState,
    required void Function(String message) onError,
  }) async {}
}
