import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_state.dart';

class ActivityPage extends StatefulWidget {
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

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
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

  // FIX: Safe filter - if filter crashes, don't hide all data
  bool _safeFilter(Map<String, dynamic> m) {
    try { return widget.matchesClientFilter(m); } catch (_) { return true; }
  }

  Widget _skeletonList() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 60,
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12)),
      )),
    );
  }

  Widget _repliesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs_replies').limit(50).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Firebase error: ${snap.error}', style: const TextStyle(color: Colors.red, fontSize: 12))));
        }
        // PROFESSIONAL: Don't show spinner if we are syncing - show skeleton, not 0
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _skeletonList();
        }
        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((d) {
          final r = d.data() as Map<String, dynamic>;
          return _safeFilter(r);
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
                  onTap: () => widget.onShowReplyDetail(r),
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

  // PROFESSIONAL: Recent Emails from appState.lastJobs - INSTANT, no StreamBuilder
  Widget _recentEmailsList() {
    // First open ever, no cache - show skeleton, not 0, not spinner
    if (!appState.hasLoadedJobs && appState.lastJobs.isEmpty) {
      return Column(children: [ _skeletonList(), const SizedBox(height: 8), const Text('Loading your emails...', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))) ]);
    }

    final allMaps = appState.lastJobs;
    final filtered = allMaps.where((m) {
      if (!_safeFilter(m)) return false;
      if (widget.filter == 'Sent') {
        final st = (m['status'] ?? 'sent').toString().toLowerCase();
        if (st.contains('follow')) return false;
      } else if (widget.filter == 'Follow-up') {
        final st = (m['status'] ?? '').toString().toLowerCase();
        if (!st.contains('follow') && m['has_followup'] != true) return false;
      }
      if (widget.searchQuery.isNotEmpty) {
        final comp = (m['company'] ?? '').toString().toLowerCase();
        final em = (m['email'] ?? '').toString().toLowerCase();
        if (!comp.contains(widget.searchQuery) && !em.contains(widget.searchQuery)) return false;
      }
      if (widget.recentEmailFilter == 'Replied') {
        final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
        if (rs != 'replied' && rs != 'reply' && m['has_reply'] != true) return false;
      }
      if (widget.recentEmailFilter == 'No Reply') {
        final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
        if (rs == 'replied' || m['has_reply'] == true) return false;
      }
      return true;
    }).take(widget.jobsLimit).toList();

    if (filtered.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              widget.searchQuery.isEmpty ? 'No emails yet. The bot will start sending soon.' : 'No match for "${widget.searchQuery}"',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...filtered.map((m) {
          final company = (m['company'] ?? 'Unknown').toString();
          final email = (m['email'] ?? '').toString();
          final cname = widget.clientDisplayName(m);
          final dateVal = m['timestamp'] ?? m['date'] ?? m['sent_at'] ?? m['created_at'] ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: ListTile(
              onTap: () => widget.onShowEmailDetail(m),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.mail_outline, color: Color(0xFF34D399), size: 16),
              ),
              title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('$email - $cname - ${widget.formatDate(dateVal)}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
            ),
          );
        }),
        TextButton(onPressed: widget.onLoadMoreJobs, child: const Text('Load More', style: TextStyle(color: Color(0xFF10B981)))),
      ],
    );
  }

  Widget _followupsList() {
    // PROFESSIONAL: Use cache if we have it, else stream
    if (appState.lastFollowups.isNotEmpty) {
      final docs = appState.lastFollowups.where((m) => _safeFilter(m)).take(widget.followupsLimit).toList();
      if (docs.isEmpty) {
        return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No follow-ups yet.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
      }
      return Column(
        children: docs.map((m) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
            child: ListTile(
              onTap: () => widget.onShowFollowupDetail(m),
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16)),
              title: Text((m['company'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
              subtitle: Text((m['email'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
            ),
          );
        }).toList(),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs_followups').limit(widget.followupsLimit).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Firebase error: ${snap.error}', style: const TextStyle(color: Colors.red, fontSize: 12))));
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return _skeletonList();
        }
        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          return _safeFilter(m);
        }).toList();
        // Save to cache for instant next time
        if (docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            appState.setFollowups(docs.map((d) => d.data() as Map<String, dynamic>).toList());
          });
        }
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
                onTap: () => widget.onShowFollowupDetail(m),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // PROFESSIONAL: Listen to appState - when main.dart syncs new jobs, Activity updates instantly, no extra Firestore call
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final clientFilterItems = <DropdownMenuItem<String>>[
          const DropdownMenuItem(value: 'All', child: Text('All Clients')),
          ...widget.clientsCache.map((c) => DropdownMenuItem(value: (c['id'] ?? '').toString(), child: Text((c['name'] ?? '').toString()))),
        ];
        final validClientFilter = clientFilterItems.any((item) => item.value == widget.selectedClientFilter) ? widget.selectedClientFilter : 'All';

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PROFESSIONAL: Sync status like Gmail
              Row(
                children: [
                  Text(appState.isSyncing ? 'Syncing...' : appState.lastSyncLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  if (appState.isSyncing) ...[
                    const SizedBox(width: 6),
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF10B981))),
                  ],
                  const Spacer(),
                  Text('${appState.lastJobs.length} emails cached', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
              const SizedBox(height: 12),
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
                          onChanged: (v) => widget.onClientFilterChanged(v ?? 'All'),
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
                      onChanged: (v) => widget.onSearchChanged(v.toLowerCase()),
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
                        value: widget.filter,
                        dropdownColor: const Color(0xFF111827),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: ['All', 'Sent', 'Follow-up'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (v) => widget.onFilterChanged(v ?? 'All'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _collapsibleHeader('Replies', widget.showReplies, widget.onToggleReplies),
              if (widget.showReplies) ...[
                const SizedBox(height: 10),
                _repliesList(),
              ],
              const SizedBox(height: 24),
              _collapsibleHeader('Recent Emails', widget.showRecentEmails, widget.onToggleRecentEmails),
              if (widget.showRecentEmails) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Replied', 'No Reply'].map((f) {
                    final sel = widget.recentEmailFilter == f;
                    return ChoiceChip(
                      label: Text(f, style: TextStyle(color: sel ? Colors.white : const Color(0xFF9CA3AF), fontSize: 12)),
                      selected: sel,
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: const Color(0xFF1F2937),
                      onSelected: (_) => widget.onRecentEmailFilterChanged(f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                _recentEmailsList(),
              ],
              const SizedBox(height: 20),
              _collapsibleHeader('Follow-ups', widget.showFollowups, widget.onToggleFollowups),
              if (widget.showFollowups) ...[
                const SizedBox(height: 10),
                _followupsList(),
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}
