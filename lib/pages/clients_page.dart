import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientsPage extends StatelessWidget {
  final String activeClientId;
  final void Function(List<Map<String, dynamic>>) onClientsUpdated;
  final VoidCallback onUseMeHabibu;
  final VoidCallback onAddClient;
  final String Function(Map<String, dynamic>) senderEmailForClient;
  final Future<void> Function(String, String) onDeleteClient;
  final Future<void> Function(String, String, String) onEditSenderEmail;
  final Future<void> Function(String) onSetActiveClient;
  final Future<void> Function(String, String, String) onShowConnectLink;
  final Future<void> Function(String, bool) onPauseResumeClient;
  final void Function(String, String, dynamic) onShowLimitDialog;
  final Future<void> Function(String, String, String) onPasteCv;
  final Future<void> Function(String, String, Map<String, dynamic>) onEditProof;

  const ClientsPage({
    super.key,
    required this.activeClientId,
    required this.onClientsUpdated,
    required this.onUseMeHabibu,
    required this.onAddClient,
    required this.senderEmailForClient,
    required this.onDeleteClient,
    required this.onEditSenderEmail,
    required this.onSetActiveClient,
    required this.onShowConnectLink,
    required this.onPauseResumeClient,
    required this.onShowLimitDialog,
    required this.onPasteCv,
    required this.onEditProof,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clients').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clients', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                SizedBox(height: 40),
                Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                SizedBox(height: 16),
                Center(child: Text('Loading clients...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))),
              ],
            );
          }
          final docs = snap.data?.docs ?? [];
          final clients = docs.map((d) {
            final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
            m['id'] = d.id;
            return m;
          }).toList();
          clients.sort((a, b) {
            if ((a['id'] ?? '') == 'user') return -1;
            if ((b['id'] ?? '') == 'user') return 1;
            return 0;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => onClientsUpdated(clients));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Clients', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onUseMeHabibu,
                        icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF3B82F6)),
                        label: const Text('Use my profile', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: onAddClient,
                        icon: const Icon(Icons.person_add_outlined, size: 16, color: Color(0xFF10B981)),
                        label: const Text('Add Client', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (clients.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Habibu Armayau Isah - Freelancer - Flutter + AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('Setting up your profile...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ...clients.map((c) {
                final id = (c['id'] ?? '').toString();
                final name = (c['name'] ?? '').toString().isEmpty && id == 'user' ? 'Habibu Armayau Isah' : (c['name'] ?? '').toString();
                final type = (c['client_type'] ?? 'freelancer').toString();
                final job = (c['job_wanted'] ?? c['job'] ?? c['skill'] ?? '').toString().isEmpty && id == 'user' ? 'Flutter + AI' : (c['job_wanted'] ?? c['job'] ?? c['skill'] ?? '').toString();
                final loc = (c['location'] ?? c['place'] ?? '').toString();
                final gmailOk = c['gmail_connected'] == true;
                final isPaused = c['is_paused'] == true || (c['status'] ?? '').toString().toLowerCase() == 'paused';
                final isActive = id == activeClientId;
                final maxPerDay = c['max_per_day'] ?? 10;
                final cvLink = (c['cv_url'] ?? c['cvUrl'] ?? c['cvLink'] ?? '').toString();
                final hasCv = cvLink.isNotEmpty;
                final senderEmail = senderEmailForClient(c);
                final hasProof = (c['project_1'] ?? '').toString().isNotEmpty || (c['experience'] ?? '').toString().isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (type == 'job_seeker' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                type == 'job_seeker' ? Icons.work_outline : Icons.code_outlined,
                                size: 16,
                                color: type == 'job_seeker' ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    '${type == 'job_seeker' ? 'Job Seeker' : 'Freelancer'} - $job - $loc',
                                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)),
                                child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            if (isPaused)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)),
                                child: const Text('PAUSED', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF9CA3AF)),
                              onPressed: () => onDeleteClient(id, name),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1F2937)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  senderEmail.isNotEmpty ? 'Sending from: $senderEmail' : 'Sending from: Not configured - tap Edit',
                                  style: TextStyle(color: senderEmail.isNotEmpty ? Colors.white : const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => onEditSenderEmail(id, name, senderEmail),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!gmailOk)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF7F1D1D).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                            child: const Text(
                              'Gmail not connected. Emails for this client are paused until Gmail is connected. No other account will be used.',
                              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: gmailOk ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                gmailOk ? 'Gmail: Connected' : 'Gmail: Not Connected',
                                style: TextStyle(color: gmailOk ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                              child: Text(hasCv ? 'CV: Attached' : 'CV: Missing', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                              child: Text('Limit: $maxPerDay/day', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: hasProof ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)),
                              child: Text(
                                hasProof ? 'Proof: YES' : 'Proof: MISSING',
                                style: TextStyle(color: hasProof ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onSetActiveClient(id),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  isActive ? 'Active' : 'Set as active',
                                  style: TextStyle(color: isActive ? const Color(0xFF34D399) : Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => onShowConnectLink(id, name, senderEmail),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1a73e8),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.link, size: 15, color: Colors.white),
                                label: const Text('Gmail Connect Link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onPauseResumeClient(id, !isPaused),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF1F2937)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onShowLimitDialog(id, name, maxPerDay),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF1F2937)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Daily Limit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => onPasteCv(id, name, cvLink),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasCv ? const Color(0xFF1F2937) : const Color(0xFFF59E0B),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.link, size: 16, color: Colors.white),
                            label: Text(
                              hasCv ? 'CV Linked - Update' : 'Add CV Link (Drive)',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => onEditProof(id, name, c),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.star, size: 16, color: Colors.white),
                            label: Text(
                              hasProof ? 'Edit Proof' : 'Add Proof (Required for replies)',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
