import 'package:intl/intl.dart';

enum CallDirection { incoming, outgoing }

enum CallStatus { missed, answered, rejected }

class CallHistoryEntry {
  final String id;
  final String remoteNumber;
  final String? remoteName;
  final CallDirection direction;
  final CallStatus status;
  final DateTime timestamp;
  final int? duration;

  CallHistoryEntry({
    required this.id,
    required this.remoteNumber,
    this.remoteName,
    required this.direction,
    required this.status,
    required this.timestamp,
    this.duration,
  });

  String get formattedDuration {
    if (duration == null) return '-';
    final seconds = duration! % 60;
    final minutes = (duration! ~/ 60) % 60;
    final hours = duration! ~/ 3600;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat.Hm().format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat.Hm().format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat.E().add_jm().format(timestamp);
    } else {
      return DateFormat.yMd().add_jm().format(timestamp);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'remoteNumber': remoteNumber,
    if (remoteName != null) 'remoteName': remoteName,
    'direction': direction.name,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
    if (duration != null) 'duration': duration,
  };

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CallHistoryEntry(
        id: json['id'] as String,
        remoteNumber: json['remoteNumber'] as String,
        remoteName: json['remoteName'] as String?,
        direction: CallDirection.values.firstWhere(
          (e) => e.name == json['direction'],
        ),
        status: CallStatus.values.firstWhere((e) => e.name == json['status']),
        timestamp: DateTime.parse(json['timestamp'] as String),
        duration: json['duration'] as int?,
      );
}
