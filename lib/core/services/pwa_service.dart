import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pwa_service.g.dart';

@JS('window.isPWAInstallable')
external JSBoolean _isPWAInstallable();

@JS('window.triggerPWAInstall')
external JSPromise<JSBoolean> _triggerPWAInstall();

@JS('window.onAppInstallableCallback')
external set _onAppInstallableCallback(JSFunction? callback);

@JS('window.onAppInstalledCallback')
external set _onAppInstalledCallback(JSFunction? callback);

@Riverpod(keepAlive: true)
class PwaController extends _$PwaController {
  @override
  bool build() {
    if (!kIsWeb) return false;
    
    // Wire up callbacks
    try {
      _onAppInstallableCallback = (() {
        state = true;
      }).toJS;

      _onAppInstalledCallback = (() {
        state = false;
      }).toJS;
    } catch (_) {}

    return isInstallable();
  }

  bool isInstallable() {
    if (!kIsWeb) return false;
    try {
      return _isPWAInstallable().toDart;
    } catch (_) {
      return false;
    }
  }

  Future<bool> installApp() async {
    if (!kIsWeb) return false;
    try {
      final response = await _triggerPWAInstall().toDart;
      return response.toDart;
    } catch (_) {
      return false;
    }
  }
}
