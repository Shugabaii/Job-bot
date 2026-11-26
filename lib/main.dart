import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareerPilot AI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = '';
  String filter = 'All';
  String _activeClientId = 'user';

  // Hide / Show messages per client - default HIDDEN
  final Map<String, bool> _expanded = {};
  // Email filter per client - All / Replied / No Reply / Sent
  final Map<String, String> _emailFilter = {};

  String _cleanPhone(dynamic v) {
    if (v == null) return '';
    return v.toString().replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime d;
      if (ts is Timestamp) {
        d = ts.toDate();
      } else if (ts is String) {
        d = DateTime.parse(ts);
      } else {
        return ts.toString();
      }
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  String _buildSubject(Map<String, dynamic> j) {
    final comp = (j['company'] ?? 'Unknown').toString();
    return 'Application - $comp';
  }

  bool _isExpanded(String id) => _expanded[id] ?? false;
  String _emailFilterFor(String id) => _emailFilter[id] ?? 'All';

  void _toggleExpanded(String id) {
    setState(() {
      _expanded[id] = !(_expanded[id] ?? false);
    });
  }

  // ============ WHATSAPP ============
  Future<void> _openWhatsApp(Map<String, dynamic> data) async {
    final phone = _cleanPhone(data['phone']);
    final name = (data['name'] ?? 'there').toString();
    final company = (data['company'] ?? '').toString();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this client'), backgroundColor: Colors.red),
      );
      return;
    }
    final msg = Uri.encodeComponent('Hi $name, this is CareerPilot AI regarding $company.');
    final uri = Uri.parse('https://wa.me/$phone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ============ DELETE ============
  Future<void> _deleteClient(String clientId, String name) async {
    if (clientId == 'user') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete own profile.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    final cc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Permanently delete profile, Gmail, CV. Cannot undo.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Type DELETE to confirm:',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cc,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF090D16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1F2937)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (cc.text.trim().toUpperCase() != 'DELETE') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Type DELETE to confirm.'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('clients').doc(clientId).delete();
      try {
        await FirebaseFirestore.instance.collection('gmail_connected').doc(clientId).delete();
      } catch (_) {}
      if (_activeClientId == clientId) {
        try {
          await FirebaseFirestore.instance.collection('bot_config').doc('active').delete();
        } catch (_) {}
        if (mounted) setState(() => _activeClientId = 'user');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted.'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============ PDF - SINGLE CLIENT ============
  Future<void> _exportClientPdf(String clientId, Map<String, dynamic> client) async {
    final jobsSnap = await FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('jobs')
        .orderBy('timestamp', descending: true)
        .get();

    final jobs = jobsSnap.docs.map((d) => d.data()).toList();
    final name = (client['name'] ?? 'Client').toString();
    final email = (client['email'] ?? '').toString();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return [
            pw.Text('CareerPilot AI - Client Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Client: $name', style: const pw.TextStyle(fontSize: 13)),
            pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 13)),
            pw.Text('Total Emails: ${jobs.length}', style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 16),
            if (jobs.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text('No emails sent yet.', style: const pw.TextStyle(fontSize: 12)),
              )
            else
              ...jobs.asMap().entries.map((e) {
                final idx = e.key + 1;
                final j = e.value;
                final comp = (j['company'] ?? 'Unknown').toString();
                final em = (j['email'] ?? '').toString();
                final phone = _cleanPhone(j['phone']).isNotEmpty ? _cleanPhone(j['phone']) : 'Not available';
                final web = (j['website'] ?? '').toString().isNotEmpty ? (j['website'] ?? '').toString() : 'Not available';
                final date = _formatDate(j['timestamp']);
                final sd = date.isNotEmpty ? date.split(' ').first : 'Unknown';
                final subj = (j['subject'] ?? _buildSubject(j)).toString();
                final rs = (j['reply_status'] ?? 'No reply yet').toString();
                final isR = rs == 'Replied';
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text('$idx. $comp', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: pw.BoxDecoration(
                              color: isR ? PdfColors.green50 : PdfColors.grey100,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Text(rs, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isR ? PdfColors.green900 : PdfColors.grey700)),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text('Email: $em', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Website: $web', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Date Sent: $sd', style: const pw.TextStyle(fontSize: 11)),
                      pw.Text('Subject: $subj', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }),
          ];
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // ============ PDF - ALL CLIENTS ============
  Future<void> _exportAllPdf(List<QueryDocumentSnapshot<Map<String, dynamic>>> clients) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) {
          return [
            pw.Text('CareerPilot AI - All Clients Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Total Clients: ${clients.length}', style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 16),
            ...clients.map((c) {
              final d = c.data();
              final name = (d['name'] ?? 'Unknown').toString();
              final email = (d['email'] ?? '').toString();
              final phone = _cleanPhone(d['phone']).isNotEmpty ? _cleanPhone(d['phone']) : 'Not available';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );
    final bytes = await doc.save();
    await Share.shareXFiles([XFile.fromData(bytes, name: 'careerpilot_all_clients.pdf', mimeType: 'application/pdf')], text: 'CareerPilot AI - All Clients');
  }

  // ============ CLIENT CARD ============
  Widget _buildClientCard(String clientId, Map<String, dynamic> data) {
    final name = (data['name'] ?? 'Unknown').toString();
    final email = (data['email'] ?? '').toString();
    final phone = _cleanPhone(data['phone']);
    final isActive = _activeClientId == clientId;
    final expanded = _isExpanded(clientId);
    final emailFilter = _emailFilterFor(clientId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF10B981),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openWhatsApp(data),
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => _exportClientPdf(clientId, data),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF Report'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2937), foregroundColor: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () => _toggleExpanded(clientId),
                icon: Icon(expanded ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(expanded ? 'Hide Messages' : 'View Messages'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              ),
              IconButton(
                onPressed: () => _deleteClient(clientId, name),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),

          // ===== HIDDEN MESSAGES SECTION - ONLY SHOWS WHEN EXPANDED =====
          if (expanded) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1F2937)),
            const Text('Messages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            // Filter chips: All / Replied / No Reply / Sent
            Wrap(
              spacing: 6,
              children: ['All', 'Replied', 'No Reply', 'Sent'].map((f) {
                final selected = emailFilter == f;
                return ChoiceChip(
                  label: Text(f, style: TextStyle(color: selected ? Colors.white : const Color(0xFF9CA3AF), fontSize: 12)),
                  selected: selected,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF1F2937),
                  onSelected: (_) => setState(() => _emailFilter[clientId] = f),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('clients').doc(clientId).collection('jobs').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10)),
                    child: const Text('No emails sent yet.', style: TextStyle(color: Color(0xFF9CA3AF))),
                  );
                }
                var jobs = snap.data!.docs.map((d) => d.data()).toList();
                // Apply email filter
                if (emailFilter == 'Replied') {
                  jobs = jobs.where((j) => (j['reply_status'] ?? '').toString() == 'Replied').toList();
                } else if (emailFilter == 'No Reply') {
                  jobs = jobs.where((j) => (j['reply_status'] ?? 'No reply yet').toString() != 'Replied').toList();
                } else if (emailFilter == 'Sent') {
                  jobs = jobs.where((j) => (j['status'] ?? 'Sent').toString() == 'Sent').toList();
                }
                if (jobs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Text('No $emailFilter emails.', style: const TextStyle(color: Color(0xFF9CA3AF))),
                  );
                }
                return Column(
                  children: jobs.map((j) {
                    final comp = (j['company'] ?? 'Unknown').toString();
                    final em = (j['email'] ?? '').toString();
                    final rs = (j['reply_status'] ?? 'No reply yet').toString();
                    final isR = rs == 'Replied';
                    final date = _formatDate(j['timestamp']);
                    final subj = (j['subject'] ?? _buildSubject(j)).toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(comp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: isR ? const Color(0xFF064E3B) : const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                                child: Text(rs, style: TextStyle(color: isR ? const Color(0xFF6EE7B7) : const Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('To: $em', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                          Text('Subject: $subj', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                          if (date.isNotEmpty) Text('Date: $date', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _toggleExpanded(clientId),
              icon: const Icon(Icons.keyboard_arrow_up, size: 16, color: Color(0xFF10B981)),
              label: const Text('Hide Messages', style: TextStyle(color: Color(0xFF10B981))),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('CareerPilot AI', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () async {
            final snap = await FirebaseFirestore.instance.collection('clients').get();
            await _exportAllPdf(snap.docs);
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { setState(() {}); },
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1F2937)),
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
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
                        onChanged: (v) => setState(() => filter = v ?? 'All'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('clients').snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Center(child: Text('No clients yet.', style: TextStyle(color: Colors.white)));
                  }
                  var docs = snap.data!.docs;
                  if (searchQuery.isNotEmpty) {
                    docs = docs.where((d) {
                      final data = d.data();
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final comp = (data['company'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery) || comp.contains(searchQuery);
                    }).toList();
                  }
                  return Column(
                    children: docs.map((d) => _buildClientCard(d.id, d.data())).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () async {
          final snap = await FirebaseFirestore.instance.collection('clients').get();
          await _exportAllPdf(snap.docs);
        },
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
    );
  }
}
