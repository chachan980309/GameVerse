class MicrophoneMeter {
  bool get isRunning => false;

  Future<void> start(
    dynamic stream,
    void Function(double level) onLevel,
  ) async {}

  Future<void> stop() async {}
}
