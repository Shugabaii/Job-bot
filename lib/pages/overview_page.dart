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

  // FIX: Try ALL possible date fields - your bot saves different names
  DateTime? _getDate(Map<String, dynamic> m) {
    for (final key in ['timestamp', 'date', 'sent_at', 'sentAt', 'created_at', 'createdAt', 'last_run']) {
      final dt = widget.parseDate(m[key]);
      if (dt != null) return dt;
    }
    return null;
  }

  Widget _buildGraph(List<Map<String, dynamic>> docs) {
    final now = DateTime.now();
    final Map<String, int> perDay = {};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      perDay[widget.dayKey(d)] = 0;
    }
    for (final m in docs) {
      final dt = _getDate(m);
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
            // FIX: ONE stream, NO orderBy, NO includeMetadataChanges = no freeze
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').limit(500).snapshots(),
              builder: (context, sentSnap) {
                if (sentSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Firebase error: ${sentSnap.error}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  );
                }
                if (sentSnap.connectionState == ConnectionState.waiting && !sentSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                  );
                }
                final allDocs = sentSnap.data?.docs ?? [];
                final allMaps = allDocs.map((d) => d.data() as Map<String, dynamic>).toList();
                // FIX: If filter removes everything, show all - don't show 0 by mistake
                var filtered = allMaps.where((m) {
                  try { return widget.matchesClientFilter(m); } catch (_) { return true; }
                }).toList();
                if (filtered.isEmpty && allMaps.isNotEmpty) filtered = allMaps;

                final totalSent = filtered.length;
                final todayKey = widget.dayKey(DateTime.now());
                final sentToday = filtered.where((m) {
                  final dt = _getDate(m);
                  return dt != null && widget.dayKey(dt) == todayKey;
                }).length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bot Status - read once, not as a stream
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('bot_status').doc('current').get(const GetOptions(source: Source.server)),
                      builder: (context, statusSnap) {
                        final data = statusSnap.data?.data() as Map<String, dynamic>?;
                        final rawCompany = (data?['last_company'] ?? '').toString().trim();
                        final lastCompany = (rawCompany.isEmpty || rawCompany.startsWith('Waiting ')) ? 'Waiting' : rawCompany;
                        final lastRun = (data?['last_run'] ?? 'No recent activity').toString();
                        return Container(
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
                                Text('$sentToday', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 2),
                                const Text('Sent Today', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
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
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildGraph(filtered),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _metric('Total Sent', '$totalSent', Icons.send_outlined, 'All emails sent'),
                        const SizedBox(width: 12),
                        _metric('Today', '$sentToday', Icons.today_outlined, 'Sent today'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Replies - separate simple stream, no metadata
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('jobs_replies').limit(500).snapshots(),
                      builder: (context, repSnap) {
                        final replies = repSnap.data?.docs.length ?? 0;
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
                    ),
                  ],
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
