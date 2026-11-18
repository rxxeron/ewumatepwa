import 'dart:async';

/// App-wide "please sync" signal. Anything that learns the server changed
/// (FCM data message, a screen's pull-to-refresh, a write) calls [request];
/// the SyncCoordinator debounces and runs one sync.
class SyncSignals {
  SyncSignals._();
  static final instance = SyncSignals._();

  final _controller = StreamController<SyncRequest>.broadcast();
  Stream<SyncRequest> get stream => _controller.stream;

  void request({bool force = false, String reason = ''}) => _controller.add(SyncRequest(force, reason));
}

class SyncRequest {
  final bool force;
  final String reason;
  const SyncRequest(this.force, this.reason);
}
