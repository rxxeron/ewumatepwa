/// What the UI needs to be honest about data freshness.
class SyncStatus {
  final bool online;
  final bool syncing;

  /// Last time a sync completed without errors (persisted across launches).
  final DateTime? lastSyncedAt;

  /// Local writes not yet on the server.
  final int pending;

  /// Writes the server rejected (shown under "Sync issues").
  final int failed;
  final String? lastError;

  const SyncStatus({
    this.online = true,
    this.syncing = false,
    this.lastSyncedAt,
    this.pending = 0,
    this.failed = 0,
    this.lastError,
  });

  SyncStatus copyWith({
    bool? online,
    bool? syncing,
    DateTime? lastSyncedAt,
    int? pending,
    int? failed,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  /// True when the screen should show a freshness hint.
  bool get needsAttention => !online || lastError != null || pending > 0 || failed > 0;
}

/// "3 h ago", "just now", "2 d ago".
String formatAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}
