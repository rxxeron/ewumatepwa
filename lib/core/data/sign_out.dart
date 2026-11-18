import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import 'data_providers.dart';

/// Signs out without silently losing offline edits: tries to send queued
/// changes first and asks before discarding any that could not be sent.
/// Returns true when the user was signed out.
Future<bool> signOutSafely(BuildContext context, WidgetRef ref) async {
  final outbox = ref.read(outboxProvider);
  var pending = await outbox.pendingCount();

  if (pending > 0) {
    final coordinator = ref.read(syncCoordinatorProvider);
    if (coordinator != null) {
      try {
        await coordinator.syncNow().timeout(const Duration(seconds: 15));
      } catch (_) {}
      pending = await outbox.pendingCount();
    }
  }

  if (pending > 0) {
    if (!context.mounted) return false;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Unsynced changes', style: TextStyle(color: Colors.white)),
        content: Text(
          '$pending change${pending == 1 ? '' : 's'} made offline ha${pending == 1 ? 's' : 've'} not reached the '
          'server yet. Signing out now will lose ${pending == 1 ? 'it' : 'them'}.\n\n'
          'Connect to the internet and wait a moment to keep ${pending == 1 ? 'it' : 'them'}.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay signed in')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out anyway', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (discard != true) return false;
  }

  await ref.read(authRepositoryProvider).signOut();
  return true;
}
