import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  String selectedClientFilter = 'All';
  String activeClientId = 'user';
  List<Map<String, dynamic>> clientsCache = [];
  int jobsLimit = 20;
  int followupsLimit = 20;

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
    clientsCache = c;
    notifyListeners();
  }

  String get activeClientDisplayName {
    if (activeClientId == 'user') return 'Habibu Armayau Isah';
    final m = clientsCache.where((c) => (c['id'] ?? '').toString() == activeClientId).toList();
    if (m.isNotEmpty) return (m.first['name'] ?? activeClientId).toString();
    return activeClientId;
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
}

// ONE global instance for whole app - like your old single file
final appState = AppState();
