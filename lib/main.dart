import 'dart:convert';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const CareerPilotApp());
}

class CareerPilotApp extends StatelessWidget {
  const CareerPilotApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareerPilot AI',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF111827),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1),
          ),
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final String apiKey = const String.fromEnvironment('BREVO_API_KEY');
  List events = [];
  bool loading = true;
  String error = '';
  String filter = 'All';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    setState(() {
      loading = true;
      error = '';
    });
    if (apiKey.isEmpty) {
      setState(() {
        loading = false;
      });
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('https://api.brevo.com/v3/smtp/statistics/events?limit=100&offset=0'),
        headers: {'api-key': apiKey, 'accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          events = data['events'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
      }
    } catch (_) {
      setState(() {
        loading = false;
      });
    }
  }

  int count(String type) => events.where((e) => (e['event'] ?? '').toString().toLowerCase() == type).length;

  List get filteredBrevo {
    if (filter == 'All') return events;
    return events.where((e) => (e['event'] ?? '').toString().toLowerCase() == filter.toLowerCase()).toList();
  }

  Color colorFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened':
        return const Color(0xFF10B981);
      case 'clicked':
        return const Color(0xFF3B82F6);
      case 'delivered':
        return const Color(0xFFA78BFA);
      case 'bounce':
      case 'softbounce':
      case 'hardbounce':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData iconFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened':
        return Icons.visibility_outlined;
      case 'clicked':
        return Icons.ads_click_outlined;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'bounce':
      case 'softbounce':
      case 'hardbounce':
        return Icons.error_outline;
      default:
        return Icons.mail_outline;
    }
  }

  String labelFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened':
        return 'Opened';
      case 'clicked':
        return 'Clicked';
      case 'delivered':
        return 'Delivered';
      case 'bounce':
      case 'softbounce':
      case 'hardbounce':
        return 'Bounced';
      default:
        return event;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final s = ts.toString();
    if (s.length > 16) return s.substring(0, 16).replaceAll('T', ' ');
    return s;
  }

  DateTime? _parseDate(dynamic ts) {
    if (ts == null) return null;
    try {
      if (ts is Timestamp) return ts.toDate();
      final s = ts.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  // ================= EMAIL DETAIL - TAP TO VIEW - MERGED =================
  // V39: Merges jobs_sent + jobs_sent_details
  // jobs_sent = company, email, date
  // jobs_sent_details = exact email_body, subject, why saved by new mailer.py
  // If details exist -> Exact copy. If not (old email) -> Preview template.
  String _buildEmailBody(Map<String, dynamic> j) {
    final saved = (j['email_body'] ?? j['message'] ?? j['body'] ?? j['email_text'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? 'your team').toString();
    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
    final why = (j['why'] ?? j['reason'] ?? '').toString().trim();
    final whyLine = why.isNotEmpty ? why : "I came across $company and liked what you're building - I build Flutter + AI mobile apps, dashboards and automation bots for teams like yours.";
    String roleLine = 'Flutter + AI mobile apps';
    if (jobType == 'BACKEND') roleLine = 'backend systems and APIs';
    if (jobType == 'AI' || jobType == 'LLM') roleLine = 'AI features, LLM apps and automation';
    if (jobType == 'FULLSTACK') roleLine = 'full-stack web and mobile apps';
    return "Hi $company Team,\n\n$whyLine\n\nI'm Habeeb Armaya'u, a Software Engineer. I build $roleLine, dashboards and automation bots for teams building that kind of product.\n\nI would love to help $company ship faster - whether it's a mobile app, dashboard, or internal tool.\n\nWould you be open to a quick 10-minute call this week to see if I can help?\n\nBest regards,\nHabeeb Armaya'u\nSoftware Engineer\nFlutter + AI Developer";
  }

  String _buildSubject(Map<String, dynamic> j) {
    final saved = (j['subject'] ?? j['email_subject'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? '').toString();
    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
    return "Flutter + AI Developer for $company - Can I help your team ship faster? ($jobType)";
  }

  Future<Map<String, dynamic>> _fetchMergedDetail(Map<String, dynamic> j) async {
    final merged = Map<String, dynamic>.from(j);
    // If jobs_sent already has body, no need to fetch details
    final hasBody = (merged['email_body'] ?? merged['body'] ?? '').toString().trim().isNotEmpty;
    if (hasBody) return merged;
    try {
      final company = (j['company'] ?? '').toString();
      final email = (j['email'] ?? '').toString();
      if (company.isEmpty || email.isEmpty) return merged;
      // Try exact match: company + email
      final q = await FirebaseFirestore.instance
          .collection('jobs_sent_details')
          .where('company', isEqualTo: company)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        if ((d['email_body'] ?? '').toString().trim().isNotEmpty) merged['email_body'] = d['email_body'];
        if ((d['body'] ?? '').toString().trim().isNotEmpty && merged['email_body'] == null) merged['email_body'] = d['body'];
        if ((d['subject'] ?? '').toString().trim().isNotEmpty) merged['subject'] = d['subject'];
        if ((d['why'] ?? '').toString().trim().isNotEmpty) merged['why'] = d['why'];
        return merged;
      }
      // Fallback: try company only (in case email case differs)
      final q2 = await FirebaseFirestore.instance
          .collection('jobs_sent_details')
          .where('company', isEqualTo: company)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final d = q2.docs.first.data();
        if ((d['email_body'] ?? '').toString().trim().isNotEmpty) merged['email_body'] = d['email_body'];
        if ((d['subject'] ?? '').toString().trim().isNotEmpty) merged['subject'] = d['subject'];
        if ((d['why'] ?? '').toString().trim().isNotEmpty) merged['why'] = d['why'];
      }
    } catch (_) {
      // If details fetch fails, just show Preview - never crash
    }
    return merged;
  }

  void _showEmailDetail(Map<String, dynamic> j) {
    // Show loading first, then fetch exact body from jobs_sent_details
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: _fetchMergedDetail(j),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)),
            );
          }
          final merged = snap.data ?? j;
          final company = (merged['company'] ?? 'Unknown').toString();
          final email = (merged['email'] ?? '').toString();
          final jobType = (merged['job_type'] ?? 'FLUTTER').toString();
          final dateStr = _formatDate(merged['timestamp']);
          final subject = _buildSubject(merged);
          final body = _buildEmailBody(merged);
          final isReal = (merged['email_body'] ?? merged['message'] ?? merged['body'] ?? merged['email_text'] ?? '').toString().trim().isNotEmpty;
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx2, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.business_outlined, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF34D399))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow('To', email),
                        const SizedBox(height: 6),
                        _detailRow('Date', dateStr.isEmpty ? 'Unknown' : dateStr),
                        const SizedBox(height: 6),
                        _detailRow('Subject', subject),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Email Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: isReal ? const Color(0xFF064E3B) : const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)),
                        child: Text(isReal ? 'Exact copy' : 'Preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isReal ? const Color(0xFF34D399) : const Color(0xFF9CA3AF))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(body, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.6)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= FOLLOW-UP DETAIL - V40 - NEW =================
  // Reads jobs_followups - shows Exact copy of follow-up email on tap.
  // If body missing (old data), shows Preview template.
  String _buildFollowupBody(Map<String, dynamic> j) {
    final saved = (j['email_body'] ?? j['body'] ?? j['message'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? 'your team').toString();
    return "Hello $company,\n\nFollowing up on my email from a few days ago.\n\nI shared a quick idea to build a small Flutter demo showing your core product working on mobile in 1 week.\n\nIf it would be helpful, I can send the demo for your review. Just let me know.\n\nThank you for your time,\n\nHabibu Armayau Isah\nSoftware Developer (Flutter, Web, Backend & AI) | Kano, Nigeria\nPhone / WhatsApp: +234 806 539 5103";
  }

  String _buildFollowupSubject(Map<String, dynamic> j) {
    final saved = (j['subject'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? '').toString();
    return "Re: Quick idea for $company - still interested?";
  }

  void _showFollowupDetail(Map<String, dynamic> j) {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
    final dateStr = _formatDate(j['timestamp']);
    final subject = _buildFollowupSubject(j);
    final body = _buildFollowupBody(j);
    final isReal = (j['email_body'] ?? j['body'] ?? '').toString().trim().isNotEmpty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx2, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.reply_outlined, color: Color(0xFF3B82F6), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('FOLLOW-UP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('To', email),
                    const SizedBox(height: 6),
                    _detailRow('Date', dateStr.isEmpty ? 'Unknown' : dateStr),
                    const SizedBox(height: 6),
                    _detailRow('Subject', subject),
                    const SizedBox(height: 6),
                    _detailRow('Type', 'Follow-up • $jobType'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Follow-up Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isReal ? const Color(0xFF1E3A8A) : const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)),
                    child: Text(isReal ? 'Exact copy' : 'Preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isReal ? const Color(0xFF93C5FD) : const Color(0xFF9CA3AF))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(body, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.6)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
  // ================= END FOLLOW-UP DETAIL =================

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white))),
      ],
    );
  }
  // ================= END EMAIL DETAIL =================

  // ================= MANUAL REQUEST =================
  Future<void> _submitManual(String company, String email, String jobType) async {
    try {
      final cleanCompany = company.trim();
      final cleanEmail = email.trim().toLowerCase();
      await FirebaseFirestore.instance.collection('pending_jobs').add({
        'company': cleanCompany,
        'email': cleanEmail,
        'job_type': jobType,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$cleanCompany added. Your bot will process it.'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add request. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddManualDialog() {
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String jobType = 'FLUTTER';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Send Manual Email', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Company', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: companyCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Chipverse',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF090D16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Email (optional)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Leave empty and the bot will find the contact email.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'hello@company.com',
                    hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF090D16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Role Focus', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['FLUTTER', 'AI', 'BACKEND', 'FULLSTACK', 'LLM', 'HYBRID'].map((t) {
                    final active = jobType == t;
                    return GestureDetector(
                      onTap: () => setDialogState(() => jobType = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF10B981) : const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? const Color(0xFF10B981) : const Color(0xFF1F2937)),
                        ),
                        child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF9CA3AF))),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                final c = companyCtrl.text.trim();
                if (c.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a company name'), backgroundColor: Colors.red));
                  return;
                }
                final em = emailCtrl.text.trim();
                if (em.isNotEmpty && (!em.contains('@') || !em.contains('.'))) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email or leave it empty'), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx);
                _submitManual(c, em, jobType);
              },
              child: const Text('Send to Bot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Color _manualStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'sent':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'processing':
        return const Color(0xFF3B82F6);
      case 'duplicate':
      case 'bad_email':
      case 'no_email_found':
      case 'failed':
      case 'invalid':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _manualStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'sent':
        return 'Sent';
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'duplicate':
        return 'Already Sent';
      case 'bad_email':
        return 'Invalid Email';
      case 'no_email_found':
        return 'No Email Found';
      case 'failed':
        return 'Failed';
      case 'invalid':
        return 'Invalid';
      default:
        return s;
    }
  }

  // ================= GRAPH =================
  Widget _buildGraph(List<QueryDocumentSnapshot> jobDocs) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final sentMap = <String, int>{};
    final openedMap = <String, int>{};
    for (var d in days) {
      sentMap[_dayKey(d)] = 0;
      openedMap[_dayKey(d)] = 0;
    }
    for (var doc in jobDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final dt = _parseDate(data['timestamp'] ?? data['created_at']);
      if (dt == null) continue;
      final key = _dayKey(dt);
      if (sentMap.containsKey(key)) sentMap[key] = (sentMap[key] ?? 0) + 1;
    }
    for (var e in events) {
      if ((e['event'] ?? '').toString().toLowerCase() != 'opened') continue;
      final dt = _parseDate(e['date']);
      if (dt == null) continue;
      final key = _dayKey(dt);
      if (openedMap.containsKey(key)) openedMap[key] = (openedMap[key] ?? 0) + 1;
    }
    int maxVal = 1;
    for (var d in days) {
      final s = sentMap[_dayKey(d)] ?? 0;
      final o = openedMap[_dayKey(d)] ?? 0;
      if (s > maxVal) maxVal = s;
      if (o > maxVal) maxVal = o;
    }
    final totalSent7 = sentMap.values.fold(0, (a, b) => a + b);
    final totalOpened7 = openedMap.values.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Last 7 Days', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$totalSent7 sent • $totalOpened7 opened', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 16),
            Row(
              children: [
                _legendDot(const Color(0xFF10B981), 'Sent'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFF3B82F6), 'Opened'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: days.map((d) {
                  final key = _dayKey(d);
                  final s = sentMap[key] ?? 0;
                  final o = openedMap[key] ?? 0;
                  final sH = maxVal == 0 ? 0.0 : (s / maxVal) * 96.0;
                  final oH = maxVal == 0 ? 0.0 : (o / maxVal) * 96.0;
                  final isToday = _dayKey(d) == _dayKey(now);
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (s > 0 || o > 0)
                          Text('$s', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399))),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(width: 10, height: sH < 4 && s > 0 ? 4 : sH, decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 3),
                            Container(width: 10, height: oH < 4 && o > 0 ? 4 : oH, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(3))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_dayLabel(d), style: TextStyle(fontSize: 10, color: isToday ? Colors.white : const Color(0xFF9CA3AF), fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFF1F2937)),
            const SizedBox(height: 10),
            Text(
              totalSent7 == 0 ? 'No activity in the last 7 days.' : totalOpened7 == 0 ? 'Applications are being sent. Opens will show here when recipients open them.' : 'Keep sending consistently. Opens usually follow within 1-2 days.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final opened = count('opened');
    final delivered = count('delivered');
    final bounced = count('softbounce') + count('hardbounce') + count('bounce');
    final rate = events.isEmpty ? 0.0 : (opened / events.length * 100);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon.png',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CareerPilot AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
            SizedBox(height: 1),
            Text('Habeeb Armaya\'u — Software Engineer', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.normal)),
          ]),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399), letterSpacing: 0.2)),
            ]),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFF1F2937))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Send Manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: fetchEvents,
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3)),
                SizedBox(height: 2),
                Text('Your applications and email activity', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ]),
              IconButton(
                onPressed: fetchEvents,
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF9CA3AF)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFF1F2937)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('bot_status').doc('current').snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final sentToday = data?['sent_today'] ?? 0;
                final lastCompany = (data?['last_company'] ?? 'Waiting').toString();
                final lastRun = (data?['last_run'] ?? 'No recent activity').toString();
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bolt, size: 16, color: Color(0xFF10B981))),
                        const SizedBox(width: 10),
                        const Text('Bot Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.1)),
                        const Spacer(),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399), letterSpacing: 0.5))),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$sentToday', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)), const SizedBox(height: 2), const Text('Sent Today', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))])),
                        Container(width: 1, height: 35, color: const Color(0xFF1F2937)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lastCompany.length > 18 ? '${lastCompany.substring(0, 18)}...' : lastCompany, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), const Text('Last Company', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))])),
                      ]),
                      const SizedBox(height: 14),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)), const SizedBox(width: 6), Expanded(child: Text('Last activity: $lastRun', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))])),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(),
              builder: (context, jobSnap) {
                final jobsCount = jobSnap.data?.docs.length ?? 0;
                final totalSent = jobsCount > 0 ? jobsCount : events.length;
                return Column(children: [
                  Row(children: [_metric('Total Sent', '$totalSent', Icons.send_outlined, 'Applications'), const SizedBox(width: 12), _metric('Open Rate', '${rate.toStringAsFixed(1)}%', Icons.visibility_outlined, 'Engagement')]),
                  const SizedBox(height: 12),
                  Row(children: [_metric('Delivered', '$delivered', Icons.check_circle_outline, 'Successful'), const SizedBox(width: 12), _metric('Bounced', '$bounced', Icons.error_outline, 'Failed')]),
                ]);
              },
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return _buildGraph(docs);
              },
            ),
            const SizedBox(height: 24),

            const Text('Services', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _systemRow('Email Delivery (Brevo)', 'Configured'),
                  const Divider(height: 24, color: Color(0xFF1F2937)),
                  _systemRow('Application Bot', 'Running on schedule'),
                  const Divider(height: 24, color: Color(0xFF1F2937)),
                  _systemRow('Database (Firebase)', 'Connected'),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Manual Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('pending_jobs').snapshots(),
                builder: (context, s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${s.data?.docs.length ?? 0} total', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
              ),
            ]),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pending_jobs').orderBy('created_at', descending: true).limit(20).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                if (snap.hasError) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Could not load manual requests.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))));
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFF9CA3AF))), const SizedBox(height: 10), const Text('No manual requests yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)), const SizedBox(height: 4), const Text('Use Send Manual to add a company you choose.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center)])),
                    ),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final company = (j['company'] ?? 'Unknown').toString();
                    final email = (j['email'] ?? '').toString();
                    final status = (j['status'] ?? 'pending').toString();
                    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
                    final c = _manualStatusColor(status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.send_outlined, color: c, size: 16)),
                        title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(email.isEmpty ? 'Bot will find email • $jobType' : '$email • $jobType', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(_manualStatusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c))),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // ALL COMPANIES - TAPPABLE
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('All Companies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(),
                builder: (context, s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${s.data?.docs.length ?? 0} total • Tap to view email', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search company or email...',
                hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
                }
                var docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, size: 24, color: Color(0xFF9CA3AF))), const SizedBox(height: 12), const Text('No applications sent yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)), const SizedBox(height: 4), const Text('Applications you send will appear here.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center)])),
                    ),
                  );
                }
                docs.sort((a, b) {
                  final ad = (a.data() as Map<String, dynamic>)['timestamp']?.toString() ?? '';
                  final bd = (b.data() as Map<String, dynamic>)['timestamp']?.toString() ?? '';
                  return bd.compareTo(ad);
                });
                if (searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final c = (j['company'] ?? '').toString().toLowerCase();
                    final e = (j['email'] ?? '').toString().toLowerCase();
                    return c.contains(searchQuery) || e.contains(searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No company found.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
                }
                return Column(
                  children: docs.map((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final company = (j['company'] ?? 'Unknown').toString();
                    final email = (j['email'] ?? '').toString();
                    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
                    final shortDate = _formatDate(j['timestamp']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                      child: ListTile(
                        onTap: () => _showEmailDetail(j),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.send_outlined, color: Color(0xFF10B981), size: 16)),
                        title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text('$email • $shortDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399)))),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ================= FOLLOW-UPS - V40 - NEW =================
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Follow-ups', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jobs_followups').snapshots(),
                builder: (context, s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${s.data?.docs.length ?? 0} total • Tap to view follow-up', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
              ),
            ]),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_followups').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF3B82F6), strokeWidth: 2)));
                }
                var docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.reply_outlined, size: 22, color: Color(0xFF9CA3AF))), const SizedBox(height: 10), const Text('No follow-ups sent yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)), const SizedBox(height: 4), const Text('Bot sends 1 professional follow-up 3 days after 1st email.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center)])),
                    ),
                  );
                }
                docs.sort((a, b) {
                  final ad = (a.data() as Map<String, dynamic>)['timestamp']?.toString() ?? '';
                  final bd = (b.data() as Map<String, dynamic>)['timestamp']?.toString() ?? '';
                  return bd.compareTo(ad);
                });
                // Apply same search filter as All Companies
                if (searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final c = (j['company'] ?? '').toString().toLowerCase();
                    final e = (j['email'] ?? '').toString().toLowerCase();
                    return c.contains(searchQuery) || e.contains(searchQuery);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No follow-up found.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
                }
                return Column(
                  children: docs.map((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final company = (j['company'] ?? 'Unknown').toString();
                    final email = (j['email'] ?? '').toString();
                    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
                    final shortDate = _formatDate(j['timestamp']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                      child: ListTile(
                        onTap: () => _showFollowupDetail(j),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_outlined, color: Color(0xFF3B82F6), size: 16)),
                        title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text('$email • $shortDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text('FOLLOW-UP', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF60A5FA)))),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            // ================= END FOLLOW-UPS =================

            const SizedBox(height: 24),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Email Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
              Text('${filteredBrevo.length} events', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Opened', 'Delivered', 'Clicked', 'Bounce'].map((f) {
                  final active = filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => filter = f),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: active ? Colors.white : const Color(0xFF111827), borderRadius: BorderRadius.circular(8), border: Border.all(color: active ? Colors.white : const Color(0xFF1F2937))), child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.black : const Color(0xFF9CA3AF)))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            if (filteredBrevo.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Column(children: [Icon(Icons.mail_outline, size: 24, color: Color(0xFF6B7280)), SizedBox(height: 8), Text('No email activity yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)), SizedBox(height: 2), Text('Opens and clicks will appear here when available.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center)])),
                ),
              )
            else
              ...filteredBrevo.take(10).map((e) {
                final ev = (e['event'] ?? 'unknown').toString();
                final email = e['email'] ?? 'Unknown recipient';
                final subject = e['subject'] ?? 'No subject';
                final date = (e['date'] ?? '').toString();
                final shortDate = date.length > 16 ? date.substring(0, 16).replaceAll('T', ' ') : date;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colorFor(ev).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(iconFor(ev), color: colorFor(ev), size: 16)),
                    title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text('$subject • $shortDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                    trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: colorFor(ev).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(labelFor(ev), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorFor(ev)))),
                  ),
                );
              }),

            const SizedBox(height: 32),
            const Center(child: Text('CareerPilot AI', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.2))),
          ]),
        ),
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, String subtitle) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: const Color(0xFF9CA3AF))), const Spacer(), const Icon(Icons.trending_up, size: 14, color: Color(0xFF10B981))]),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
        ),
      ),
    );
  }

  Widget _systemRow(String label, String status) {
    return Row(children: [
      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.white))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)), child: Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500))),
    ]);
  }
}
