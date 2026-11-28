import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';

class QueuePage extends StatefulWidget {
  final bool Function(Map<String, dynamic>) matchesManualFilter;
  final Color Function(String) manualStatusColor;
  final String Function(String) manualStatusLabel;
  final Future<void> Function(String, String, String) onShowManualActions;

  const QueuePage({
    super.key,
    required this.matchesManualFilter,
    required this.manualStatusColor,
    required this.manualStatusLabel,
    required this.onShowManualActions,
  });

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  // PROFESSIONAL: Keep last queue in memory - show instantly while new data syncs.
  // This is how Gmail / WhatsApp do it. Never show 0, never show blank spinner.
  List<QueryDocumentSnapshot> _lastDocs = [];
  bool _hasLoadedOnce = false;

  Widget _skeleton() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 60,
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12)),
      )),
    );
  }

  bool _safeFilter(Map<String, dynamic> m) {
    try { return widget.matchesManualFilter(m); } catch (_) { return true; }
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    final filtered = docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      return _safeFilter(m);
    }).toList();

    if (filtered.isEmpty) {
      // PROFESSIONAL: If we had data before but filter hides it, don't show "No manual requests" by mistake
      // Only show empty when we truly have no data AND we have loaded once
      if (_hasLoadedOnce && _lastDocs.isNotEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No match for current filter.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
          ),
        );
      }
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No manual requests.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
        ),
      );
    }

    return Column(
      children: filtered.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final st = (m['status'] ?? 'pending').toString();
        final skillLabel = (m['job_type'] ?? m['skill'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: ListTile(
            onLongPress: () => widget.onShowManualActions(d.id, (m['company'] ?? '').toString(), st),
            onTap: () => widget.onShowManualActions(d.id, (m['company'] ?? '').toString(), st),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: widget.manualStatusColor(st).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.schedule, color: widget.manualStatusColor(st), size: 16),
            ),
            title: Text((m['company'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
            subtitle: Text(
              '${m['email'] ?? ''} - ${widget.manualStatusLabel(st)}${skillLabel.isNotEmpty ? ' - $skillLabel' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
            trailing: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF6B7280)),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Manual Queue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  const Spacer(),
                  // PROFESSIONAL: Sync status like Gmail
                  Text(appState.isSyncing ? 'Syncing...' : appState.lastSyncLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                  if (appState.isSyncing) ...[
                    const SizedBox(width: 6),
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF10B981))),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              const Text('Long-press an item to Retry or Delete.', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('pending_jobs').limit(50).snapshots(),
                builder: (context, snap) {
                  // PROFESSIONAL: If we have last data, show it INSTANTLY while new data loads.
                  // Don't show spinner, don't show 0.
                  if (snap.hasData && snap.data != null) {
                    final docs = snap.data!.docs;
                    // Don't overwrite good cache with empty while syncing
                    if (docs.isNotEmpty || !_hasLoadedOnce) {
                      _lastDocs = docs;
                      _hasLoadedOnce = true;
                    }
                    return _buildList(_lastDocs);
                  }

                  if (snap.hasError) {
                    // If error but we have cache, show cache - don't show error screen
                    if (_lastDocs.isNotEmpty) return _buildList(_lastDocs);
                    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Firebase error: ${snap.error}', style: const TextStyle(color: Colors.red, fontSize: 12))));
                  }

                  // Waiting + no data yet
                  if (_lastDocs.isNotEmpty) {
                    // Show last data instantly, not spinner
                    return _buildList(_lastDocs);
                  }

                  // First open ever, no cache - skeleton, not 0, not spinner
                  return Column(
                    children: [
                      _skeleton(),
                      const SizedBox(height: 8),
                      const Text('Loading queue...', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}
