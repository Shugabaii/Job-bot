import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  String filter = 'All';
  String searchQuery = '';
  int _jobsLimit = 20;
  int _followupsLimit = 20;
  bool _showReplies = false;
  bool _showRecentEmails = false;
  bool _showFollowups = false;
  String _recentEmailFilter = 'All';
  String _selectedClientFilter = 'All';
  String _activeClientId = 'user';
  var _clientsCache = [];
  static const String _hfSpaceUrl = 'https://iharmayau-habeeb-job-bot.hf.space/';
  static const List<String> _recruiterWords = [
    'recruitment', 'recruiting', 'recruiter', 'staffing', 'headhunter',
    'executive search', 'talent agency', 'talent acquisition',
    'placement agency', 'job agency', 'employment agency', 'job board',
    'recruitment agency', 'recruitment firm', 'workforce', 'manpower'
  ];

  bool _isRecruiterName(String company) {
    final c = company.toLowerCase();
    return _recruiterWords.any((w) => c.contains(w));
  }

  String _normalizeSkill(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'FLUTTER';
    return s.toUpperCase();
  }

  String _skillDisplay(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Flutter';
    if (s.toUpperCase() == 'FLUTTER') return 'Flutter';
    if (s.toUpperCase() == 'BACKEND') return 'Backend';
    if (s.toUpperCase() == 'AI' || s.toUpperCase() == 'LLM') return 'AI';
    if (s.toUpperCase() == 'FULLSTACK') return 'Full-Stack';
    return s.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _roleLineForSkill(String rawSkill) {
    final s = rawSkill.trim().toUpperCase();
    if (s == 'FLUTTER') return 'Flutter + AI mobile apps';
    if (s == 'BACKEND') return 'backend systems and APIs';
    if (s == 'AI' || s == 'LLM') return 'AI features, LLM apps and automation';
    if (s == 'FULLSTACK') return 'full-stack web and mobile apps';
    if (s.isEmpty) return 'Flutter + AI mobile apps';
    return _skillDisplay(rawSkill);
  }

  @override
  void initState() {
    super.initState();
    _ensureDefaultUser();
    _loadActiveClient();
  }

  Future<void> _ensureDefaultUser() async {
    try {
      final ref = FirebaseFirestore.instance.collection('clients').doc('user');
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'name': 'Habibu Armayau Isah',
          'client_type': 'freelancer',
          'skill': 'Flutter + AI',
          'job': 'Flutter + AI',
          'job_wanted': 'Flutter + AI',
          'location': 'Lagos, Nigeria',
          'place': 'Lagos, Nigeria / Global',
          'email': '',
          'phone': '',
          'cv_url': '',
          'cvUrl': '',
          'cvLink': '',
          'gmail_connected': false,
          'is_paused': false,
          'status': 'active',
          'max_per_day': 10,
          'is_default_user': true,
          'created_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } else {
        final d = doc.data() ?? {};
        final name = (d['name'] ?? '').toString().trim();
        if (name.isEmpty || name.toLowerCase() == 'user' || name.toLowerCase() == 'unknown') {
          await ref.set({
            'name': 'Habibu Armayau Isah',
            'client_type': 'freelancer',
            'skill': 'Flutter + AI',
            'job': 'Flutter + AI',
            'job_wanted': 'Flutter + AI',
            'location': (d['location'] ?? 'Lagos, Nigeria').toString(),
            'place': (d['place'] ?? 'Lagos, Nigeria / Global').toString(),
          }, SetOptions(merge: true));
        } else {
          if ((d['client_type'] ?? '').toString() != 'freelancer') {
            await ref.set({'client_type': 'freelancer'}, SetOptions(merge: true));
          }
        }
      }
    } catch (_) {}
  }

  String get _activeClientDisplayName {
    if (_activeClientId == 'user') return 'Habibu Armayau Isah';
    final match = _clientsCache.where((c) => (c['id'] ?? '').toString() == _activeClientId).toList();
    if (match.isNotEmpty) {
      final n = (match.first['name'] ?? '').toString().trim();
      if (n.isNotEmpty) return n;
    }
    return _activeClientId;
  }

  Future<void> _loadActiveClient() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('bot_config').doc('active').get();
      if (doc.exists) {
        final d = doc.data() ?? {};
        if (mounted) setState(() => _activeClientId = (d['active_client_id'] ?? d['client_id'] ?? 'user').toString());
      } else {
        if (mounted) setState(() => _activeClientId = 'user');
      }
    } catch (_) {}
  }

  String _cleanPhone(dynamic raw) {
    if (raw == null) return '';
    return raw.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _phoneDigits(String phone) {
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

  String _whatsAppMessage(String company, {Map<String, dynamic>? client}) {
    final name = company.trim().isEmpty ? 'there' : company.trim();
    final type = (client?['client_type'] ?? '').toString();
    if (type == 'job_seeker') {
      final job = (client?['job_wanted'] ?? client?['job'] ?? client?['skill'] ?? 'the position').toString();
      return 'Hello $name team, I recently sent an email regarding the $job position. I would appreciate any update when convenient. My CV was attached to the email.';
    }
    return 'Hello $name team, I recently sent an email regarding a Flutter demo showing how your product can work on mobile within one week. I would be glad to discuss it further.';
  }

  Future<void> _copyPhone(String phone) async {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number copied: $clean'), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied'), backgroundColor: const Color(0xFF10B981)),
      );
    }
  }

  Future<void> _openWhatsApp(String phone, String company, {Map<String, dynamic>? client}) async {
    final digits = _phoneDigits(phone);
    if (digits.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number for WhatsApp.'), backgroundColor: Colors.red));
      return;
    }
    final text = Uri.encodeComponent(_whatsAppMessage(company, client: client));
    final uri = Uri.parse('https://wa.me/$digits?text=$text');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.red));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error launching WhatsApp.'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editSenderEmail(String clientId, String name, String currentEmail) async {
    final ctrl = TextEditingController(text: currentEmail);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Sender Email - $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type the Gmail that will show in From: for this client. Must match the Gmail you connected.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. habeeb@gmail.com',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF090D16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a valid email.'), backgroundColor: Colors.red));
                return;
              }
              await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'email': email, 'gmail': email, 'gmail_email': email}, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sender email saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _whatsAppReport(Map<String, dynamic> j) async {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final date = _formatDate(j['timestamp']);
    final clientName = (j['client_name'] ?? '').toString();
    final report = 'CareerPilot AI Report\n\nCompany: $company\nEmail: $email\nDate: ${date.isEmpty ? 'Unknown' : date}${clientName.isNotEmpty ? '\nClient: $clientName' : ''}';
    await Share.share(report, subject: 'CareerPilot Report - $company');
  }

  Future<void> _exportSingleEmailPdf(Map<String, dynamic> j) async {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final phone = _cleanPhone(j['phone']).isNotEmpty ? _cleanPhone(j['phone']) : 'Not available';
    final website = (j['website'] ?? j['company_website'] ?? '').toString().isNotEmpty ? (j['website'] ?? j['company_website']).toString() : 'Not available';
    final date = _formatDate(j['timestamp']);
    final subject = _buildSubject(j);
    final body = _buildEmailBody(j);
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
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
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
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
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

  Future<void> _exportAllEmailsPdf() async {
    final snap = await FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).get();
    final docs = snap.docs.where((d) => _matchesClientFilter(d.data())).toList();
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
            final phone = _cleanPhone(j['phone']).isNotEmpty ? _cleanPhone(j['phone']) : 'Not available';
            final website = (j['website'] ?? '').toString().isNotEmpty ? (j['website']).toString() : 'Not available';
            final date = _formatDate(j['timestamp']);
            final subject = _buildSubject(j);
            final rs = (j['reply_status'] ?? 'No reply yet').toString();
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
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

  String _clientSlug(String name) {
    var s = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) s = 'client_${DateTime.now().millisecondsSinceEpoch}';
    return s;
  }

  String _clientDisplayName(Map<String, dynamic> j) => (j['name'] ?? j['client_name'] ?? 'Unknown').toString();
  String _senderEmailForClient(Map<String, dynamic> c) => (c['email'] ?? c['gmail'] ?? c['gmail_email'] ?? '').toString().trim();

  bool _matchesClientFilter(Map<String, dynamic> j) {
    if (_selectedClientFilter == 'All') return true;
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final f = _selectedClientFilter.toLowerCase();
    final match = _clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    final name = match.isNotEmpty ? (match.first['name'] ?? '').toString().toLowerCase() : f;
    return cn == name || cid == f || cn == f;
  }

  bool _matchesManualFilter(Map<String, dynamic> j) {
    if (_selectedClientFilter == 'All') return true;
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final f = _selectedClientFilter.toLowerCase();
    if (cid == f || cn == f) return true;
    final match = _clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    if (match.isNotEmpty) {
      final name = (match.first['name'] ?? '').toString().toLowerCase();
      if (cn == name) return true;
    }
    return false;
  }

  Future<void> _setActiveClient(String clientId) async {
    try {
      await FirebaseFirestore.instance.collection('bot_config').doc('active').set({
        'active_client_id': clientId,
        'client_id': clientId,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _activeClientId = clientId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Active client updated to $clientId.'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _useMeHabibu() async {
    try {
      await _ensureDefaultUser();
      await FirebaseFirestore.instance.collection('bot_config').doc('active').delete();
      if (mounted) {
        setState(() => _activeClientId = 'user');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Active client cleared. Using your profile - Habibu Armayau Isah.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showConnectLinkDialog(String clientId, String name, String senderEmail) async {
    final link = '$_hfSpaceUrl?client=$clientId';
    final message = 'Hello $name, please connect your Gmail so your applications are sent from your own email address:\n\n$link\n\nOpen the link, select Connect Gmail, sign in with ${senderEmail.isNotEmpty ? senderEmail : "your Gmail account"}, and approve access. Until this is completed, sending for your profile will remain paused.';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Connect Gmail - $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with the client. They must sign in with their own Gmail account.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
              child: SelectableText(link, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            const Text('Message preview', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
              child: SelectableText(message, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.4)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              await _copyText(link, 'Connect link');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy Link'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              await _copyText(message, 'Message');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy Message', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteCvForClient(String clientId, String name, String currentLink) async {
    final ctrl = TextEditingController(text: currentLink);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('CV Link - $name', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Upload the CV to Google Drive\n2. Set sharing to Anyone with the link\n3. Paste the link below', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'https://drive.google.com/...',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF090D16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (currentLink.isNotEmpty)
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'cv_url': '', 'cvUrl': '', 'cvLink': ''}, SetOptions(merge: true));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CV link removed')));
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final link = ctrl.text.trim();
              if (link.isEmpty) return;
              await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
                'cv_url': link,
                'cvUrl': link,
                'cvLink': link,
                'cv_uploaded_at': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CV link saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClient(String clientId, String name) async {
    if (clientId == 'user') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot delete your own profile - Habibu Armayau Isah.'), backgroundColor: Colors.orange));
      return;
    }
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently delete the client profile, Gmail connection, and CV link. This action cannot be undone.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Type DELETE to confirm:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE',
                hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                filled: true,
                fillColor: const Color(0xFF090D16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Permanently', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    if (confirmCtrl.text.trim().toUpperCase() != 'DELETE') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please type DELETE to confirm.'), backgroundColor: Colors.red));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name has been deleted.'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pauseResumeClient(String clientId, bool pause) async {
    try {
      await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'is_paused': pause, 'status': pause ? 'paused' : 'active'}, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pause ? 'Sending paused for this client.' : 'Sending resumed for this client.'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _showLimitDialog(String clientId, String name, dynamic current) {
    final ctrl = TextEditingController(text: (current ?? 10).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Daily Limit - $name', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1-50, e.g. 5',
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            filled: true,
            fillColor: const Color(0xFF090D16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text.trim()) ?? 0;
              if (v < 1 || v > 50) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a value between 1 and 50.'), backgroundColor: Colors.red));
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'max_per_day': v}, SetOptions(merge: true));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Daily limit for $name set to $v.'), backgroundColor: const Color(0xFF10B981)));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBotSettingsDialog() {
    final maxCtrl = TextEditingController(text: '20');
    final cyclesCtrl = TextEditingController(text: '3');
    final sleepCtrl = TextEditingController(text: '6');
    final waitCtrl = TextEditingController(text: '15');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('bot_config').doc('settings').get(),
          builder: (ctx2, snap) {
            if (snap.hasData && snap.data!.exists) {
              final d = snap.data!.data() as Map<String, dynamic>;
              maxCtrl.text = (d['max_per_day'] ?? 20).toString();
              cyclesCtrl.text = (d['max_cycles_per_day'] ?? 3).toString();
              sleepCtrl.text = (d['cycle_sleep_hours'] ?? 6).toString();
              waitCtrl.text = (d['wait_between_minutes'] ?? 15).toString();
            }
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bot Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Changes apply to the next cycle. No restart is required. A client daily limit overrides the global limit.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 16),
                    _clientTextField(maxCtrl, 'Max emails per day (global) e.g. 20'),
                    const SizedBox(height: 10),
                    _clientTextField(cyclesCtrl, 'Cycles per day e.g. 3'),
                    const SizedBox(height: 10),
                    _clientTextField(sleepCtrl, 'Hours between cycles e.g. 6'),
                    const SizedBox(height: 10),
                    _clientTextField(waitCtrl, 'Minutes between each email e.g. 15'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () async {
                          try {
                            await FirebaseFirestore.instance.collection('bot_config').doc('settings').set({
                              'max_per_day': int.tryParse(maxCtrl.text.trim()) ?? 20,
                              'max_cycles_per_day': int.tryParse(cyclesCtrl.text.trim()) ?? 3,
                              'cycle_sleep_hours': int.tryParse(sleepCtrl.text.trim()) ?? 6,
                              'wait_between_minutes': int.tryParse(waitCtrl.text.trim()) ?? 15,
                            }, SetOptions(merge: true));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bot settings saved.'), backgroundColor: Color(0xFF10B981)));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddClientDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final skillCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final cvCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    final skillsCtrl = TextEditingController();
    final projectCtrl = TextEditingController();
    final projectResultCtrl = TextEditingController();
    final experienceCtrl = TextEditingController();
    String type = 'freelancer';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSB) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('Freelancer: outreach for services. Job Seeker: applications for employment.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 16),
                    _clientTextField(nameCtrl, 'Full name e.g. Amina Bello'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _typeChip('freelancer', type, (v) => setSB(() => type = v))),
                        const SizedBox(width: 8),
                        Expanded(child: _typeChip('job_seeker', type, (v) => setSB(() => type = v))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (type == 'freelancer') ...[
                      _clientTextField(skillCtrl, 'Skill e.g. Flutter + AI, Video Editing, Graphic Design'),
                      const SizedBox(height: 6),
                      const Text('Any skill is supported - e.g. Video Editing, Plumbing, Data Analysis, Welding, Copywriting.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      const SizedBox(height: 10),
                      _clientTextField(placeCtrl, 'Target market e.g. Lagos, Nigeria / Global'),
                    ] else ...[
                      _clientTextField(jobCtrl, 'Position sought e.g. Nurse, Accountant, Video Editor'),
                      const SizedBox(height: 6),
                      const Text('Any position is supported - e.g. Pharmacist, Welder, Electrician, Cleaner, Marketing Manager.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      const SizedBox(height: 10),
                      _clientTextField(locCtrl, 'Location e.g. Abuja, Kano'),
                      const SizedBox(height: 10),
                      _clientTextField(cvCtrl, 'CV link (Google Drive / PDF URL) - can be added later'),
                      const SizedBox(height: 10),
                      _clientTextField(skillCtrl, 'Qualification e.g. BSc Nursing, RN'),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF064E3B).withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PROOF - This is why companies reply (REQUIRED)', style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text('Ask client 3 questions on WhatsApp. Without proof, emails get 0 replies.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                          const SizedBox(height: 12),
                          _clientTextField(skillsCtrl, 'Q1: What tools can you use? e.g. Excel, Power BI, Python, SQL'),
                          const SizedBox(height: 10),
                          _clientTextField(projectCtrl, 'Q2: What work have you done? e.g. Analyzed sales data for small shop in Kano using Excel'),
                          const SizedBox(height: 10),
                          _clientTextField(projectResultCtrl, 'Q3: What was the result? e.g. Found which product sells best, made dashboard'),
                          const SizedBox(height: 10),
                          _clientTextField(experienceCtrl, 'Experience (optional) e.g. 2 years as Data Analyst'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _clientTextField(emailCtrl, 'Gmail address (sender) e.g. amina@gmail.com'),
                    const SizedBox(height: 6),
                    const Text('This address will appear as the sender. Each client must connect their own Gmail account. Sending will remain paused until Gmail is connected.', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                    const SizedBox(height: 10),
                    _clientTextField(phoneCtrl, 'Phone / WhatsApp e.g. +234...'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter the client name.'), backgroundColor: Colors.red));
                            return;
                          }
                          if (type == 'job_seeker' && (jobCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty)) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Job seekers require a position and location.'), backgroundColor: Colors.red));
                            return;
                          }
                          final id = _clientSlug(name);
                          try {
                            await FirebaseFirestore.instance.collection('clients').doc(id).set({
                              'name': name,
                              'client_type': type,
                              'skill': skillCtrl.text.trim(),
                              'job_wanted': jobCtrl.text.trim(),
                              'job': jobCtrl.text.trim(),
                              'location': locCtrl.text.trim(),
                              'place': type == 'freelancer' ? placeCtrl.text.trim() : locCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'cv_url': cvCtrl.text.trim(),
                              'cvUrl': cvCtrl.text.trim(),
                              'cvLink': cvCtrl.text.trim(),
                              'skills': skillsCtrl.text.trim(),
                              'project_1': projectCtrl.text.trim(),
                              'project_1_result': projectResultCtrl.text.trim(),
                              'experience': experienceCtrl.text.trim(),
                              'gmail_connected': false,
                              'is_paused': false,
                              'status': 'active',
                              'max_per_day': 10,
                              'created_at': DateTime.now().toIso8601String(),
                            }, SetOptions(merge: true));
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client $name added. Next: add the CV link and share the Gmail connect link.'), backgroundColor: const Color(0xFF10B981)));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Save Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditProofDialog(String clientId, String name, Map<String, dynamic> c) async {
    final skillsCtrl = TextEditingController(text: (c['skills'] ?? '').toString());
    final projectCtrl = TextEditingController(text: (c['project_1'] ?? c['project'] ?? '').toString());
    final resultCtrl = TextEditingController(text: (c['project_1_result'] ?? c['project_result'] ?? '').toString());
    final expCtrl = TextEditingController(text: (c['experience'] ?? '').toString());
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text('Proof - $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ask client 3 questions. This proof goes into EVERY email.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              const SizedBox(height: 12),
              _clientTextField(skillsCtrl, 'Q1: Tools? e.g. Excel, Power BI, Python'),
              const SizedBox(height: 10),
              _clientTextField(projectCtrl, 'Q2: What work did you do?'),
              const SizedBox(height: 10),
              _clientTextField(resultCtrl, 'Q3: What was the result?'),
              const SizedBox(height: 10),
              _clientTextField(expCtrl, 'Experience (optional)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
                'skills': skillsCtrl.text.trim(),
                'project_1': projectCtrl.text.trim(),
                'project_1_result': resultCtrl.text.trim(),
                'experience': expCtrl.text.trim(),
                'proof_updated_at': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proof saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save Proof', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String val, String selected, Function(String) onTap) {
    final active = val == selected;
    return GestureDetector(
      onTap: () => onTap(val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF10B981) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF10B981) : const Color(0xFF1F2937)),
        ),
        child: Text(
          val == 'freelancer' ? 'Freelancer' : 'Job Seeker',
          style: TextStyle(color: active ? Colors.white : const Color(0xFF9CA3AF), fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  Widget _clientTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF090D16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _collapsibleHeader(String title, bool expanded, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
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

  Widget _clientsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final clients = docs.map((d) {
          final m = d.data() as Map<String, dynamic>;
          m['id'] = d.id;
          return m;
        }).toList();
        clients.sort((a, b) {
          if ((a['id'] ?? '') == 'user') return -1;
          if ((b['id'] ?? '') == 'user') return 1;
          return 0;
        });
        _clientsCache = clients;
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
                      onPressed: _useMeHabibu,
                      icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF3B82F6)),
                      label: const Text('Use my profile', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _showAddClientDialog,
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
              final isActive = id == _activeClientId;
              final maxPerDay = c['max_per_day'] ?? 10;
              final cvLink = (c['cv_url'] ?? c['cvUrl'] ?? c['cvLink'] ?? '').toString();
              final hasCv = cvLink.isNotEmpty;
              final senderEmail = _senderEmailForClient(c);
              final hasProof = (c['project_1'] ?? '').toString().isNotEmpty || (c['experience'] ?? '').toString().isNotEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937))),
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
                            decoration: BoxDecoration(color: (type == 'job_seeker' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Icon(type == 'job_seeker' ? Icons.work_outline : Icons.code_outlined, size: 16, color: type == 'job_seeker' ? const Color(0xFF60A5FA) : const Color(0xFF34D399)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('${type == 'job_seeker' ? 'Job Seeker' : 'Freelancer'} - $job - $loc', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold))),
                          if (isPaused)
                            Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)), child: const Text('PAUSED', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold))),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF9CA3AF)), onPressed: () => _deleteClient(id, name)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1F2937))),
                        child: Row(
                          children: [
                            Expanded(child: Text(senderEmail.isNotEmpty ? 'Sending from: $senderEmail' : 'Sending from: Not configured - tap Edit', style: TextStyle(color: senderEmail.isNotEmpty ? Colors.white : const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600))),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _editSenderEmail(id, name, senderEmail),
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
                          child: const Text('Gmail not connected. Emails for this client are paused until Gmail is connected. No other account will be used.', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: gmailOk ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)), child: Text(gmailOk ? 'Gmail: Connected' : 'Gmail: Not Connected', style: TextStyle(color: gmailOk ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.w600))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text(hasCv ? 'CV: Attached' : 'CV: Missing', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('Limit: $maxPerDay/day', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: hasProof ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)), child: Text(hasProof ? 'Proof: YES' : 'Proof: MISSING', style: TextStyle(color: hasProof ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _setActiveClient(id),
                              style: OutlinedButton.styleFrom(side: BorderSide(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: Text(isActive ? 'Active' : 'Set as active', style: TextStyle(color: isActive ? const Color(0xFF34D399) : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showConnectLinkDialog(id, name, senderEmail),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a73e8), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
                              onPressed: () => _pauseResumeClient(id, !isPaused),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showLimitDialog(id, name, maxPerDay),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              child: const Text('Daily Limit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _pasteCvForClient(id, name, cvLink),
                          style: ElevatedButton.styleFrom(backgroundColor: hasCv ? const Color(0xFF1F2937) : const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          icon: const Icon(Icons.link, size: 16, color: Colors.white),
                          label: Text(hasCv ? 'CV Linked - Update' : 'Add CV Link (Drive)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showEditProofDialog(id, name, c),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          icon: const Icon(Icons.star, size: 16, color: Colors.white),
                          label: Text(hasProof ? 'Edit Proof' : 'Add Proof (Required for replies)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
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

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, color: Colors.white))),
      ],
    );
  }

  String _buildEmailBody(Map<String, dynamic> j) {
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
    final skillDisp = _skillDisplay(jobType);
    final roleLine = _roleLineForSkill(jobType);
    final whyLine = why.isNotEmpty ? why : "I came across $company and liked what you're building - I help teams with $skillDisp, and I can support your team with that.";
    return "Hi $company Team,\n\n$whyLine\n\nI'm Habeeb Armaya'u, a Software Engineer. I help teams with $roleLine, dashboards and automation for teams building that kind of product.\n\nI would love to help $company ship faster - whether it's $skillDisp, a mobile app, dashboard, or internal tool.\n\nWould you be open to a quick 10-minute call this week to see if I can help?\n\nBest regards,\nHabeeb Armaya'u\nSoftware Engineer\n$skillDisp Developer";
  }

  String _buildSubject(Map<String, dynamic> j) {
    final saved = (j['subject'] ?? j['email_subject'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? '').toString();
    final jobType = (j['job_type'] ?? j['skill'] ?? 'FLUTTER').toString();
    if ((j['client_type'] ?? '').toString() == 'job_seeker') {
      final name = (j['client_name'] ?? 'Applicant').toString();
      return "Application for $jobType at $company - $name";
    }
    final skillDisp = _skillDisplay(jobType);
    return "$skillDisp Developer for $company - Can I help your team ship faster? ($jobType)";
  }

  Future _fetchMergedDetail(Map j) async {
    final merged = Map<String, dynamic>.from(j);
    final hasBody = (merged['email_body'] ?? merged['body'] ?? '').toString().trim().isNotEmpty;
    final hasPhone = _cleanPhone(merged['phone']).isNotEmpty;
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
        if (!hasPhone && _cleanPhone(d['phone']).isNotEmpty) merged['phone'] = _cleanPhone(d['phone']);
        return merged;
      }
    } catch (_) {}
    return merged;
  }

  Widget _phoneActionCard(String phone, String company, {Map<String, dynamic>? client}) {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text('Phone', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(child: SelectableText(clean, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600))),
              IconButton(tooltip: 'Copy number', onPressed: () => _copyPhone(clean), icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF9CA3AF)), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _openWhatsApp(clean, company, client: client),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16),
                  label: const Text('WhatsApp Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => _copyPhone(clean),
                icon: const Icon(Icons.copy, color: Color(0xFF9CA3AF), size: 15),
                label: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEmailDetail(Map<String, dynamic> j) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder(
          future: _fetchMergedDetail(j),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
            }
            final merged = snap.data ?? j;
            final company = (merged['company'] ?? 'Unknown').toString();
            final email = (merged['email'] ?? '').toString();
            final clientPhonesHere = _clientsCache.map((c) => _cleanPhone(c['phone'])).where((p) => p.isNotEmpty).toSet();
            final phone = clientPhonesHere.contains(_cleanPhone(merged['phone'])) ? '' : _cleanPhone(merged['phone']);
            final jobType = (merged['job_type'] ?? 'FLUTTER').toString();
            final dateStr = _formatDate(merged['timestamp']);
            final subject = _buildSubject(merged);
            final body = _buildEmailBody(merged);
            final isReal = (merged['email_body'] ?? merged['message'] ?? merged['body'] ?? merged['email_text'] ?? '').toString().trim().isNotEmpty;
            final senderDisplay = (merged['sender_email'] ?? merged['from_email'] ?? '').toString().trim();
            final clientForWhatsApp = _clientsCache.where((c) => (c['name'] ?? '').toString() == (merged['client_name'] ?? '').toString()).toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (ctx2, scrollCtrl) {
                return SingleChildScrollView(
                  controller: scrollCtrl,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_outlined, color: Color(0xFF10B981), size: 20)),
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
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF34D399)))),
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
                            if ((merged['client_name'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _detailRow('Client', (merged['client_name'] ?? '').toString()),
                            ],
                            if (senderDisplay.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _detailRow('From', senderDisplay),
                            ],
                          ],
                        ),
                      ),
                      _phoneActionCard(phone, company, client: clientForWhatsApp.isNotEmpty ? clientForWhatsApp.first : null),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                        child: SelectableText(body, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.5)),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _copyText('Subject: $subject\n\n$body', 'Email'), icon: const Icon(Icons.copy, size: 15), label: const Text('Copy Email'))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _whatsAppReport(merged),
                              icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                              label: const Text('WhatsApp Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _exportSingleEmailPdf(merged),
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                              label: const Text('PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      // V76 REMOVED: Unprofessional note below buttons - deleted
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFollowupDetail(Map<String, dynamic> j) {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final body = (j['email_body'] ?? j['body'] ?? 'Follow-up sent 3 days after first email.').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                child: SelectableText(body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showAddManualDialog() {
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final customSkillCtrl = TextEditingController();
    String jobType = 'FLUTTER';
    String selectedClient = _activeClientId;
    final jobTypes = ['FLUTTER', 'BACKEND', 'AI', 'LLM', 'FULLSTACK', 'NURSE', 'ACCOUNTANT', 'TEACHER', 'DRIVER', 'CHEF', 'CUSTOM'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSB) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Send Manually', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text('If no email is provided, the bot will attempt to find one, then send for the selected client. Any skill is supported.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    const SizedBox(height: 14),
                    _clientTextField(companyCtrl, 'Company / Hospital e.g. Nizamiye Hospital'),
                    const SizedBox(height: 10),
                    _clientTextField(emailCtrl, 'Email (optional - bot will find if empty)'),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _clientsCache.any((c) => (c['id'] ?? '') == selectedClient) ? selectedClient : null,
                      decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      dropdownColor: const Color(0xFF111827),
                      style: const TextStyle(color: Colors.white),
                      hint: const Text('Select Client', style: TextStyle(color: Color(0xFF6B7280))),
                      items: _clientsCache.map((c) => DropdownMenuItem<String>(value: (c['id'] ?? '').toString(), child: Text('${c['name']} (${c['client_type']})', style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setSB(() => selectedClient = v ?? _activeClientId),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: jobType,
                      decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                      dropdownColor: const Color(0xFF111827),
                      style: const TextStyle(color: Colors.white),
                      items: jobTypes.map((j) => DropdownMenuItem(value: j, child: Text(j == 'CUSTOM' ? 'Other / Custom Skill' : j, style: const TextStyle(color: Colors.white)))).toList(),
                      onChanged: (v) => setSB(() => jobType = v ?? 'FLUTTER'),
                    ),
                    if (jobType == 'CUSTOM') ...[
                      const SizedBox(height: 10),
                      _clientTextField(customSkillCtrl, 'Enter custom skill e.g. Video Editing, Graphic Design, Welding'),
                      const SizedBox(height: 6),
                      const Text('Any skill is supported. The bot will use this skill to find and contact relevant companies.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () async {
                          final company = companyCtrl.text.trim();
                          if (company.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a company name.'), backgroundColor: Colors.red));
                            return;
                          }
                          String finalSkill = jobType;
                          if (jobType == 'CUSTOM') {
                            if (customSkillCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a custom skill.'), backgroundColor: Colors.red));
                              return;
                            }
                            finalSkill = _normalizeSkill(customSkillCtrl.text);
                          }
                          if (_isRecruiterName(company)) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: const Color(0xFF111827),
                                title: const Text('Recruitment Agency Detected', style: TextStyle(color: Colors.white)),
                                content: Text('"$company" appears to be a recruitment or staffing agency.\n\nCareerPilot only contacts direct employers. This request will be marked as not sent.\n\nDo you still want to queue it?', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Queue Anyway', style: TextStyle(color: Colors.orange))),
                                ],
                              ),
                            );
                            if (proceed != true || !mounted) return;
                          }
                          final selClient = _clientsCache.where((c) => (c['id'] ?? '').toString() == selectedClient).toList();
                          if (selClient.isNotEmpty && selClient.first['gmail_connected'] != true) {
                            final proceed2 = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: const Color(0xFF111827),
                                title: const Text('Gmail Not Connected', style: TextStyle(color: Colors.white)),
                                content: Text('${selClient.first['name']} has not connected Gmail.\n\nSending for this client will remain paused until Gmail is connected. No other account will be used.\n\nQueue anyway? It will be recorded as not sent - Gmail required.', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Queue Anyway', style: TextStyle(color: Colors.orange))),
                                ],
                              ),
                            );
                            if (proceed2 != true || !mounted) return;
                          }
                          try {
                            final clientName = selClient.isNotEmpty ? (selClient.first['name'] ?? '').toString() : '';
                            await FirebaseFirestore.instance.collection('pending_jobs').add({
                              'company': company,
                              'email': emailCtrl.text.trim(),
                              'job_type': finalSkill,
                              'skill': finalSkill,
                              'custom_skill': jobType == 'CUSTOM',
                              'client_id': selectedClient,
                              'client_name': clientName,
                              'status': 'pending',
                              'created_at': DateTime.now().toIso8601String(),
                              'timestamp': DateTime.now().toIso8601String(),
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manual request queued for $finalSkill. The bot will process it shortly.'), backgroundColor: const Color(0xFF10B981)));
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: const Text('Queue Manual Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGraph(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final Map<String, int> perDay = {};
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      perDay[_dayKey(d)] = 0;
    }
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final dt = _parseDate(m['timestamp'] ?? m['date']);
      if (dt == null) continue;
      final k = _dayKey(dt);
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
                      Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Text(_dayLabel(DateTime.parse(e.key)), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
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
      stream: FirebaseFirestore.instance.collection('jobs_replies').snapshots(),
      builder: (context, snap) {
        final all = snap.data?.docs ?? [];
        final filtered = all.where((d) => _matchesClientFilter(d.data() as Map<String, dynamic>)).toList();
        final replies = filtered.length;
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

  Color _manualStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'sent': return const Color(0xFF10B981);
      case 'pending': case 'processing': return const Color(0xFFF59E0B);
      case 'failed': case 'bad_email': case 'no_email_found': return const Color(0xFFEF4444);
      case 'duplicate': return const Color(0xFF3B82F6);
      case 'blocked_recruiter': case 'blocked_irrelevant': case 'blocked_no_gmail': return const Color(0xFFEF4444);
      case 'paused': return const Color(0xFF9CA3AF);
      default: return const Color(0xFF9CA3AF);
    }
  }

  String _manualStatusLabel(String s) {
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

  Future<void> _showManualActions(String docId, String company, String status) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(company, style: const TextStyle(color: Colors.white)),
        content: Text('Status: ${_manualStatusLabel(status)}\n\nLong-press action:', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          if (status.toLowerCase() != 'pending' && status.toLowerCase() != 'processing')
            TextButton(onPressed: () => Navigator.pop(ctx, 'retry'), child: const Text('Retry - Set to Pending', style: TextStyle(color: Color(0xFF10B981)))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (action == 'retry') {
      try {
        await FirebaseFirestore.instance.collection('pending_jobs').doc(docId).update({'status': 'pending', 'retry_at': DateTime.now().toIso8601String(), 'error': ''});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moved back to Pending. Bot will retry.'), backgroundColor: Color(0xFF10B981)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retry failed: $e'), backgroundColor: Colors.red));
      }
    } else if (action == 'delete') {
      try {
        await FirebaseFirestore.instance.collection('pending_jobs').doc(docId).delete();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual job deleted.'), backgroundColor: Color(0xFF10B981)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showReplyDetail(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx2, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Text((r['company'] ?? 'Unknown').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text((r['email'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 4),
                  Text((r['subject'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                    child: SelectableText((r['reply_text'] ?? r['snippet'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.5)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => _whatsAppReport(r),
                          icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                          label: const Text('WhatsApp Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => _exportSingleEmailPdf(r),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                          label: const Text('PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        final email = (r['email'] ?? '').toString();
                        if (email.isNotEmpty) {
                          final uri = Uri.parse('mailto:$email?subject=Re: ${(r['subject'] ?? '').toString()}');
                          try {
                            await launchUrl(uri);
                          } catch (_) {}
                        }
                      },
                      icon: const Icon(Icons.reply, color: Colors.white, size: 16),
                      label: const Text('Reply in Gmail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _repliesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs_replies').orderBy('timestamp', descending: true).limit(20).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs.where((d) {
          final r = d.data() as Map<String, dynamic>;
          return _matchesClientFilter(r);
        }).toList();
        if (docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.reply_outlined, size: 22, color: Color(0xFF9CA3AF))),
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
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${docs.length} total - Tap to view reply', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
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
                decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
                child: ListTile(
                  onTap: () => _showReplyDetail(r),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16)),
                  title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subject.isNotEmpty ? '$subject - $email' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))),
                  trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _metric(String title, String value, IconData icon, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 14, color: const Color(0xFF10B981)), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))]),
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
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]), borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CareerPilot AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
                SizedBox(height: 1),
                Text("Habeeb Armaya'u - Software Engineer", style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Export All PDF', onPressed: _exportAllEmailsPdf, icon: const Icon(Icons.picture_as_pdf, color: Colors.white)),
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFF064E3B).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
            child: const Row(children: [Icon(Icons.circle, size: 6, color: Color(0xFF10B981)), SizedBox(width: 6), Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399)))]),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFF1F2937))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF10B981),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Send Manually', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      IconButton(onPressed: _showBotSettingsDialog, icon: const Icon(Icons.settings, size: 18, color: Color(0xFF9CA3AF)), style: IconButton.styleFrom(backgroundColor: const Color(0xFF111827), side: const BorderSide(color: Color(0xFF1F2937)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(width: 8),
                      IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF9CA3AF)), style: IconButton.styleFrom(backgroundColor: const Color(0xFF111827), side: const BorderSide(color: Color(0xFF1F2937)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('bot_status').doc('current').snapshots(),
                builder: (context, statusSnap) {
                  final data = statusSnap.data?.data() as Map<String, dynamic>?;
                  final rawCompany = (data?['last_company'] ?? '').toString().trim();
                  final lastCompany = (rawCompany.isEmpty || rawCompany.startsWith('Waiting ')) ? 'Waiting' : rawCompany;
                  final lastRun = (data?['last_run'] ?? 'No recent activity').toString();
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, sentSnap) {
                      final allDocs = sentSnap.data?.docs ?? [];
                      final filtered = allDocs.where((d) {
                        final m = d.data() as Map<String, dynamic>;
                        return _matchesClientFilter(m);
                      }).toList();
                      final totalSent = filtered.length;
                      final sentTodayFirestore = filtered.where((d) {
                        final m = d.data() as Map<String, dynamic>;
                        final dt = _parseDate(m['timestamp']);
                        return dt != null && _dayKey(dt) == _dayKey(DateTime.now());
                      }).length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2937))),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bolt, size: 16, color: Color(0xFF10B981))),
                                      const SizedBox(width: 10),
                                      const Text('Bot Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                                      const Spacer(),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399)))),
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
                                  _systemRow('Active Client', _activeClientDisplayName),
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
              const SizedBox(height: 24),
              _clientsSection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Client Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClientFilter,
                          dropdownColor: const Color(0xFF111827),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Clients')),
                            ..._clientsCache.map((c) => DropdownMenuItem(value: (c['id'] ?? '').toString(), child: Text((c['name'] ?? '').toString()))),
                          ],
                          onChanged: (v) => setState(() => _selectedClientFilter = v ?? 'All'),
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
                      onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))),
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
              _collapsibleHeader('Replies', _showReplies, () => setState(() => _showReplies = !_showReplies)),
              if (_showReplies) ...[
                const SizedBox(height: 10),
                _repliesList(),
              ],
              const SizedBox(height: 24),
              _collapsibleHeader('Recent Emails', _showRecentEmails, () => setState(() => _showRecentEmails = !_showRecentEmails)),
              if (_showRecentEmails) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['All', 'Replied', 'No Reply'].map((f) {
                    final sel = _recentEmailFilter == f;
                    return ChoiceChip(
                      label: Text(f, style: TextStyle(color: sel ? Colors.white : const Color(0xFF9CA3AF), fontSize: 12)),
                      selected: sel,
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: const Color(0xFF1F2937),
                      onSelected: (_) => setState(() => _recentEmailFilter = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).limit(_jobsLimit).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                    final docs = snap.data!.docs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      if (!_matchesClientFilter(m)) return false;
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
                      if (_recentEmailFilter == 'Replied') {
                        final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
                        if (rs != 'replied' && rs != 'reply' && m['has_reply'] != true) return false;
                      }
                      if (_recentEmailFilter == 'No Reply') {
                        final rs = (m['reply_status'] ?? m['status'] ?? '').toString().toLowerCase();
                        if (rs == 'replied' || m['has_reply'] == true) return false;
                      }
                      return true;
                    }).toList();
                    if (docs.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(child: Text(searchQuery.isEmpty ? 'No emails yet. The bot will start sending soon.' : 'No match for "$searchQuery"', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center)),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        ...docs.map((d) {
                          final m = d.data() as Map<String, dynamic>;
                          final company = (m['company'] ?? 'Unknown').toString();
                          final email = (m['email'] ?? '').toString();
                          final clientName = _clientDisplayName(m);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                            child: ListTile(
                              onTap: () => _showEmailDetail(m),
                              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.mail_outline, color: Color(0xFF34D399), size: 16)),
                              title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('$email - $clientName - ${_formatDate(m['timestamp'])}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                            ),
                          );
                        }),
                        TextButton(onPressed: () => setState(() => _jobsLimit += 20), child: const Text('Load More', style: TextStyle(color: Color(0xFF10B981)))),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              _collapsibleHeader('Follow-ups', _showFollowups, () => setState(() => _showFollowups = !_showFollowups)),
              if (_showFollowups) ...[
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('jobs_followups').orderBy('timestamp', descending: true).limit(_followupsLimit).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final docs = snap.data!.docs.where((d) {
                      final m = d.data() as Map<String, dynamic>;
                      return _matchesClientFilter(m);
                    }).toList();
                    if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No follow-ups yet.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
                    return Column(
                      children: docs.map((d) {
                        final m = d.data() as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                          child: ListTile(
                            onTap: () => _showFollowupDetail(m),
                            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16)),
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
              const SizedBox(height: 20),
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
                    return _matchesManualFilter(m);
                  }).toList();
                  if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child:Continuing from where it stopped — here is the rest of the file, from the Manual Queue section to the end. Paste this after the last line you received:

```dart
                  if (docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No manual requests.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
                  return Column(
                    children: docs.map((d) {
                      final m = d.data() as Map<String, dynamic>;
                      final st = (m['status'] ?? 'pending').toString();
                      final skillLabel = (m['job_type'] ?? m['skill'] ?? '').toString();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
                        child: ListTile(
                          onLongPress: () => _showManualActions(d.id, (m['company'] ?? '').toString(), st),
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: _manualStatusColor(st).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.schedule, color: _manualStatusColor(st), size: 16)),
                          title: Text((m['company'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
                          subtitle: Text('${m['email'] ?? ''} - ${_manualStatusLabel(st)}${skillLabel.isNotEmpty ? ' - $skillLabel' : ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          trailing: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF6B7280)),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
