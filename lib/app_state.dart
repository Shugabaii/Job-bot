import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  // --- Filters / Active Client (Single Brain) ---
  String selectedClientFilter = 'All';
  String activeClientId = 'user';
  List<Map<String, dynamic>> clientsCache = [];
  int jobsLimit = 20;
  int followupsLimit = 20;

  // --- PROFESSIONAL: Instant Feel ---
  // Last data from Firebase - shown INSTANTLY while new data loads in background.
  // This is how Gmail / WhatsApp work. Never show 0, never show blank spinner.
  List<Map<String, dynamic>> lastJobs = [];
  List<Map<String, dynamic>> lastFollowups = [];
  bool hasLoadedJobs = false; // false = first open ever, show skeleton. true = we have old data to show instantly
  bool isSyncing = false; // true = fetching new data from server in background
  DateTime? lastSyncAt;
  String? lastError;

  void setFilter(String v) {
    if (selectedClientFilter == v) return;
    selectedClientFilter = v;
    notifyListeners();
  }

  void setActiveClient(String id) {
    if (activeClientId == id) return;
    activeClientId = id;
    notifyListeners();
  }

  void setClients(List<Map<String, dynamic>> c) {
    // Professional: Don't overwrite good cache with empty list
    // This was your old 0-bug: empty snapshot overwrote real data
    if (c.isEmpty && clientsCache.isNotEmpty) return;
    clientsCache = c;
    notifyListeners();
  }

  // --- PROFESSIONAL: Jobs Cache ---
  void setJobs(List<Map<String, dynamic>> jobs) {
    // Don't overwrite good data with empty while syncing
    if (jobs.isEmpty && lastJobs.isNotEmpty && isSyncing) return;
    lastJobs = jobs;
    hasLoadedJobs = true;
    lastSyncAt = DateTime.now();
    lastError = null;
    notifyListeners();
  }

  void setFollowups(List<Map<String, dynamic>> f) {
    if (f.isEmpty && lastFollowups.isNotEmpty && isSyncing) return;
    lastFollowups = f;
    notifyListeners();
  }

  void setSyncing(bool v) {
    if (isSyncing == v) return;
    isSyncing = v;
    notifyListeners();
  }

  void setError(String e) {
    lastError = e;
    isSyncing = false;
    notifyListeners();
  }

  void clearCache() {
    lastJobs = [];
    lastFollowups = [];
    hasLoadedJobs = false;
    notifyListeners();
  }

  // --- Helpers ---
  String get activeClientDisplayName {
    if (activeClientId == 'user') return 'Habibu Armayau Isah';
    final m = clientsCache.where((c) => (c['id'] ?? '').toString() == activeClientId).toList();
    if (m.isNotEmpty) return (m.first['name'] ?? activeClientId).toString();
    return activeClientId;
  }

  String get lastSyncLabel {
    if (lastSyncAt == null) return 'Not synced yet';
    final diff = DateTime.now().difference(lastSyncAt!);
    if (diff.inSeconds < 10) return 'Updated just now';
    if (diff.inMinutes < 1) return 'Updated ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated ${diff.inDays}d ago';
  }

  bool matchesClientFilter(Map<String, dynamic> j) {
    if (selectedClientFilter == 'All') return true;
    final cn = (j['client_name'] ?? '').toString().toLowerCase();
    final cid = (j['client_id'] ?? '').toString().toLowerCase();
    final f = selectedClientFilter.toLowerCase();
    final match = clientsCache.where((c) => (c['id'] ?? '').toString().toLowerCase() == f).toList();
    final name = match.isNotEmpty ? (match.first['name'] ?? '').toString().toLowerCase() : f;
    return cn == name || cid == f || cn == f;
  }

  // Filtered jobs from CACHE - instant, no Firestore wait
  List<Map<String, dynamic>> get filteredJobs {
    return lastJobs.where((j) => matchesClientFilter(j)).toList();
  }
}

// ONE global instance for whole app - like your old single file
final appState = AppState();
