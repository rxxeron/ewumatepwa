import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../router/app_router.dart';

part 'update_service.g.dart';

@JS('window.location.reload')
external void _reloadPage();

@JS('window.onServiceWorkerUpdateCallback')
external set _onServiceWorkerUpdateCallback(JSFunction? callback);

@Riverpod(keepAlive: true)
void updateListener(UpdateListenerRef ref) {
  _onServiceWorkerUpdateCallback = (() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'A premium update for EWUMate is ready!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        action: SnackBarAction(
          label: 'RELOAD',
          textColor: const Color(0xFFD4AF37),
          onPressed: () => _reloadPage(),
        ),
        duration: const Duration(days: 1), // Keeps prompt open
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }).toJS;
}
