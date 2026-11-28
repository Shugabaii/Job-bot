import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityPage extends StatelessWidget {
  final String selectedClientFilter;
  final List<Map<String, dynamic>> clientsCache;
  final String searchQuery;
  final String filter;
  final bool showReplies;
  final bool showRecentEmails;
  final bool showFollowups;
  final String recentEmailFilter;
  final int jobsLimit;
  final int followupsLimit;
  final ValueChanged<String> onClientFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onToggleReplies;
  final VoidCallback onToggleRecentEmails;
  final VoidCallback onToggleFollowups;
  final ValueChanged<String> onRecentEmailFilterChanged;
  final VoidCallback onLoadMoreJobs;
  final bool Function(Map<String, dynamic>) matchesClientFilter;
  final String Function(Map<String, dynamic>) clientDisplayName;
  final String Function(dynamic) formatDate;
  final void Function(Map<String, dynamic>) onShowEmailDetail;
  final void Function(Map<String, dynamic>) onShowReplyDetail;
  final void Function(Map<String, dynamic>) onShowFollowupDetail;

  const ActivityPage({
    super.key,
    required this.selectedClientFilter,
    required this.clientsCache,
    required this.searchQuery,
    required this.filter,
    required this.showReplies,
    required this.showRecentEmails,
    required this.showFollowups,
    required this.recentEmailFilter,
    required this.jobsLimit,
    required this.followupsLimit,
    required this.onClientFilterChanged,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onToggleReplies,
    required this.onToggleRecentEmails,
    required this.onToggleFollowups,
    required this.onRecentEmailFilterChanged,
    required this.onLoadMoreJobs,
    required this.matchesClientFilter,
    required this.clientDisplayName,
    required this.formatDate,
    required this.onShowEmailDetail,
    required this.onShowReplyDetail,
    required this.onShowFollowupDetail,
  });

  Widget _collapsibleHeader(String title, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
              child: Text(expanded ? 'Hide' : 'View', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF9CA3AF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _repliesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs_replies').orderBy('timestamp', descending: true).limit(20).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(
            children: [
              SizedBox(height: 20),
              Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
              SizedBox(height: 12),
              Text('Loading replies...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            ],
          );
        }
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((d) {
          final r = d.data() as Map<String, dynamic>;
          return matchesClientFilter(r);
        }).toList();
        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle),
                      child: const Icon(Icons.reply_outlined, size: 22, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 10),
                    const Text('No replies yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('When a company replies in Gmail, it will appear here automatically.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Replies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                  child: Text('${docs.length} total - Tap to view reply', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...docs.map((d) {
              final r = d.data() as Map<String, dynamic>;
              final company = (r['company'] ?? 'Unknown').toString();
              final email = (r['email'] ?? '').toString();
              final subject = (r['subject'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  onTap: () => onShowReplyDetail(r),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16),
                  ),
                  title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subject.isNotEmpty ? '$subject - $email' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientFilterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'All', child: Text('All Clients')),
      ...clientsCache.map((c) => DropdownMenuItem(value: (c['id'] ?? '').toString(), child: Text((c['name'] ?? '').toString()))),
    ];
    final validClientFilter = clientFilterItems.any((item) => item.value == selectedClientFilter) ? selectedClientFilter : 'All';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Client Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: validClientFilter,
                      dropdownColor: const Color(0xFF111827),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      isExpanded: true,
                      items: clientFilterItems,
                      onChanged: (v) => onClientFilterChanged(v ?? 'All'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search company...',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                    filled: true,
                    fillColor: const Color(0xFF111827),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) => onSearchChanged(v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: filter,
                    dropdownColor: const Color(0xFF111827),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: ['All', 'Sent', 'Follow-up'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => onFilterChanged(v ?? 'All'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _collapsibleHeader('Replies', showReplies, onToggleReplies),
          if (showReplies) ...[
            const SizedBox(height: 10),
            _repliesList(),
          ],
          const SizedBox(height: 24),
          _collapsibleHeader('Recent Emails', showRecentEmails, onToggleRecentEmails),
          if (showRecentEmails) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: ['All', 'Replied', 'No Reply'].map((f) {
                final sel = recentEmailFilter == f;
                return ChoiceChip(
                  label: Text(f, style: TextStyle(color: sel ? Colors.white : const Color(0xFF9CA3AF), fontSize: 12)),
                  selected: sel,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF1F2937),
                  onSelected: (_) => onRecentEmailFilterChanged(f),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).limit(jobsLimit).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Column(
                    children: [
                      SizedBox(height: 20),
                      Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                      SizedBox(height: 12),
                      Text('Loading emails...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    ],
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                final docs = snap.data!.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  if (!matchesClientFilter(m)) return false;
                  if (filter == 'Sent') {
                    final st = (m['status'] ?? 'sent').toString().toLowerCase();
                    if (st.contains('follow')) return false;
                  } else if (filter == 'Follow-up') {
                    final st = (m['status'] ?? '').toString().toLowerCase();
                    if (!st.contains('follow') && m['has_followup'] != true) return false;
                  }
                  if (searchQuery.isNotEmpty) {
                    final comp = (m['company'] ?? '').toString().toLowerCase();
                    final em = (m['email'] ?? '').toString().toLowerCase();
                    if (!comp.contains(searchQuery) && !em.contains(searchQuery)) return false;
                  }
                  if (recentEmailFilter == 'Replied') {
                    final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
                    if (rs != 'replied' && rs != 'reply' && m['has_reply'] != true) return false;
                  }
                  if (recentEmailFilter == 'No Reply') {
                    final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
                    if (rs == 'replied' || m['has_reply'] == true) return false;
                  }
                  return true;
                }).toList();
                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          searchQuery.isEmpty ? 'No emails yet. The bot will start sending soon.' : 'No match for "$searchQuery"',
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    ...docs.map((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final company = (m['company'] ?? 'Unknown').toString();
                      final email = (m['email'] ?? '').toString();
                      final cname = clientDisplayName(m);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: ListTile(
                          onTap: () => onShowEmailDetail(m),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.mail_outline, color: Color(0xFF34D399), size: 16),
                          ),
                          title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$email - $cname - ${formatDate(m['timestamp'])}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                        ),
                      );
                    }),
                    TextButton(onPressed: onLoadMoreJobs, child: const Text('Load More', style: TextStyle(color: Color(0xFF10B981)))),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          _collapsibleHeader('Follow-ups', showFollowups, onToggleFollowups),
          if (showFollowups) ...[
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_followups').orderBy('timestamp', descending: true).limit(followupsLimit).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Column(
                    children: [
                      SizedBox(height: 20),
                      Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                      SizedBox(height: 12),
                      Text('Loading follow-ups...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    ],
                  );
                }
                if (!snap.hasData) return const SizedBox.shrink();
                final docs = snap.data!.docs.where((d) {
                  final m = d.data() as Map<String, dynamic>;
                  return matchesClientFilter(m);
                }).toList();
                if (docs.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No follow-ups yet.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
                    ),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final m = d.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: ListTile(
                        onTap: () => onShowFollowupDetail(m),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16),
                        ),
                        title: Text((m['company'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                        subtitle: Text((m['email'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
