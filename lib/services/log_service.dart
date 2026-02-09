import 'package:flutter/material.dart';

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  void addLog(String message) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .split('T')
        .last
        .substring(0, 8);
    _logs.add('[$timestamp] $message');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }
}
