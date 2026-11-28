import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pilot_helpers.dart';

class PilotDialogs {
  static Widget _textField(TextEditingController ctrl, String hint) {
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

  static Widget _typeChip(String val, String selected, Function(String) onTap) {
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

  static Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600))),
        Expanded(child: SelectableText(value, style: const TextStyle(fontSize: 12, color: Colors.white))),
      ],
    );
  }

  static Widget _phoneActionCard(BuildContext context, String phone, String company, {Map<String, dynamic>? client}) {
    final clean = PilotHelpers.cleanPhone(phone);
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
              IconButton(tooltip: 'Copy number', onPressed: () => PilotHelpers.copyPhone(context, clean), icon: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFF9CA3AF)), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => PilotHelpers.openWhatsApp(context, clean, company, client: client),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16),
                  label: const Text('WhatsApp Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1F2937)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => PilotHelpers.copyPhone(context, clean),
                icon: const Icon(Icons.copy, color: Color(0xFF9CA3AF), size: 15),
                label: const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> editSenderEmail(BuildContext context, String clientId, String name, String currentEmail) async {
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
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sender email saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Future<void> showConnectLink(BuildContext context, String clientId, String name, String senderEmail) async {
    final link = '${PilotHelpers.hfSpaceUrl}?client=$clientId';
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
              await PilotHelpers.copyText(context, link, 'Connect link');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy Link'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              await PilotHelpers.copyText(context, message, 'Message');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy Message', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static Future<void> pasteCv(BuildContext context, String clientId, String name, String currentLink) async {
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
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CV link removed')));
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final link = ctrl.text.trim();
              if (link.isEmpty) return;
              await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
                'cv_url': link, 'cvUrl': link, 'cvLink': link, 'cv_uploaded_at': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CV link saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save Link', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static void showLimit(BuildContext context, String clientId, String name, dynamic current) {
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
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Daily limit for $name set to $v.'), backgroundColor: const Color(0xFF10B981)));
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static void showBotSettings(BuildContext context) {
    final maxCtrl = TextEditingController(text: '20');
    final cyclesCtrl = TextEditingController(text: '3');
    final sleepCtrl = TextEditingController(text: '6');
    final waitCtrl = TextEditingController(text: '15');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('bot_config').doc('settings').get(),
        builder: (ctx2, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 280,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text('Loading settings...', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                ],
              ),
            );
          }
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
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bot Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Changes apply to the next cycle. No restart is required. A client daily limit overrides the global limit.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 16),
                  _textField(maxCtrl, 'Max emails per day (global) e.g. 20'),
                  const SizedBox(height: 10),
                  _textField(cyclesCtrl, 'Cycles per day e.g. 3'),
                  const SizedBox(height: 10),
                  _textField(sleepCtrl, 'Hours between cycles e.g. 6'),
                  const SizedBox(height: 10),
                  _textField(waitCtrl, 'Minutes between each email e.g. 15'),
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
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bot settings saved.'), backgroundColor: Color(0xFF10B981)));
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
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
      ),
    );
  }

  static void showAddClient(BuildContext context) {
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSB) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Client', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Freelancer: outreach for services. Job Seeker: applications for employment.', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(height: 16),
                _textField(nameCtrl, 'Full name e.g. Amina Bello'),
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
                  _textField(skillCtrl, 'Skill e.g. Flutter + AI, Video Editing, Graphic Design'),
                  const SizedBox(height: 6),
                  const Text('Any skill is supported - e.g. Video Editing, Plumbing, Data Analysis, Welding, Copywriting.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                  const SizedBox(height: 10),
                  _textField(placeCtrl, 'Target market e.g. Lagos, Nigeria / Global'),
                ] else ...[
                  _textField(jobCtrl, 'Position sought e.g. Nurse, Accountant, Video Editor'),
                  const SizedBox(height: 6),
                  const Text('Any position is supported - e.g. Pharmacist, Welder, Electrician, Cleaner, Marketing Manager.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                  const SizedBox(height: 10),
                  _textField(locCtrl, 'Location e.g. Abuja, Kano'),
                  const SizedBox(height: 10),
                  _textField(cvCtrl, 'CV link (Google Drive / PDF URL) - can be added later'),
                  const SizedBox(height: 10),
                  _textField(skillCtrl, 'Qualification e.g. BSc Nursing, RN'),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF064E3B).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROOF - This is why companies reply (REQUIRED)', style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Ask client 3 questions on WhatsApp. Without proof, emails get 0 replies.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                      const SizedBox(height: 12),
                      _textField(skillsCtrl, 'Q1: What tools can you use? e.g. Excel, Power BI, Python, SQL'),
                      const SizedBox(height: 10),
                      _textField(projectCtrl, 'Q2: What work have you done? e.g. Analyzed sales data for small shop in Kano using Excel'),
                      const SizedBox(height: 10),
                      _textField(projectResultCtrl, 'Q3: What was the result? e.g. Found which product sells best, made dashboard'),
                      const SizedBox(height: 10),
                      _textField(experienceCtrl, 'Experience (optional) e.g. 2 years as Data Analyst'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _textField(emailCtrl, 'Gmail address (sender) e.g. amina@gmail.com'),
                const SizedBox(height: 6),
                const Text('This address will appear as the sender. Each client must connect their own Gmail account. Sending will remain paused until Gmail is connected.', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                const SizedBox(height: 10),
                _textField(phoneCtrl, 'Phone / WhatsApp e.g. +234...'),
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
                      final id = PilotHelpers.clientSlug(name);
                      try {
                        await FirebaseFirestore.instance.collection('clients').doc(id).set({
                          'name': name, 'client_type': type, 'skill': skillCtrl.text.trim(),
                          'job_wanted': jobCtrl.text.trim(), 'job': jobCtrl.text.trim(),
                          'location': locCtrl.text.trim(), 'place': type == 'freelancer' ? placeCtrl.text.trim() : locCtrl.text.trim(),
                          'email': emailCtrl.text.trim(), 'phone': phoneCtrl.text.trim(),
                          'cv_url': cvCtrl.text.trim(), 'cvUrl': cvCtrl.text.trim(), 'cvLink': cvCtrl.text.trim(),
                          'skills': skillsCtrl.text.trim(), 'project_1': projectCtrl.text.trim(),
                          'project_1_result': projectResultCtrl.text.trim(), 'experience': experienceCtrl.text.trim(),
                          'gmail_connected': false, 'is_paused': false, 'status': 'active', 'max_per_day': 10,
                          'created_at': DateTime.now().toIso8601String(),
                        }, SetOptions(merge: true));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client $name added. Next: add the CV link and share the Gmail connect link.'), backgroundColor: const Color(0xFF10B981)));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Save Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> editProof(BuildContext context, String clientId, String name, Map<String, dynamic> c) async {
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
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ask client 3 questions. This proof goes into EVERY email.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
              const SizedBox(height: 12),
              _textField(skillsCtrl, 'Q1: Tools? e.g. Excel, Power BI, Python'),
              const SizedBox(height: 10),
              _textField(projectCtrl, 'Q2: What work did you do?'),
              const SizedBox(height: 10),
              _textField(resultCtrl, 'Q3: What was the result?'),
              const SizedBox(height: 10),
              _textField(expCtrl, 'Experience (optional)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clients').doc(clientId).set({
                'skills': skillsCtrl.text.trim(), 'project_1': projectCtrl.text.trim(),
                'project_1_result': resultCtrl.text.trim(), 'experience': expCtrl.text.trim(),
                'proof_updated_at': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proof saved for $name.'), backgroundColor: const Color(0xFF10B981)));
            },
            child: const Text('Save Proof', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static void showAddManual(BuildContext context, String activeClientId, List<Map<String, dynamic>> clientsCache) {
    final companyCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final customSkillCtrl = TextEditingController();
    String jobType = 'FLUTTER';
    String selectedClient = activeClientId;
    const jobTypes = ['FLUTTER', 'BACKEND', 'AI', 'LLM', 'FULLSTACK', 'NURSE', 'ACCOUNTANT', 'TEACHER', 'DRIVER', 'CHEF', 'CUSTOM'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSB) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Send Manually', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('If no email is provided, the bot will attempt to find one, then send for the selected client. Any skill is supported.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                const SizedBox(height: 14),
                _textField(companyCtrl, 'Company / Hospital e.g. Nizamiye Hospital'),
                const SizedBox(height: 10),
                _textField(emailCtrl, 'Email (optional - bot will find if empty)'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: clientsCache.any((c) => (c['id'] ?? '') == selectedClient) ? selectedClient : null,
                  decoration: InputDecoration(filled: true, fillColor: const Color(0xFF090D16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1F2937))), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  dropdownColor: const Color(0xFF111827),
                  style: const TextStyle(color: Colors.white),
                  hint: const Text('Select Client', style: TextStyle(color: Color(0xFF6B7280))),
                  items: clientsCache.map((c) => DropdownMenuItem<String>(value: (c['id'] ?? '').toString(), child: Text('${c['name']} (${c['client_type']})', style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setSB(() => selectedClient = v ?? activeClientId),
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
                  _textField(customSkillCtrl, 'Enter custom skill e.g. Video Editing, Graphic Design, Welding'),
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
                        finalSkill = PilotHelpers.normalizeSkill(customSkillCtrl.text);
                      }
                      if (PilotHelpers.isRecruiterName(company)) {
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
                        if (proceed != true || !context.mounted) return;
                      }
                      final selClient = clientsCache.where((c) => (c['id'] ?? '').toString() == selectedClient).toList();
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
                        if (proceed2 != true || !context.mounted) return;
                      }
                      try {
                        final clientName = selClient.isNotEmpty ? (selClient.first['name'] ?? '').toString() : '';
                        await FirebaseFirestore.instance.collection('pending_jobs').add({
                          'company': company, 'email': emailCtrl.text.trim(),
                          'job_type': finalSkill, 'skill': finalSkill, 'custom_skill': jobType == 'CUSTOM',
                          'client_id': selectedClient, 'client_name': clientName,
                          'status': 'pending', 'created_at': DateTime.now().toIso8601String(), 'timestamp': DateTime.now().toIso8601String(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manual request queued for $finalSkill. The bot will process it shortly.'), backgroundColor: const Color(0xFF10B981)));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Queue Manual Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showEmailDetail(BuildContext context, Map<String, dynamic> j, List<Map<String, dynamic>> clientsCache) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: PilotHelpers.fetchMergedDetail(j),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
          }
          final merged = snap.data ?? j;
          final company = (merged['company'] ?? 'Unknown').toString();
          final email = (merged['email'] ?? '').toString();
          final clientPhonesHere = clientsCache.map((c) => PilotHelpers.cleanPhone(c['phone'])).where((p) => p.isNotEmpty).toSet();
          final phone = clientPhonesHere.contains(PilotHelpers.cleanPhone(merged['phone'])) ? '' : PilotHelpers.cleanPhone(merged['phone']);
          final jobType = (merged['job_type'] ?? 'FLUTTER').toString();
          final dateStr = PilotHelpers.formatDate(merged['timestamp']);
          final subject = PilotHelpers.buildSubject(merged);
          final body = PilotHelpers.buildEmailBody(merged);
          final isReal = (merged['email_body'] ?? merged['message'] ?? merged['body'] ?? merged['email_text'] ?? '').toString().trim().isNotEmpty;
          final senderDisplay = (merged['sender_email'] ?? merged['from_email'] ?? '').toString().trim();
          final clientForWhatsApp = clientsCache.where((c) => (c['name'] ?? '').toString() == (merged['client_name'] ?? '').toString()).toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (ctx2, scrollCtrl) => SingleChildScrollView(
              controller: scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
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
                  _phoneActionCard(context, phone, company, client: clientForWhatsApp.isNotEmpty ? clientForWhatsApp.first : null),
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
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => PilotHelpers.copyText(context, 'Subject: $subject\n\n$body', 'Email'), icon: const Icon(Icons.copy, size: 15), label: const Text('Copy Email'))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => PilotHelpers.whatsAppReport(merged),
                          icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                          label: const Text('WhatsApp Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () => PilotHelpers.exportSingleEmailPdf(merged),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                          label: const Text('PDF Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static void showFollowupDetail(BuildContext context, Map<String, dynamic> j) {
    final company = (j['company'] ?? 'Unknown').toString();
    final email = (j['email'] ?? '').toString();
    final body = (j['email_body'] ?? j['body'] ?? 'Follow-up sent 3 days after first email.').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
      ),
    );
  }

  static void showReplyDetail(BuildContext context, Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx2, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
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
                      onPressed: () => PilotHelpers.whatsAppReport(r),
                      icon: const Icon(Icons.chat, color: Colors.white, size: 16),
                      label: const Text('WhatsApp Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => PilotHelpers.exportSingleEmailPdf(r),
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
        ),
      ),
    );
  }
}
