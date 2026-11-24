import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
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
  List events = [];
  String filter = 'All';
  String searchQuery = '';
  int _jobsLimit = 20;
  int _followupsLimit = 20;

  String _selectedClientFilter = 'All';
  String _activeClientId = 'user';
  List<Map<String, dynamic>> _clientsCache = [];
  static const String _hfSpaceUrl = 'https://iharmayau-habeeb-job-bot.hf.space/';

  @override
  void initState() {
    super.initState();
    _loadActiveClient();
  }

  Future<void> _loadActiveClient() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('bot_config').doc('active').get();
      if (doc.exists) {
        final d = doc.data() ?? {};
        if (mounted) setState(() => _activeClientId = (d['active_client_id'] ?? d['client_id'] ?? 'user').toString());
      }
    } catch (_) {}
  }

  // ================= PHONE & WHATSAPP HELPERS =================
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
    if (!hasPlus && digits.startsWith('0') && digits.length == 11) digits = '234${digits.substring(1)}';
    return digits;
  }

  String _whatsAppMessage(String company) {
    final name = company.trim().isEmpty ? 'there' : company.trim();
    return 'Hi $name team, I sent you an email a few days ago about a Flutter demo showing how your product can work on mobile in 1 week.';
  }

  Future<void> _copyPhone(String phone) async {
    final clean = _cleanPhone(phone);
    if (clean.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied phone: $clean'), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 2)));
    }
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $label'), backgroundColor: const Color(0xFF10B981)));
  }

  Future<void> _openWhatsApp(String phone, String company) async {
    final digits = _phoneDigits(phone);
    if (digits.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid phone number for WhatsApp.'), backgroundColor: Colors.red));
      return;
    }
    final text = Uri.encodeComponent(_whatsAppMessage(company));
    final uri = Uri.parse('https://wa.me/$digits?text=$text');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.'), backgroundColor: Colors.red));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error launching WhatsApp.'), backgroundColor: Colors.red));
    }
  }

  // ================= CLIENT HELPERS =================
  String _clientSlug(String name) {
    var s = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) s = 'client_${DateTime.now().millisecondsSinceEpoch}';
    return s;
  }

  String _clientDisplayName(Map<String, dynamic> j) => (j['name'] ?? j['client_name'] ?? 'Unknown').toString();

  bool _matchesClientFilter(Map<String, dynamic> j) {
    if (_selectedClientFilter == 'All') return true;
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final f = _selectedClientFilter.toLowerCase();
    final match = _clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    final name = match.isNotEmpty ? (match.first['name'] ?? '').toString().toLowerCase() : f;
    return cn == name || cid == f || cn == f;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Active client set to $clientId. Bot will now send for this client.'), backgroundColor: const Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _useMeHabibu() async {
    try {
      await FirebaseFirestore.instance.collection('bot_config').doc('active').delete();
      if (mounted) {
        setState(() => _activeClientId = 'user');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active cleared. Bot now uses YOU - Habibu Armayau Isah.'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  // V61 - Full delete: client + gmail token + clear active
  Future<void> _deleteClient(String clientId, String name) async {
    if (clientId == 'user') return;
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: Text('Delete $name?', style: const TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('This deletes client + Gmail token + CV forever. Cannot undo.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        const SizedBox(height: 12),
        const Text('Type DELETE to confirm:', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: confirmCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'DELETE', hintStyle: const TextStyle(color: Color(0xFF6B7280)), filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete Forever', style: TextStyle(color: Colors.red)))],
    ));
    if (ok != true) return;
    if (confirmCtrl.text.trim().toUpperCase() != 'DELETE') {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type DELETE to confirm delete.'), backgroundColor: Colors.red));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('clients').doc(clientId).delete();
      try { await FirebaseFirestore.instance.collection('gmail_connected').doc(clientId).delete(); } catch (_) {}
      if (_activeClientId == clientId) {
        try { await FirebaseFirestore.instance.collection('bot_config').doc('active').delete(); } catch (_) {}
        if (mounted) setState(() => _activeClientId = 'user');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $name forever.'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pauseResumeClient(String clientId, bool pause) async {
    try {
      await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'is_paused': pause, 'status': pause ? 'paused' : 'active'}, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pause ? 'Paused $clientId. Bot will send 0 for them.' : 'Resumed $clientId. Bot will send again.'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _showLimitDialog(String clientId, String name, dynamic current) {
    final ctrl = TextEditingController(text: (current ?? 10).toString());
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      title: Text('Limit for $name', style: const TextStyle(color: Colors.white)),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: '1-50, e.g. 5', hintStyle: const TextStyle(color: Color(0xFF6B7280)), filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () async {
        final v = int.tryParse(ctrl.text.trim()) ?? 0;
        if (v < 1 || v > 50) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter 1 to 50'), backgroundColor: Colors.red)); return; }
        try {
          await FirebaseFirestore.instance.collection('clients').doc(clientId).set({'max_per_day': v}, SetOptions(merge: true));
          if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Set $name limit to $v/day'), backgroundColor: const Color(0xFF10B981))); }
        } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)); }
      }, child: const Text('Save'))],
    ));
  }

  void _showBotSettingsDialog() {
    final maxCtrl = TextEditingController(text: '20');
    final cyclesCtrl = TextEditingController(text: '3');
    final sleepCtrl = TextEditingController(text: '6');
    final waitCtrl = TextEditingController(text: '15');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('bot_config').doc('settings').get(), builder: (ctx2, snap) {
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>;
          maxCtrl.text = (d['max_per_day'] ?? 20).toString();
          cyclesCtrl.text = (d['max_cycles_per_day'] ?? 3).toString();
          sleepCtrl.text = (d['cycle_sleep_hours'] ?? 6).toString();
          waitCtrl.text = (d['wait_between_minutes'] ?? 15).toString();
        }
        return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bot Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Bot reads these every cycle. No restart needed. Client limit wins over global.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          _clientTextField(maxCtrl, 'Max emails per day (global) e.g. 20'),
          const SizedBox(height: 10),
          _clientTextField(cyclesCtrl, 'Cycles per day e.g. 3'),
          const SizedBox(height: 10),
          _clientTextField(sleepCtrl, 'Hours between cycles e.g. 6'),
          const SizedBox(height: 10),
          _clientTextField(waitCtrl, 'Minutes between each email e.g. 15'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () async {
            try {
              await FirebaseFirestore.instance.collection('bot_config').doc('settings').set({'max_per_day': int.tryParse(maxCtrl.text.trim()) ?? 20, 'max_cycles_per_day': int.tryParse(cyclesCtrl.text.trim()) ?? 3, 'cycle_sleep_hours': int.tryParse(sleepCtrl.text.trim()) ?? 6, 'wait_between_minutes': int.tryParse(waitCtrl.text.trim()) ?? 15}, SetOptions(merge: true));
              if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bot settings saved.'), backgroundColor: Color(0xFF10B981))); }
            } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)); }
          }, child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 20),
        ])));
      }));
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
    String type = 'freelancer';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setSB) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Freelancer = you sell Flutter/AI. Job Seeker = they want a job (Nurse, Accountant...).', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 16),
          _clientTextField(nameCtrl, 'Full Name * e.g. Amina Bello'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _typeChip('freelancer', type, (v) => setSB(() => type = v))),
            const SizedBox(width: 8),
            Expanded(child: _typeChip('job_seeker', type, (v) => setSB(() => type = v))),
          ]),
          const SizedBox(height: 10),
          if (type == 'freelancer') ...[
            _clientTextField(skillCtrl, 'Skill e.g. Flutter + AI, Backend, UI/UX'),
            const SizedBox(height: 10),
            _clientTextField(placeCtrl, 'Place / Target e.g. Lagos, Nigeria / Global'),
          ] else ...[
            _clientTextField(jobCtrl, 'Job Wanted * e.g. Nurse, Accountant, Teacher'),
            const SizedBox(height: 10),
            _clientTextField(locCtrl, 'Location * e.g. Abuja, Kano'),
            const SizedBox(height: 10),
            _clientTextField(cvCtrl, 'CV Link (Google Drive / PDF URL)'),
            const SizedBox(height: 10),
            _clientTextField(skillCtrl, 'Skill / Qualification e.g. BSc Nursing, RN'),
          ],
          const SizedBox(height: 10),
          _clientTextField(emailCtrl, 'Gmail (for sender) e.g. amina@gmail.com'),
          const SizedBox(height: 10),
          _clientTextField(phoneCtrl, 'Phone / WhatsApp e.g. +234...'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter client name'), backgroundColor: Colors.red)); return; }
              if (type == 'job_seeker' && (jobCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job Seeker needs Job Wanted + Location'), backgroundColor: Colors.red)); return;
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
                  'gmail_connected': false,
                  'is_paused': false,
                  'status': 'active',
                  'max_per_day': 10,
                  'created_at': DateTime.now().toIso8601String(),
                }, SetOptions(merge: true));
                if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client $name added (id: $id). Now tap Copy Connect Link to send Gmail link.'), backgroundColor: const Color(0xFF10B981))); }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
          const SizedBox(height: 20),
        ])),
      )),
    );
  }

  Widget _typeChip(String val, String selected, Function(String) onTap) {
    final active = val == selected;
    return GestureDetector(onTap: () => onTap(val), child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center,
      decoration: BoxDecoration(color: active ? const Color(0xFF10B981) : const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? const Color(0xFF10B981) : const Color(0xFF1F2937))),
      child: Text(val == 'freelancer' ? '💻 Freelancer' : '💼 Job Seeker', style: TextStyle(color: active ? Colors.white : const Color(0xFF9CA3AF), fontWeight: FontWeight.w600, fontSize: 13)),
    ));
  }

  Widget _clientTextField(TextEditingController ctrl, String hint) {
    return TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12), filled: true, fillColor: const Color(0xFF090D16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)));
  }

  Widget _clientsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('clients').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        final clients = docs.map((d) { final m = d.data() as Map<String, dynamic>; m['id'] = d.id; return m; }).toList();
        _clientsCache = clients;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Clients', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
            Row(children: [
              TextButton.icon(onPressed: _useMeHabibu, icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF3B82F6)), label: const Text('Use Me', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w600, fontSize: 12))),
              TextButton.icon(onPressed: _showAddClientDialog, icon: const Icon(Icons.person_add_outlined, size: 16, color: Color(0xFF10B981)), label: const Text('Add Client', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600))),
            ]),
          ]),
          const SizedBox(height: 6),
          if (clients.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('No clients yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Add yourself as Freelancer, then add job seekers like Amina (Nurse, Abuja). Bot sends for ACTIVE client only.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          ]))),
          ...clients.map((c) {
            final id = (c['id'] ?? '').toString();
            final name = (c['name'] ?? '').toString();
            final type = (c['client_type'] ?? 'freelancer').toString();
            final job = (c['job_wanted'] ?? c['job'] ?? c['skill'] ?? '').toString();
            final loc = (c['location'] ?? c['place'] ?? '').toString();
            final gmailOk = c['gmail_connected'] == true;
            final isPaused = c['is_paused'] == true || (c['status'] ?? '').toString().toLowerCase() == 'paused';
            final isActive = id == _activeClientId;
            final maxPerDay = c['max_per_day'] ?? 10;
            final hasCv = (c['cv_url'] ?? c['cvUrl'] ?? '').toString().isNotEmpty;
            final link = '$_hfSpaceUrl?client=$id';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937))),
              child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: (type == 'job_seeker' ? const Color(0xFF3B82F6) : const Color(0xFF10B981)).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(type == 'job_seeker' ? Icons.work_outline : Icons.code_outlined, size: 16, color: type == 'job_seeker' ? const Color(0xFF60A5FA) : const Color(0xFF34D399))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('${type == 'job_seeker' ? 'Job Seeker' : 'Freelancer'} • $job • $loc', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  if (isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold))),
                  if (isPaused) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)), child: const Text('PAUSED', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 9, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF9CA3AF)), onPressed: () => _deleteClient(id, name)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: gmailOk ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D), borderRadius: BorderRadius.circular(6)), child: Text(gmailOk ? 'Gmail: Connected ✅' : 'Gmail: Not Connected ❌', style: TextStyle(color: gmailOk ? const Color(0xFF34D399) : const Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.w600))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text(hasCv ? 'CV ✅' : 'CV ❌', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('Max: $maxPerDay/day', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w600))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('ID: $id', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _setActiveClient(id), style: OutlinedButton.styleFrom(side: BorderSide(color: isActive ? const Color(0xFF10B981) : const Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(isActive ? 'Active ✓' : 'Make Active', style: TextStyle(color: isActive ? const Color(0xFF34D399) : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(onPressed: () async {
                    final msg = 'Hi $name, connect your Gmail here so companies will see YOUR email:\n$link\n\nTap link -> Click Connect Gmail for $name -> Login with YOUR Gmail -> Allow -> Done.';
                    await _copyText(link, 'Connect Link');
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link copied. Send to $name on WhatsApp:\n$msg'), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 4)));
                  }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a73e8), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), icon: const Icon(Icons.link, size: 15, color: Colors.white), label: const Text('Copy Connect Link', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pauseResumeClient(id, !isPaused), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(isPaused ? '▶️ Resume' : '⏸️ Pause', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _showLimitDialog(id, name, maxPerDay), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('🔢 Set Limit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)))),
                ]),
              ])),
            );
          }),
        ]);
      },
    );
  }

  int count(String type) => events.where((e) => (e['event'] ?? '').toString().toLowerCase() == type).length;
  Color colorFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened': return const Color(0xFF10B981);
      case 'clicked': return const Color(0xFF3B82F6);
      case 'delivered': return const Color(0xFFA78BFA);
      case 'bounce': case 'softbounce': case 'hardbounce': return const Color(0xFFEF4444);
      default: return const Color(0xFF9CA3AF);
    }
  }
  IconData iconFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened': return Icons.visibility_outlined;
      case 'clicked': return Icons.ads_click_outlined;
      case 'delivered': return Icons.check_circle_outline;
      case 'bounce': case 'softbounce': case 'hardbounce': return Icons.error_outline;
      default: return Icons.mail_outline;
    }
  }
  String labelFor(String event) {
    switch (event.toLowerCase()) {
      case 'opened': return 'Opened';
      case 'clicked': return 'Clicked';
      case 'delivered': return 'Delivered';
      case 'request': case 'requests': return 'Sent';
      case 'bounce': case 'softbounce': case 'hardbounce': return 'Bounced';
      default: return 'Sent';
    }
  }
  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) { final d = ts.toDate(); return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'; }
    final s = ts.toString(); if (s.length > 16) return s.substring(0, 16).replaceAll('T', ' '); return s;
  }
  DateTime? _parseDate(dynamic ts) {
    if (ts == null) return null;
    try { if (ts is Timestamp) return ts.toDate(); final s = ts.toString(); if (s.isEmpty) return null; return DateTime.tryParse(s); } catch (_) { return null; }
  }
  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _dayLabel(DateTime d) { const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']; return days[d.weekday - 1]; }

  Widget _detailRow(String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))), Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, color: Colors.white)))]);

  String _buildEmailBody(Map<String, dynamic> j) {
    final saved = (j['email_body'] ?? j['message'] ?? j['body'] ?? j['email_text'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;
    final company = (j['company'] ?? 'your team').toString();
    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
    final why = (j['why'] ?? j['reason'] ?? '').toString().trim();
    final clientType = (j['client_type'] ?? '').toString();
    final clientName = (j['client_name'] ?? 'Habeeb').toString();
    if (clientType == 'job_seeker') {
      final job = (j['job_wanted'] ?? jobType).toString();
      return "Dear Hiring Manager at $company,\n\nMy name is $clientName. I am applying for the $job position at $company.\n\n${why.isNotEmpty ? why : 'I saw $company is hiring and I am interested in the $job role. I am available immediately.'}\n\nI have attached my CV for your review. I would be grateful for an opportunity to discuss how I can contribute to your team.\n\nThank you for your time.\n\nKind regards,\n$clientName\n$job";
    }
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
    if ((j['client_type'] ?? '').toString() == 'job_seeker') {
      final name = (j['client_name'] ?? 'Applicant').toString();
      return "Application for $jobType at $company - $name";
    }
    return "Flutter + AI Developer for $company - Can I help your team ship faster? ($jobType)";
  }

  Future<Map<String, dynamic>> _fetchMergedDetail(Map<String, dynamic> j) async {
    final merged = Map<String, dynamic>.from(j);
    final hasBody = (merged['email_body'] ?? merged['body'] ?? '').toString().trim().isNotEmpty;
    final hasPhone = _cleanPhone(merged['phone']).isNotEmpty;
    if (hasBody && hasPhone) return merged;
    try {
      final company = (j['company'] ?? '').toString(); final email = (j['email'] ?? '').toString();
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

  Widget _phoneActionCard(String phone, String company) {
    final clean = _cleanPhone(phone); if (clean.isEmpty) return const SizedBox.shrink();
    return Container(margin: const EdgeInsets.only(top: 14), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF10B981)), const SizedBox(width: 8), const Text('Phone', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)), const SizedBox(width: 10), Expanded(child: SelectableText(clean, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600))), IconButton(tooltip: 'Copy number', onPressed: () => _copyPhone(clean), icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF9CA3AF)), visualDensity: VisualDensity.compact)]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _openWhatsApp(clean, company), icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16), label: const Text('WhatsApp Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)))),
          const SizedBox(width: 8),
          OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _copyPhone(clean), icon: const Icon(Icons.copy, color: Color(0xFF9CA3AF), size: 15), label: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12)))]),
      ]));
  }

  void _showEmailDetail(Map<String, dynamic> j) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(future: _fetchMergedDetail(j), builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
        final merged = snap.data ?? j;
        final company = (merged['company'] ?? 'Unknown').toString(); final email = (merged['email'] ?? '').toString();
        final phone = _cleanPhone(merged['phone']); final jobType = (merged['job_type'] ?? 'FLUTTER').toString();
        final dateStr = _formatDate(merged['timestamp']); final subject = _buildSubject(merged); final body = _buildEmailBody(merged);
        final isReal = (merged['email_body'] ?? merged['message'] ?? merged['body'] ?? merged['email_text'] ?? '').toString().trim().isNotEmpty;
        return DraggableScrollableSheet(initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false, builder: (ctx2, scrollCtrl) => SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 16),
          Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business_outlined, color: Color(0xFF10B981), size: 20)), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(height: 2), Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF34D399))))]),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_detailRow('To', email), const SizedBox(height: 6), _detailRow('Date', dateStr.isEmpty ? 'Unknown' : dateStr), const SizedBox(height: 6), _detailRow('Subject', subject), if ((merged['client_name'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 6), _detailRow('Client', (merged['client_name'] ?? '').toString())]])),
          _phoneActionCard(phone, company),
          const SizedBox(height: 16),
          Row(children: [const Text('Email Message', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isReal ? const Color(0xFF064E3B) : const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)), child: Text(isReal ? 'Exact copy' : 'Preview', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isReal ? const Color(0xFF34D399) : const Color(0xFF9CA3AF))))]),
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))), child: SelectableText(body, style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.5))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _copyText('Subject: $subject\n\n$body', 'Email'), icon: const Icon(Icons.copy, size: 15), label: const Text('Copy Email'))),
        ])));
      }));
  }

  void _showFollowupDetail(Map<String, dynamic> j) {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final body = (j['email_body'] ?? j['body'] ?? 'Follow-up sent 3 days after first email.').toString();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(email, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))), child: SelectableText(body, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5))),
        const SizedBox(height: 20),
      ])));
  }

  void _showAddManualDialog() {
    final companyCtrl = TextEditingController(); final emailCtrl = TextEditingController();
    String jobType = 'FLUTTER'; String selectedClient = _activeClientId;
    final jobTypes = ['FLUTTER', 'BACKEND', 'AI', 'LLM', 'FULLSTACK', 'NURSE', 'ACCOUNTANT', 'TEACHER', 'DRIVER', 'CHEF'];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setSB) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Send Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Bot will find email if left empty, then send for the selected client.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
        const SizedBox(height: 14),
        _clientTextField(companyCtrl, 'Company / Hospital * e.g. Nizamiye Hospital'),
        const SizedBox(height: 10),
        _clientTextField(emailCtrl, 'Email (optional - bot will find if empty)'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: _clientsCache.any((c) => (c['id'] ?? '') == selectedClient) ? selectedClient : null, decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Colors.white), hint: const Text('Select Client', style: TextStyle(color: Color(0xFF6B7280))), items: _clientsCache.map((c) => DropdownMenuItem<String>(value: (c['id'] ?? '').toString(), child: Text('${c['name']} (${c['client_type']})', style: const TextStyle(color: Colors.white)))).toList(), onChanged: (v) => setSB(() => selectedClient = v ?? _activeClientId)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: jobType, decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)), dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Colors.white), items: jobTypes.map((j) => DropdownMenuItem(value: j, child: Text(j, style: const TextStyle(color: Colors.white)))).toList(), onChanged: (v) => setSB(() => jobType = v ?? 'FLUTTER')),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () async {
          final company = companyCtrl.text.trim(); if (company.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter company'), backgroundColor: Colors.red)); return; }
          try {
            await FirebaseFirestore.instance.collection('pending_jobs').add({'company': company, 'email': emailCtrl.text.trim(), 'job_type': jobType, 'client_id': selectedClient, 'status': 'pending', 'created_at': DateTime.now().toIso8601String(), 'timestamp': DateTime.now().toIso8601String()});
            if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual request queued. Bot will send soon.'), backgroundColor: Color(0xFF10B981))); }
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red)); }
        }, child: const Text('Queue Manual Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 20),
      ]))));
  }

  Widget _buildGraph(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now(); final Map<String, int> perDay = {};
    for (var i = 6; i >= 0; i--) { final d = now.subtract(Duration(days: i)); perDay[_dayKey(d)] = 0; }
    for (final d in docs) { final m = d.data() as Map<String, dynamic>; final dt = _parseDate(m['timestamp'] ?? m['date']); if (dt == null) continue; final k = _dayKey(dt); if (perDay.containsKey(k)) perDay[k] = (perDay[k] ?? 0) + 1; }
    final maxV = perDay.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Last 7 Days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: perDay.entries.map((e) {
        final h = 8 + (e.value / maxV * 60);
        return Expanded(child: Column(children: [Text('${e.value}', style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))), const SizedBox(height: 4), Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 4), Text(_dayLabel(DateTime.parse(e.key)), style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)))]));
      }).toList()),
    ])));
  }

  Widget _repliesMetrics(int totalSent) {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_replies').snapshots(), builder: (context, snap) {
      final replies = snap.data?.docs.length ?? 0;
      final rate = totalSent == 0 ? 0.0 : (replies / totalSent * 100);
      return Row(children: [_metric('Replies', '$replies', Icons.mark_email_read_outlined, 'Companies replied'), const SizedBox(width: 12), _metric('Reply Rate', '${rate.toStringAsFixed(1)}%', Icons.trending_up, 'Response rate')]);
    });
  }

  Color _manualStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'sent': return const Color(0xFF10B981);
      case 'pending': case 'processing': return const Color(0xFFF59E0B);
      case 'failed': case 'bad_email': case 'no_email_found': return const Color(0xFFEF4444);
      case 'duplicate': return const Color(0xFF3B82F6);
      default: return const Color(0xFF9CA3AF);
    }
  }
  String _manualStatusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return 'Pending';
      case 'processing': return 'Sending...';
      case 'sent': return 'Sent';
      case 'failed': return 'Failed';
      case 'bad_email': return 'Bad Email';
      case 'no_email_found': return 'No Email';
      case 'duplicate': return 'Duplicate';
      default: return s;
    }
  }

  void _showReplyDetail(Map<String, dynamic> r) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: const Color(0xFF111827), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.5, expand: false, builder: (ctx2, scrollCtrl) => SingleChildScrollView(controller: scrollCtrl, padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 16),
        Text((r['company'] ?? 'Unknown').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4), Text((r['email'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 4), Text((r['subject'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))), child: SelectableText((r['reply_text'] ?? r['snippet'] ?? '').toString(), style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.5))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () async { final email = (r['email'] ?? '').toString(); if (email.isNotEmpty) { final uri = Uri.parse('mailto:$email?subject=Re: ${(r['subject'] ?? '').toString()}'); try { await launchUrl(uri); } catch (_) {} } }, icon: const Icon(Icons.reply, color: Colors.white, size: 16), label: const Text('Reply in Gmail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
      ]))));
  }

  Widget _repliesList() {
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_replies').orderBy('timestamp', descending: true).limit(20).snapshots(), builder: (context, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      var docs = snap.data!.docs.where((d) { final r = d.data() as Map<String, dynamic>; return _matchesClientFilter(r); }).toList();
      if (docs.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.reply_outlined, size: 22, color: Color(0xFF9CA3AF))), const SizedBox(height: 10), const Text('No replies yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)), const SizedBox(height: 4), const Text('When a company replies in Gmail, it will appear here automatically.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center)]))));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Replies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${docs.length} total • Tap to view reply', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))]),
        const SizedBox(height: 10),
        ...docs.map((d) { final r = d.data() as Map<String, dynamic>; final company = (r['company'] ?? 'Unknown').toString(); final email = (r['email'] ?? '').toString(); final subject = (r['subject'] ?? '').toString(); return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))), child: ListTile(onTap: () => _showReplyDetail(r), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_outlined, color: Color(0xFFF59E0B), size: 16)), title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subject.isNotEmpty ? '$subject • $email' : email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))), trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)))); }),
      ]);
    });
  }

  Widget _metric(String title, String value, IconData icon, String sub) {
    return Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 14, color: const Color(0xFF10B981)), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))]),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
    ])));
  }

  Widget _systemRow(String title, String status) {
    return Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.white))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399))))]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icon.png', width: 38, height: 38, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Container(width: 38, height: 38, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]), borderRadius: BorderRadius.circular(10)), child: const Center(child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))))),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CareerPilot AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)), SizedBox(height: 1), Text("Habeeb Armaya'u — Software Engineer", style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))]),
        ]),
        actions: [Container(margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: const Color(0xFF064E3B).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))), child: const Row(children: [Icon(Icons.circle, size: 6, color: Color(0xFF10B981)), SizedBox(width: 6), Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399))) ]))],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFF1F2937))),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddManualDialog, backgroundColor: const Color(0xFF10B981), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Send Manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      body: RefreshIndicator(onRefresh: () async { setState(() {}); }, color: const Color(0xFF10B981), backgroundColor: const Color(0xFF111827), child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.3)), SizedBox(height: 2), Text('Your applications and email activity', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))]), IconButton(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF9CA3AF)), style: IconButton.styleFrom(backgroundColor: const Color(0xFF111827), side: const BorderSide(color: Color(0xFF1F2937)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))]),
        const SizedBox(height: 20),
        StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('bot_status').doc('current').snapshots(), builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?; final sentToday = data?['sent_today'] ?? 0;
          final rawCompany = (data?['last_company'] ?? '').toString().trim(); final lastCompany = (rawCompany.isEmpty || rawCompany.startsWith('Waiting ')) ? 'Waiting' : rawCompany; final lastRun = (data?['last_run'] ?? 'No recent activity').toString();
          return Container(decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F2937))), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.bolt, size: 16, color: Color(0xFF10B981))), const SizedBox(width: 10), const Text('Bot Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)), child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399))))]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$sentToday', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 2), const Text('Sent Today', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))] )), Container(width: 1, height: 35, color: const Color(0xFF1F2937)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lastCompany.length > 18 ? '${lastCompany.substring(0, 18)}...' : lastCompany, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), const Text('Last Company', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))]))]),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)), const SizedBox(width: 6), Expanded(child: Text('Last activity: $lastRun', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))])),
          ])));
        }),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1F2937))), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedClientFilter, isExpanded: true, dropdownColor: const Color(0xFF111827), style: const TextStyle(color: Colors.white, fontSize: 13), items: ['All', ..._clientsCache.map((c) => (c['id'] ?? '').toString())].map((v) => DropdownMenuItem(value: v, child: Text(v == 'All' ? 'Filter: All Clients' : 'Filter: $v', style: const TextStyle(color: Colors.white)))).toList(), onChanged: (v) => setState(() => _selectedClientFilter = v ?? 'All')))),
        const SizedBox(height: 16),
        _clientsSection(),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(), builder: (context, jobSnap) {
          final allDocs = jobSnap.data?.docs ?? []; final docs = allDocs.where((d) => _matchesClientFilter(d.data() as Map<String, dynamic>)).toList();
          final jobsCount = docs.length; final totalSent = jobsCount; final realDelivered = totalSent; final realRate = 100.0;
          return Column(children: [Row(children: [_metric('Total Sent', '$totalSent', Icons.send_outlined, 'Applications'), const SizedBox(width: 12), _metric('Open Rate', '${realRate.toStringAsFixed(1)}%', Icons.visibility_outlined, 'Engagement')]), const SizedBox(height: 12), Row(children: [_metric('Delivered', '$realDelivered', Icons.check_circle_outline, 'Successful'), const SizedBox(width: 12), _metric('Active Client', _activeClientId == 'user' ? 'Habibu' : _activeClientId, Icons.person_outline, 'Bot sends for this client')]), const SizedBox(height: 12), _repliesMetrics(totalSent)]);
        }),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(), builder: (context, snap) => _buildGraph((snap.data?.docs ?? []).where((d) => _matchesClientFilter(d.data() as Map<String, dynamic>)).toList())),
        const SizedBox(height: 24),
        const Text('Services', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _systemRow('Email Delivery (Gmail OAuth - Per Client)', 'Configured'),
          const Divider(height: 24, color: Color(0xFF1F2937)),
          Row(children: [const Expanded(child: Text('Bot Settings (Max / Cycles / Sleep / Wait)', style: TextStyle(fontSize: 13, color: Colors.white))), TextButton(onPressed: _showBotSettingsDialog, child: const Text('Edit', style: TextStyle(color: Color(0xFF10B981))))]),
          const Divider(height: 24, color: Color(0xFF1F2937)),
          _systemRow('Application Bot (Tavily Only)', 'Running on schedule'),
          const Divider(height: 24, color: Color(0xFF1F2937)),
          _systemRow('Database (Firebase)', 'Connected'),
        ]))),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Manual Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('pending_jobs').snapshots(), builder: (context, s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${s.data?.docs.length ?? 0} total', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))))]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('pending_jobs').orderBy('created_at', descending: true).limit(20).snapshots(), builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
          if (snap.hasError) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Could not load manual requests.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12))));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFF9CA3AF))), const SizedBox(height: 10), const Text('No manual requests yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)), const SizedBox(height: 4), const Text('Use Send Manual to add a company you choose.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center)]))));
          return Column(children: docs.map((d) { final j = d.data() as Map<String, dynamic>; final company = (j['company'] ?? 'Unknown').toString(); final email = (j['email'] ?? '').toString(); final status = (j['status'] ?? 'pending').toString(); final jobType = (j['job_type'] ?? 'FLUTTER').toString(); final c = _manualStatusColor(status); return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.send_outlined, color: c, size: 16)), title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(email.isEmpty ? 'Bot will find email • $jobType • ${(j['client_id'] ?? '').toString()}' : '$email • $jobType', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(_manualStatusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c))))); }).toList());
        }),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('All Companies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(), builder: (context, s) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text('${s.data?.docs.length ?? 0} total • Tap to view email', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))))]),
        const SizedBox(height: 10),
        TextField(onChanged: (v) => setState(() => searchQuery = v.trim().toLowerCase()), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Search company, email or phone...', hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 12), prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)), filled: true, fillColor: const Color(0xFF111827), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).limit(_jobsLimit).snapshots(), builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
          final rawDocs = (snap.data?.docs ?? []).where((d) => _matchesClientFilter(d.data() as Map<String, dynamic>)).toList();
          if (rawDocs.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle), child: const Icon(Icons.inbox_outlined, size: 24, color: Color(0xFF9CA3AF))), const SizedBox(height: 12), const Text('No applications sent yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)), const SizedBox(height: 4), const Text('Applications you send will appear here.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center)]))));
          final filteredDocs = searchQuery.isEmpty ? rawDocs : rawDocs.where((d) { final j = d.data() as Map<String, dynamic>; final c = (j['company'] ?? '').toString().toLowerCase(); final e = (j['email'] ?? '').toString().toLowerCase(); final p = _cleanPhone(j['phone']).toLowerCase(); return c.contains(searchQuery) || e.contains(searchQuery) || (p.isNotEmpty && p.contains(searchQuery)); }).toList();
          if (filteredDocs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No company found.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
          return Column(children: [
            ...filteredDocs.map((d) { final j = d.data() as Map<String, dynamic>; final company = (j['company'] ?? 'Unknown').toString(); final email = (j['email'] ?? '').toString(); final phone = _cleanPhone(j['phone']); final jobType = (j['job_type'] ?? 'FLUTTER').toString(); final shortDate = _formatDate(j['timestamp']); final clientName = (j['client_name'] ?? '').toString(); final subtitleParts = [if (email.isNotEmpty) email, if (clientName.isNotEmpty) 'For: $clientName', if (phone.isNotEmpty) phone, if (shortDate.isNotEmpty) shortDate].join(' • '); return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))), child: ListTile(onTap: () => _showEmailDetail(j), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.send_outlined, color: Color(0xFF10B981), size: 16)), title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitleParts, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)))), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399)))))); }),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => setState(() => _jobsLimit += 20), child: const Text('Load More', style: TextStyle(color: Colors.white))),
          ]);
        }),
        const SizedBox(height: 24),
        _repliesList(),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Follow-ups', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)), child: const Text('Auto after 3 days', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))))]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('jobs_followups').orderBy('timestamp', descending: true).limit(_followupsLimit).snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final docs = (snap.data?.docs ?? []).where((d) => _matchesClientFilter(d.data() as Map<String, dynamic>)).toList();
          if (docs.isEmpty) return Card(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No follow-ups yet.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)))));
          return Column(children: docs.map((d) { final j = d.data() as Map<String, dynamic>; return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1F2937))), child: ListTile(onTap: () => _showFollowupDetail(j), leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.reply_all_outlined, color: Color(0xFF60A5FA), size: 16)), title: Text((j['company'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text((j['email'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))), trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)))); }).toList());
        }),
        const SizedBox(height: 30),
      ]))),
    );
  }
}
