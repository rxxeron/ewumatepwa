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

  PwaState({
    required this.isInstallable,
    required this.isStandalone,
    required this.isIOS,
  });

  PwaState copyWith({
    bool? isInstallable,
    bool? isStandalone,
    bool? isIOS,
  }) {
    return PwaState(
      isInstallable: isInstallable ?? this.isInstallable,
      isStandalone: isStandalone ?? this.isStandalone,
      isIOS: isIOS ?? this.isIOS,
    );
  }
}

@Riverpod(keepAlive: true)
class PwaController extends _$PwaController {
  @override
  PwaState build() {
    if (!kIsWeb) {
      return PwaState(isInstallable: false, isStandalone: false, isIOS: false);
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
    if (!kIsWeb) return false;
    try {
      return _isIOSDevice().toDart;
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
