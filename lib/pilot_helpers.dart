import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PilotHelpers {
  static const String hfSpaceUrl = 'https://iharmayau-habeeb-job-bot.hf.space/';

  static const List<String> recruiterWords = [
    'recruitment', 'recruiting', 'recruiter', 'staffing', 'headhunter',
    'executive search', 'talent agency', 'talent acquisition',
    'placement agency', 'job agency', 'employment agency', 'job board',
    'recruitment agency', 'recruitment firm', 'workforce', 'manpower'
  ];

  static bool isRecruiterName(String company) {
    final c = company.toLowerCase();
    return recruiterWords.any((w) => c.contains(w));
  }

  static String normalizeSkill(String raw) {
    final s = raw.trim();
    return s.isEmpty ? 'FLUTTER' : s.toUpperCase();
  }

  static String skillDisplay(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Flutter';
    final up = s.toUpperCase();
    if (up == 'FLUTTER') return 'Flutter';
    if (up == 'BACKEND') return 'Backend';
    if (up == 'AI' || up == 'LLM') return 'AI';
    if (up == 'FULLSTACK') return 'Full-Stack';
    return s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  static String roleLineForSkill(String rawSkill) {
    final s = rawSkill.trim().toUpperCase();
    if (s == 'FLUTTER') return 'Flutter + AI mobile apps';
    if (s == 'BACKEND') return 'backend systems and APIs';
    if (s == 'AI' || s == 'LLM') return 'AI features, LLM apps and automation';
    if (s == 'FULLSTACK') return 'full-stack web and mobile apps';
    if (s.isEmpty) return 'Flutter + AI mobile apps';
    return skillDisplay(rawSkill);
  }

  static String clientSlug(String name) {
    var s = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'client_${DateTime.now().millisecondsSinceEpoch}' : s;
  }

  static String clientDisplayName(Map<String, dynamic> j) =>
      (j['name'] ?? j['client_name'] ?? 'Unknown').toString();

  static String senderEmailForClient(Map<String, dynamic> c) =>
      (c['email'] ?? c['gmail'] ?? c['gmail_email'] ?? '').toString().trim();

  static bool matchesClientFilter(
    Map<String, dynamic> j,
    String selectedClientFilter,
    List<Map<String, dynamic>> clientsCache,
  ) {
    if (selectedClientFilter == 'All') return true;
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final f = selectedClientFilter.toLowerCase();
    final match = clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    final name = match.isNotEmpty ? (match.first['name'] ?? '').toString().toLowerCase() : f;
    return cn == name || cid == f || cn == f;
  }

  static bool matchesManualFilter(
    Map<String, dynamic> j,
    String selectedClientFilter,
    List<Map<String, dynamic>> clientsCache,
  ) {
    if (selectedClientFilter == 'All') return true;
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final f = selectedClientFilter.toLowerCase();
    if (cid == f || cn == f) return true;
    final match = clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    return match.isNotEmpty && cn == (match.first['name'] ?? '').toString().toLowerCase();
  }

  static String cleanPhone(dynamic raw) =>
      raw == null ? '' : raw.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

  static String phoneDigits(String phone) {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return '';
    final hasPlus = cleaned.startsWith('+');
    var digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (!hasPlus && digits.startsWith('0') && digits.length == 11) {
      digits = '234${digits.substring(1)}';
    }
    return digits;
  }

  static String whatsAppMessage(String company, {Map<String, dynamic>? client}) {
    final name = company.trim().isEmpty ? 'there' : company.trim();
    if ((client?['client_type'] ?? '').toString() == 'job_seeker') {
      final job = (client?['job_wanted'] ?? client?['job'] ?? client?['skill'] ?? 'the position').toString();
      return 'Hello $name team, I recently sent an email regarding the $job position. I would appreciate any update when convenient. My CV was attached to the email.';
    }
    return 'Hello $name team, I recently sent an email regarding a Flutter demo showing how your product can work on mobile within one week. I would be glad to discuss it further.';
  }

  static Future<void> copyPhone(BuildContext context, String phone) async {
    final clean = cleanPhone(phone);
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number copied: $clean'), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 2)),
      );
    }
  }

  static Future<void> copyText(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  static Future<void> openWhatsApp(BuildContext context, String phone, String company, {Map<String, dynamic>? client}) async {
    final digits = phoneDigits(phone);
    if (digits.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number for WhatsApp.'), backgroundColor: Colors.red));
      return;
    }
    final text = Uri.encodeComponent(whatsAppMessage(company, client: client));
    final uri = Uri.parse('https://wa.me/$digits?text=$text');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.red));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error launching WhatsApp.'), backgroundColor: Colors.red));
    }
  }

  static String formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final s = ts.toString();
    return s.length > 16 ? s.substring(0, 16).replaceAll('T', ' ') : s;
  }

  static DateTime? parseDate(dynamic ts) {
    if (ts == null) return null;
    try {
      if (ts is Timestamp) return ts.toDate();
      final s = ts.toString();
      return s.isEmpty ? null : DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  static Color manualStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'sent': return const Color(0xFF10B981);
      case 'pending': case 'processing': return const Color(0xFFF59E0B);
      case 'failed': case 'bad_email': case 'no_email_found':
      case 'blocked_recruiter': case 'blocked_irrelevant': case 'blocked_no_gmail':
        return const Color(0xFFEF4444);
      case 'duplicate': return const Color(0xFF3B82F6);
      default: return const Color(0xFF9CA3AF);
    }
  }

  static String manualStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'processing': return 'Sending';
      case 'sent': return 'Sent';
      case 'failed': return 'Failed';
      case 'bad_email': return 'Invalid email';
      case 'no_email_found': return 'No email found';
      case 'duplicate': return 'Duplicate';
      case 'blocked_recruiter': return 'Not sent - Recruitment agency';
      case 'blocked_irrelevant': return 'Not sent - Not relevant';
      case 'blocked_no_gmail': return 'Not sent - Gmail required';
      case 'paused': return 'Paused';
      default: return s;
    }
  }

  static String buildEmailBody(Map<String, dynamic> j) {
    final saved = (j['email_body'] ?? j['message'] ?? j['body'] ?? j['email_text'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? 'your team').toString();
    final jobType = (j['job_type'] ?? j['skill'] ?? 'FLUTTER').toString();
    final why = (j['why'] ?? j['reason'] ?? '').toString().trim();
    final clientType = (j['client_type'] ?? '').toString();
    final clientName = (j['client_name'] ?? 'Habeeb').toString();
    final proofUsed = (j['proof_used'] ?? j['project_1'] ?? '').toString().trim();
    if (clientType == 'job_seeker') {
      final job = (j['job_wanted'] ?? j['job'] ?? jobType).toString();
      return "Dear Hiring Manager at $company,\n\nMy name is $clientName. I am applying for the $job position at $company.\n\n${why.isNotEmpty ? why : 'I saw $company is hiring and I am interested in the $job role. I am available immediately.'}${proofUsed.isNotEmpty ? '\n\nMy work: $proofUsed' : ''}\n\nI have attached my CV for your review. I would be grateful for an opportunity to discuss how I can contribute to your team.\n\nThank you for your time.\n\nKind regards,\n$clientName\n$job";
    }
    final skillDisp = skillDisplay(jobType);
    final roleLine = roleLineForSkill(jobType);
    final whyLine = why.isNotEmpty ? why : "I came across $company and liked what you're building - I help teams with $skillDisp, and I can support your team with that.";
    return "Hi $company Team,\n\n$whyLine\n\nI'm Habeeb Armaya'u, a Software Engineer. I help teams with $roleLine, dashboards and automation for teams building that kind of product.\n\nI would love to help $company ship faster - whether it's $skillDisp, a mobile app, dashboard, or internal tool.\n\nWould you be open to a quick 10-minute call this week to see if I can help?\n\nBest regards,\nHabeeb Armaya'u\nSoftware Engineer\n$skillDisp Developer";
  }

  static String buildSubject(Map<String, dynamic> j) {
    final saved = (j['subject'] ?? j['email_subject'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? '').toString();
    final jobType = (j['job_type'] ?? j['skill'] ?? 'FLUTTER').toString();
    if ((j['client_type'] ?? '').toString() == 'job_seeker') {
      final name = (j['client_name'] ?? 'Applicant').toString();
      return "Application for $jobType at $company - $name";
    }
    return "${skillDisplay(jobType)} Developer for $company - Can I help your team ship faster? ($jobType)";
  }

  static Future<Map<String, dynamic>> fetchMergedDetail(Map<String, dynamic> j) async {
    final merged = Map<String, dynamic>.from(j);
    final hasBody = (merged['email_body'] ?? merged['body'] ?? '').toString().trim().isNotEmpty;
    final hasPhone = cleanPhone(merged['phone']).isNotEmpty;
    if (hasBody && hasPhone) return merged;
    try {
      final company = (j['company'] ?? '').toString();
      final email = (j['email'] ?? '').toString();
      if (company.isEmpty && email.isEmpty) return merged;
      final q = (company.isNotEmpty && email.isNotEmpty)
          ? await FirebaseFirestore.instance.collection('jobs_sent_details').where('company', isEqualTo: company).where('email', isEqualTo: email).limit(1).get()
          : await FirebaseFirestore.instance.collection('jobs_sent_details').where('company', isEqualTo: company).limit(1).get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        if (!hasBody) {
          if ((d['email_body'] ?? '').toString().trim().isNotEmpty) merged['email_body'] = d['email_body'];
          if ((d['subject'] ?? '').toString().trim().isNotEmpty) merged['subject'] = d['subject'];
          if ((d['why'] ?? '').toString().trim().isNotEmpty) merged['why'] = d['why'];
        }
        if (!hasPhone && cleanPhone(d['phone']).isNotEmpty) merged['phone'] = cleanPhone(d['phone']);
      }
    } catch (_) {}
    return merged;
  }

  static Future<void> whatsAppReport(Map<String, dynamic> j) async {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final date = formatDate(j['timestamp']);
    final clientName = (j['client_name'] ?? '').toString();
    final report = 'CareerPilot AI Report\n\nCompany: $company\nEmail: $email\nDate: ${date.isEmpty ? 'Unknown' : date}${clientName.isNotEmpty ? '\nClient: $clientName' : ''}';
    await Share.share(report, subject: 'CareerPilot Report - $company');
  }

  static Future<void> exportSingleEmailPdf(Map<String, dynamic> j) async {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final phone = cleanPhone(j['phone']).isNotEmpty ? cleanPhone(j['phone']) : 'Not available';
    final website = (j['website'] ?? j['company_website'] ?? '').toString().isNotEmpty ? (j['website'] ?? j['company_website']).toString() : 'Not available';
    final date = formatDate(j['timestamp']);
    final subject = buildSubject(j);
    final body = buildEmailBody(j);
    final replyStatus = (j['reply_status'] ?? j['status'] ?? 'No reply yet').toString();
    final clientName = (j['client_name'] ?? '').toString();
    final sender = (j['sender_email'] ?? j['from_email'] ?? '').toString();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text('CareerPilot AI - Email Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Professional proof of email sent', style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.Border.circular(8)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Website: $website', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Date Sent: ${date.isEmpty ? 'Unknown' : date}', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Subject: $subject', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Reply Status: $replyStatus', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (clientName.isNotEmpty) pw.Text('Client: $clientName', style: const pw.TextStyle(fontSize: 12)),
                if (sender.isNotEmpty) pw.Text('From: $sender', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Email Message', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.Border.circular(8)),
            child: pw.Text(body, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'CareerPilot_${company.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf', mimeType: 'application/pdf')],
      text: 'CareerPilot AI - Email Report for $company',
    );
  }

  static Future<void> exportAllEmailsPdf(String selectedClientFilter, List<Map<String, dynamic>> clientsCache) async {
    final snap = await FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).get();
    final docs = snap.docs.where((d) => matchesClientFilter(d.data(), selectedClientFilter, clientsCache)).toList();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text('CareerPilot AI - All Emails Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Total Emails: ${docs.length}', style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 16),
          ...docs.map((d) {
            final j = d.data();
            final company = (j['company'] ?? 'Unknown').toString();
            final email = (j['email'] ?? '').toString();
            final phone = cleanPhone(j['phone']).isNotEmpty ? cleanPhone(j['phone']) : 'Not available';
            final website = (j['website'] ?? '').toString().isNotEmpty ? (j['website']).toString() : 'Not available';
            final date = formatDate(j['timestamp']);
            final subject = buildSubject(j);
            final rs = (j['reply_status'] ?? 'No reply yet').toString();
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.Border.circular(8)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(company, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Website: $website', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Date Sent: ${date.isEmpty ? 'Unknown' : date}', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Subject: $subject', style: const pw.TextStyle(fontSize: 11)),
                  pw.Text('Reply Status: $rs', style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
    final bytes = await doc.save();
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: 'CareerPilot_All_Emails.pdf', mimeType: 'application/pdf')],
      text: 'CareerPilot AI - All Emails Report',
    );
  }
}
