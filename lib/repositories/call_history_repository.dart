import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_history_entry.dart';

class CallHistoryRepository {
  static const _key = 'call_history';
  static const _maxEntries = 100;

  Future<List<CallHistoryEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((json) => CallHistoryEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> addEntry(CallHistoryEntry entry) async {
    final history = await getHistory();
    history.insert(0, entry);

    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }

    await _saveHistory(history);
  }

  Future<void> deleteEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((entry) => entry.id == id);
    await _saveHistory(history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _saveHistory(List<CallHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = history.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
