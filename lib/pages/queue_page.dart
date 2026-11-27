import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QueuePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manual Queue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Long-press an item to Retry or Delete.', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('pending_jobs').orderBy('created_at', descending: true).limit(20).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final docs = snap.data!.docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                return matchesManualFilter(m);
              }).toList();
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No manual requests.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
                  ),
                );
              }
              return Column(
                children: docs.map((d) {
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
                      onLongPress: () => onShowManualActions(d.id, (m['company'] ?? '').toString(), st),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: manualStatusColor(st).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.schedule, color: manualStatusColor(st), size: 16),
                      ),
                      title: Text((m['company'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                      subtitle: Text(
                        '${m['email'] ?? ''} - ${manualStatusLabel(st)}${skillLabel.isNotEmpty ? ' - $skillLabel' : ''}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                      trailing: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF6B7280)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
