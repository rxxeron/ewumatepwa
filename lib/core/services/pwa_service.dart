import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pwa_service.g.dart';

@JS('window.isPWAInstallable')
external JSBoolean _isPWAInstallable();

@JS('window.isPWAStandalone')
external JSBoolean _isPWAStandalone();

@JS('window.isIOSDevice')
external JSBoolean _isIOSDevice();

@JS('window.isRxxeronBypassed')
external JSBoolean _isRxxeronBypassed();

@JS('window.setRxxeronBypassed')
external void _setRxxeronBypassed();

@JS('window.triggerPWAInstall')
external JSPromise<JSBoolean> _triggerPWAInstall();

@JS('window.onAppInstallableCallback')
external set _onAppInstallableCallback(JSFunction? callback);

@JS('window.onAppInstalledCallback')
external set _onAppInstalledCallback(JSFunction? callback);

class PwaState {
  final bool isInstallable;
  final bool isStandalone;
  final bool isIOS;
  final bool isBypassed;

  PwaState({
    required this.isInstallable,
    required this.isStandalone,
    required this.isIOS,
    this.isBypassed = false,
  });

  /// Access is granted if on iOS or if unlocked via rxxeron=true bypass
  bool get hasAccess => isIOS || isBypassed;

  PwaState copyWith({
    bool? isInstallable,
    bool? isStandalone,
    bool? isIOS,
    bool? isBypassed,
  }) {
    return PwaState(
      isInstallable: isInstallable ?? this.isInstallable,
      isStandalone: isStandalone ?? this.isStandalone,
      isIOS: isIOS ?? this.isIOS,
      isBypassed: isBypassed ?? this.isBypassed,
    );
  }
}

@Riverpod(keepAlive: true)
class PwaController extends _$PwaController {
  @override
  PwaState build() {
    if (!kIsWeb) {
      return PwaState(isInstallable: false, isStandalone: false, isIOS: true, isBypassed: true);
    }
    
    // Wire up callbacks
    try {
      _onAppInstallableCallback = (() {
        state = state.copyWith(isInstallable: true);
      }).toJS;

      _onAppInstalledCallback = (() {
        state = state.copyWith(isInstallable: false, isStandalone: true);
      }).toJS;
    } catch (_) {}

    return PwaState(
      isInstallable: isInstallable(),
      isStandalone: isStandalone(),
      isIOS: isIOS(),
      isBypassed: isBypassed(),
    );
  }

  bool isInstallable() {
    if (!kIsWeb) return false;
    try {
      return _isPWAInstallable().toDart;
    } catch (_) {
      return false;
    }
  }

  bool isStandalone() {
    if (!kIsWeb) return false;
    try {
      return _isPWAStandalone().toDart;
    } catch (_) {
      return false;
    }
  }

  bool isIOS() {
    if (!kIsWeb) return true;
    try {
      return _isIOSDevice().toDart;
    } catch (_) {
      return false;
    }
  }

  bool isBypassed() {
    if (!kIsWeb) return true;
    try {
      if (Uri.base.queryParameters['rxxeron'] == 'true') {
        _setRxxeronBypassed();
        return true;
      }
      return _isRxxeronBypassed().toDart;
    } catch (_) {
      return false;
    }
  }

  void setBypassed() {
    if (!kIsWeb) return;
    try {
      _setRxxeronBypassed();
      state = state.copyWith(isBypassed: true);
    } catch (_) {}
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
