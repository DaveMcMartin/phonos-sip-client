import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/log_service.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all logs',
            onPressed: () {
              final logs = context.read<LogService>().logs.join('\n');
              Clipboard.setData(ClipboardData(text: logs));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              context.read<LogService>().clearLogs();
            },
          ),
        ],
      ),
      body: Consumer<LogService>(
        builder: (context, logService, child) {
          final logs = logService.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'No logs available',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              return SelectableText(
                logs[index],
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
              );
            },
          );
        },
      ),
    );
  }
}
