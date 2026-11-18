import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_providers.dart';
import '../data/db/app_database.dart';
import '../data/sync/sync_signals.dart';
import '../data/sync/sync_status.dart';

/// Small honest-freshness pill: invisible when everything is synced; otherwise
/// "Offline · synced 3 h ago", "2 changes waiting", "Sync issue". Never blocks content.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    if (!s.needsAttention) return const SizedBox.shrink();
    final synced = s.lastSyncedAt == null ? '' : ' · synced ${formatAgo(s.lastSyncedAt)}';

    final (IconData icon, Color color, String text) = switch (s) {
      SyncStatus(failed: > 0) => (Icons.error_outline_rounded, Colors.orangeAccent, 'Sync issue · tap'),
      SyncStatus(online: false) => (
          Icons.cloud_off_rounded,
          Colors.white70,
          s.pending > 0
              ? 'Offline · ${s.pending} change${s.pending == 1 ? '' : 's'} waiting'
              : 'Offline$synced'
        ),
      SyncStatus(pending: > 0) => (
          Icons.cloud_upload_outlined,
          Colors.white70,
          '${s.pending} change${s.pending == 1 ? '' : 's'} waiting'
        ),
      _ => (Icons.sync_problem_rounded, Colors.white70, 'Couldn\'t refresh$synced'),
    };

    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        onTap: () => s.failed > 0 ? showSyncIssues(context) : SyncSignals.instance.request(reason: 'chip'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (s.syncing)
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: color))
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Lists writes the server rejected (e.g. "Couldn't enroll: section changed").
Future<void> showSyncIssues(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14161C),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _SyncIssuesSheet(),
  );
}

class _SyncIssuesSheet extends ConsumerWidget {
  const _SyncIssuesSheet();

  static String explain(String? reason) => switch (reason) {
        'section_changed' => 'The section\'s schedule changed before your request reached the server.',
        'section_not_found' => 'That section no longer exists.',
        'semester_closed' => 'Enrollment for that semester is closed.',
        'course_mismatch' => 'The section belongs to a different course.',
        null => 'The server did not accept this change.',
        _ => reason,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outbox = ref.watch(outboxProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: StreamBuilder<List<OutboxEntry>>(
          stream: outbox.watchFailed(),
          builder: (context, snap) {
            final items = snap.data ?? const <OutboxEntry>[];
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sync issues',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('These changes were undone on this phone because the server refused them.',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nothing here.', style: TextStyle(color: Colors.white54)),
                ),
              for (final e in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.undo_rounded, color: Colors.orangeAccent),
                  title: Text(e.label ?? 'Change', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(explain(e.lastError), style: const TextStyle(color: Colors.white60)),
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => outbox.dismissFailed(e.id),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
