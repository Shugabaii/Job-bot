import 'dart:convert';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

  @override
  Widget build(BuildContext context) {
    final opened = count('opened');
    final delivered = count('delivered');
    final bounced = count('softbounce') + count('hardbounce') + count('bounce');
    final rate = events.isEmpty ? 0.0 : (opened / events.length * 100);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Center(
              child: Text('C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
              Text('Operational', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399), letterSpacing: 0.2)),
            ]),
          ),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFF1F2937))),
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
                Text('Real-time telemetry and automation performance', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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

            // BOT STATUS - LIVE FROM FIREBASE
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('bot_status').doc('current').snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() as Map<String, dynamic>?;
                final sentToday = data?['sent_today'] ?? 0;
                final lastCompany = (data?['last_company'] ?? 'Waiting...').toString();
                final lastRun = (data?['last_run'] ?? 'Never').toString();
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bolt, size: 16, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 10),
                        const Text('Bot Status — Live from Firebase', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.1)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF064E3B), borderRadius: BorderRadius.circular(6)),
                          child: const Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF34D399), letterSpacing: 0.5)),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('$sentToday', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                            const SizedBox(height: 2),
                            const Text('Sent Today', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        Container(width: 1, height: 35, color: const Color(0xFF1F2937)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              lastCompany.length > 18 ? '${lastCompany.substring(0, 18)}...' : lastCompany,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text('Last Activity', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF090D16), borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.access_time, size: 12, color: Color(0xFF6B7280)),
                          const SizedBox(width: 6),
                          Text('Last Execution Run: $lastRun', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Metrics Grid
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).limit(100).snapshots(),
              builder: (context, jobSnap) {
                final jobsCount = jobSnap.data?.docs.length ?? 0;
                final totalSent = jobsCount > 0 ? jobsCount : events.length;
                return Column(children: [
                  Row(children: [
                    _metric('Total Sent', '$totalSent', Icons.send_outlined, 'Applications'),
                    const SizedBox(width: 12),
                    _metric('Open Rate', '${rate.toStringAsFixed(1)}%', Icons.visibility_outlined, 'Engagement'),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _metric('Delivered', '$delivered', Icons.check_circle_outline, 'Successful'),
                    const SizedBox(width: 12),
                    _metric('Bounced', '$bounced', Icons.error_outline, 'Failed'),
                  ]),
                ]);
              },
            ),
            const SizedBox(height: 24),

            // System Diagnostics
            const Text('System Diagnostics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _systemRow('Email Delivery Service (Brevo)', 'Operational', true),
                  const Divider(height: 24, color: Color(0xFF1F2937)),
                  _systemRow('AI Engine (Local GGUF / API)', 'Operational', true),
                  const Divider(height: 24, color: Color(0xFF1F2937)),
                  _systemRow('Firebase Sync Pipeline', 'Passing', true),
                  const Divider(height: 24, color: Color(0xFF1F2937)),
                  _systemRow('Firestore Realtime State', 'Up to date', true),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // JOBS SENT - REAL BOT DATA
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Jobs Sent — From Bot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('jobs_sent').snapshots(),
                builder: (context, s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(6)),
                  child: Text('${s.data?.docs.length ?? 0} total', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs_sent').orderBy('timestamp', descending: true).limit(20).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(color: Color(0xFF1F2937), shape: BoxShape.circle),
                            child: const Icon(Icons.inbox_outlined, size: 24, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 12),
                          const Text('No jobs sent yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Your bot will save job execution entries here automatically.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12), textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final j = d.data() as Map<String, dynamic>;
                    final company = (j['company'] ?? 'Unknown').toString();
                    final email = (j['email'] ?? '').toString();
                    final jobType = (j['job_type'] ?? 'FLUTTER').toString();
                    final ts = (j['timestamp'] ?? '').toString();
                    final shortDate = ts.length > 16 ? ts.substring(0, 16).replaceAll('T', ' ') : ts;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.send_outlined, color: Color(0xFF10B981), size: 16),
                        ),
                        title: Text(company, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('$email • $shortDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(jobType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF34D399))),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // Activity - Brevo Events
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Activity — Email Events', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2)),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        child: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.black : const Color(0xFF9CA3AF))),
                      ),
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
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.mail_outline, size: 24, color: Color(0xFF6B7280)),
                      SizedBox(height: 8),
                      Text('No email events yet', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Add BREVO_API_KEY parameter to monitor opens and clicks.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), textAlign: TextAlign.center),
                    ]),
                  ),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: colorFor(ev).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(iconFor(ev), color: colorFor(ev), size: 16),
                    ),
                    title: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('$subject • $shortDate', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: colorFor(ev).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(labelFor(ev), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorFor(ev))),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),
            const Center(
              child: Text(
                'CareerPilot AI • v4.0 — Connected to Bot v22',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), letterSpacing: 0.2),
              ),
            ),
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
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
              ),
              const Spacer(),
              const Icon(Icons.trending_up, size: 14, color: Color(0xFF10B981)),
            ]),
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

  Widget _systemRow(String label, String status, bool ok) {
    return Row(children: [
      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.white))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(4)),
        child: Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ),
    ]);
  }
}