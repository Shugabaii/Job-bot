import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app_state.dart';
import 'pilot_helpers.dart';
import 'pilot_dialogs.dart';
import 'pages/overview_page.dart';
import 'pages/clients_page.dart';
import 'pages/activity_page.dart';
import 'pages/queue_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // FIX: Read from FIREBASE SERVER, not phone cache.
    // Cache was showing old 0 data and freezing the app.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
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
          backgroundColor: const Color(0xFF090D16),
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
  int _currentIndex = 0;
  String filter = 'All';
  String searchQuery = '';
  int _jobsLimit = 20;
  int _followupsLimit = 20;
  bool _showReplies = false;
  bool _showRecentEmails = false;
  bool _showFollowups = false;
  String _recentEmailFilter = 'All';

  // LOCAL copies - always synced to appState (the single brain)
  String _selectedClientFilter = 'All';
  String _activeClientId = 'user';
  List<Map<String, dynamic>> _clientsCache = [];

  @override
  void initState() {
    super.initState();
    // FIX: Don't block UI - run in background, don't await
    Future.microtask(() async {
      await _ensureDefaultUser();
      await _loadActiveClient();
    });
  }

  // Keep local + appState in sync - this is the fix for 0-then-appears
  void _syncToAppState() {
    appState.selectedClientFilter = _selectedClientFilter;
    appState.activeClientId = _activeClientId;
    appState.clientsCache = _clientsCache;
    appState.jobsLimit = _jobsLimit;
    appState.followupsLimit = _followupsLimit;
    // Don't call notifyListeners here - setState already rebuilds Dashboard
    // Pages that listen to appState directly will get it via Dashboard rebuild
  }

  Future<void> _ensureDefaultUser() async {
    try {
      final ref = FirebaseFirestore.instance.collection('clients').doc('user');
      // FIX: Always read from SERVER (Firebase), never from phone cache
      DocumentSnapshot doc = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
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
        final d = doc.data() as Map<String, dynamic>? ?? {};
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
        } else if ((d['client_type'] ?? '').toString() != 'freelancer') {
          await ref.set({'client_type': 'freelancer'}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('ensureDefaultUser error (will retry next open): $e');
    }
  }

  String get _activeClientDisplayName {
    // Use appState helper - same logic everywhere
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
      // FIX: Read from SERVER, not cache
      final doc = await FirebaseFirestore.instance
          .collection('bot_config')
          .doc('active')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _activeClientId = doc.exists
              ? ((doc.data() as Map<String, dynamic>? ?? {})['active_client_id'] ?? (doc.data() as Map<String, dynamic>? ?? {})['client_id'] ?? 'user').toString()
              : 'user';
          _syncToAppState();
        });
      }
    } catch (e) {
      debugPrint('loadActiveClient error: $e');
    }
  }

  Future<void> _setActiveClient(String clientId) async {
    try {
      await FirebaseFirestore.instance.collection('bot_config').doc('active').set({
        'active_client_id': clientId,
        'client_id': clientId,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _activeClientId = clientId;
          _syncToAppState();
        });
        // Also notify any page listening directly to appState
        appState.setActiveClient(clientId);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Active client updated to $clientId.'), backgroundColor: const Color(0xFF10B981)));
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
        setState(() {
          _activeClientId = 'user';
          _syncToAppState();
        });
        appState.setActiveClient('user');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Active client cleared. Using your profile - Habibu Armayau Isah.'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
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
        if (mounted) {
          setState(() {
            _activeClientId = 'user';
            _syncToAppState();
          });
          appState.setActiveClient('user');
        }
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

  Future<void> _showManualActions(String docId, String company, String status) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(company, style: const TextStyle(color: Colors.white)),
        content: Text('Status: ${PilotHelpers.manualStatusLabel(status)}\n\nLong-press action:', style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Manual job deleted.'), backgroundColor: Color(0xFF10B981)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Listen to appState too - if a page changes filter, Dashboard rebuilds with same filter
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        // If appState was changed from a page, sync it back to local so pages get same value
        if (appState.selectedClientFilter != _selectedClientFilter) {
          _selectedClientFilter = appState.selectedClientFilter;
        }
        if (appState.activeClientId != _activeClientId) {
          _activeClientId = appState.activeClientId;
        }
        if (appState.clientsCache.isNotEmpty && _clientsCache.isEmpty) {
          _clientsCache = appState.clientsCache;
        }

        final pages = <Widget>[
          OverviewPage(
            activeClientDisplayName: _activeClientDisplayName,
            matchesClientFilter: (m) => PilotHelpers.matchesClientFilter(m, _selectedClientFilter, _clientsCache),
            parseDate: PilotHelpers.parseDate,
            dayKey: PilotHelpers.dayKey,
            dayLabel: PilotHelpers.dayLabel,
            onOpenSettings: () => PilotDialogs.showBotSettings(context),
            onRefresh: () => setState(() {}),
          ),
          ClientsPage(
            activeClientId: _activeClientId,
            onClientsUpdated: (clients) {
              if (!mounted) return;
              if (clients.isEmpty && _clientsCache.isNotEmpty) return;
              setState(() {
                _clientsCache = clients;
                _syncToAppState();
              });
              // Push to shared brain so Overview/Activity see same clients instantly
              appState.setClients(clients);
            },
            onUseMeHabibu: _useMeHabibu,
            onAddClient: () => PilotDialogs.showAddClient(context),
            senderEmailForClient: PilotHelpers.senderEmailForClient,
            onDeleteClient: _deleteClient,
            onEditSenderEmail: (id, name, email) => PilotDialogs.editSenderEmail(context, id, name, email),
            onSetActiveClient: _setActiveClient,
            onShowConnectLink: (id, name, email) => PilotDialogs.showConnectLink(context, id, name, email),
            onPauseResumeClient: _pauseResumeClient,
            onShowLimitDialog: (id, name, cur) => PilotDialogs.showLimit(context, id, name, cur),
            onPasteCv: (id, name, link) => PilotDialogs.pasteCv(context, id, name, link),
            onEditProof: (id, name, c) => PilotDialogs.editProof(context, id, name, c),
          ),
          ActivityPage(
            selectedClientFilter: _selectedClientFilter,
            clientsCache: _clientsCache,
            searchQuery: searchQuery,
            filter: filter,
            showReplies: _showReplies,
            showRecentEmails: _showRecentEmails,
            showFollowups: _showFollowups,
            recentEmailFilter: _recentEmailFilter,
            jobsLimit: _jobsLimit,
            followupsLimit: _followupsLimit,
            onClientFilterChanged: (v) {
              setState(() {
                _selectedClientFilter = v;
                _syncToAppState();
              });
              appState.setFilter(v);
            },
            onSearchChanged: (v) => setState(() => searchQuery = v),
            onFilterChanged: (v) => setState(() => filter = v),
            onToggleReplies: () => setState(() => _showReplies = !_showReplies),
            onToggleRecentEmails: () => setState(() => _showRecentEmails = !_showRecentEmails),
            onToggleFollowups: () => setState(() => _showFollowups = !_showFollowups),
            onRecentEmailFilterChanged: (v) => setState(() => _recentEmailFilter = v),
            onLoadMoreJobs: () => setState(() {
              _jobsLimit += 20;
              _syncToAppState();
            }),
            matchesClientFilter: (m) => PilotHelpers.matchesClientFilter(m, _selectedClientFilter, _clientsCache),
            clientDisplayName: PilotHelpers.clientDisplayName,
            formatDate: PilotHelpers.formatDate,
            onShowEmailDetail: (j) => PilotDialogs.showEmailDetail(context, j, _clientsCache),
            onShowReplyDetail: (r) => PilotDialogs.showReplyDetail(context, r),
            onShowFollowupDetail: (j) => PilotDialogs.showFollowupDetail(context, j),
          ),
          QueuePage(
            matchesManualFilter: (m) => PilotHelpers.matchesManualFilter(m, _selectedClientFilter, _clientsCache),
            manualStatusColor: PilotHelpers.manualStatusColor,
            manualStatusLabel: PilotHelpers.manualStatusLabel,
            onShowManualActions: _showManualActions,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]), borderRadius: BorderRadius.circular(10)),
                      child: const Center(child: Text('CP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
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
              IconButton(
                tooltip: 'Export All PDF',
                onPressed: () => PilotHelpers.exportAllEmailsPdf(_selectedClientFilter, _clientsCache),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF064E3B).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                child: const Row(children: [Icon(Icons.circle, size: 6, color: Color(0xFF10B981)), SizedBox(width: 6), Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF34D399)))]),
              ),
            ],
            bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFF1F2937))),
          ),
          floatingActionButton: _currentIndex == 3
              ? FloatingActionButton.extended(
                  onPressed: () => PilotDialogs.showAddManual(context, _activeClientId, _clientsCache),
                  backgroundColor: const Color(0xFF10B981),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Send Manually', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                )
              : null,
          // FIX: Only show the current page - before IndexedStack loaded all 4 pages at once from Firebase = freeze
          body: pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: const Color(0xFF111827),
            indicatorColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined, color: Color(0xFF9CA3AF)), selectedIcon: Icon(Icons.home, color: Color(0xFF10B981)), label: 'Overview'),
              NavigationDestination(icon: Icon(Icons.people_outline, color: Color(0xFF9CA3AF)), selectedIcon: Icon(Icons.people, color: Color(0xFF10B981)), label: 'Clients'),
              NavigationDestination(icon: Icon(Icons.mark_email_unread_outlined, color: Color(0xFF9CA3AF)), selectedIcon: Icon(Icons.mark_email_unread, color: Color(0xFF10B981)), label: 'Activity'),
              NavigationDestination(icon: Icon(Icons.queue_outlined, color: Color(0xFF9CA3AF)), selectedIcon: Icon(Icons.queue, color: Color(0xFF10B981)), label: 'Queue'),
            ],
          ),
        );
      },
    );
  }
}
