import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverviewPage extends StatefulWidget {
  final String activeClientDisplayName;
  final bool Function(Map<String, dynamic>) matchesClientFilter;
  final DateTime? Function(dynamic) parseDate;
  final String Function(DateTime) dayKey;
  final String Function(DateTime) dayLabel;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;

  const OverviewPage({
    super.key,
    required this.activeClientDisplayName,
    required this.matchesClientFilter,
    required this.parseDate,
    required this.dayKey,
    required this.dayLabel,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  // FIX: Keep last data - show it instantly, never show skeleton / empty boxes
  List<QueryDocumentSnapshot>? _lastSentDocs;
  Map<String, dynamic>? _lastStatusData;
  int _lastRepliesCount = 0;
  bool _hasEverLoadedReplies = false;

  Widget _metric(String title, String value, IconData icon, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _systemRow(String title, String status) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.white))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)),
          child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399))),
        ),
      ],
    );
  }

  Widget _buildGraph(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final Map<String, int> perDay = {};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      perDay[widget.dayKey(d)] = 0;
    }
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final dt = widget.parseDate(m['timestamp'] ?? m['date']);
      if (dt == null) continue;
      final k = widget.dayKey(dt);
      if (perDay.containsKey(k)) perDay[k] = (perDay[k] ?? 0) + 1;
    }
    final maxV = perDay.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last 7 Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: perDay.entries.map((e) {
                final h = 8 + (e.value / maxV * 60);
                return Expanded(
                  child: Column(
                    children: [
                      Text('${e.value}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 4),
                      Container(
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.dayLabel(DateTime.parse(e.key)), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _repliesMetrics(int totalSent) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs_replies').snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        // FIX: No skeleton. Show last known replies instantly, or 0 if never loaded.
        if (snap.hasData) {
          final all = snap.data?.docs ?? [];
          final filtered = all.where((d) => widget.matchesClientFilter(d.data() as Map<String, dynamic>)).toList();
          _lastRepliesCount = filtered.length;
          _hasEverLoadedReplies = true;
        }
        final replies = _hasEverLoadedReplies ? _lastRepliesCount : 0;
        double rate = 0.0;
        if (totalSent > 0) {
          rate = (replies / totalSent * 100);
          if (rate > 100) rate = 100;
          if (rate < 0) rate = 0;
        }
        return Row(
          children: [
            _metric('Replies', '$replies', Icons.mark_email_read_outlined, 'Companies replied'),
            const SizedBox(width: 12),
            _metric('Reply Rate', '${rate.toStringAsFixed(1)}%', Icons.trending_up, 'Response rate'),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3)),
                    SizedBox(height: 2),
                    Text('Your applications and email activity', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onOpenSettings,
                      icon: const Icon(Icons.settings, size: 18, color: Color(0xFF9CA3AF)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFF1F2937)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF9CA3AF)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFF1F2937)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('bot_status').doc('current').snapshots(includeMetadataChanges: true),
              builder: (context, statusSnap) {
                if (statusSnap.hasData && statusSnap.data?.data() != null) {
                  _lastStatusData = statusSnap.data!.data() as Map<String, dynamic>;
                }
                final data = _lastStatusData;
                final rawCompany = (data?['last_company'] ?? '').toString().trim();
                final lastCompany = (rawCompany.isEmpty || rawCompany.startsWith('Waiting ')) ? 'Waiting' : rawCompany;
                final lastRun = (data?['last_run'] ?? 'No recent activity').toString();
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).snapshots(includeMetadataChanges: true),
                  builder: (context, sentSnap) {
                    // FIX: No skeleton. Use last data if still loading.
                    if (sentSnap.hasData) {
                      _lastSentDocs = sentSnap.data?.docs ?? [];
                    }
                    // First ever open with truly no data yet: show real 0s, not grey boxes
                    final allDocs = _lastSentDocs ?? [];
                    final filtered = allDocs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      return widget.matchesClientFilter(m);
                    }).toList();
                    final totalSent = filtered.length;
                    final sentTodayFirestore = filtered.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final dt = widget.parseDate(m['timestamp']);
                      return dt != null && widget.dayKey(dt) == widget.dayKey(DateTime.now());
                    }).length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1F2937)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.bolt, size: 16, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Bot Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$sentTodayFirestore', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 2),
                                          const Text('Sent Today', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('Last: $lastCompany', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                Text(lastRun, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                const SizedBox(height: 12),
                                _systemRow('Bot', 'Online'),
                                const SizedBox(height: 8),
                                _systemRow('Gmail', 'Connected'),
                                const SizedBox(height: 8),
                                _systemRow('Active Client', widget.activeClientDisplayName),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildGraph(filtered),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _metric('Total Sent', '$totalSent', Icons.send_outlined, 'All emails sent'),
                            const SizedBox(width: 12),
                            _metric('Today', '$sentTodayFirestore', Icons.today_outlined, 'Sent today'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _repliesMetrics(totalSent),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
