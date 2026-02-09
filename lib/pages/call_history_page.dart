import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_history_entry.dart';
import '../services/sip_service.dart';

class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sipService = context.watch<SipService>();
    final history = sipService.callHistory;

    return Scaffold(
      body: history.isEmpty
          ? _buildEmptyState(context)
          : _buildHistoryList(context, history, sipService),
      floatingActionButton: history.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showClearConfirmation(context, sipService),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear History'),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No call history',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<CallHistoryEntry> history,
    SipService sipService,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = history[index];
        return _buildHistoryItem(context, entry, sipService);
      },
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    CallHistoryEntry entry,
    SipService sipService,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _buildCallIcon(entry, theme),
      title: Text(
        entry.remoteName?.isNotEmpty == true
            ? entry.remoteName!
            : entry.remoteNumber,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Icon(
            _getDirectionIcon(entry.direction),
            size: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Text(entry.formattedTimestamp),
          if (entry.duration != null) ...[
            const SizedBox(width: 8),
            Text('(${entry.formattedDuration})'),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sipService.isRegistered)
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => sipService.call(entry.remoteNumber),
              tooltip: 'Call back',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => sipService.deleteCallHistoryEntry(entry.id),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildCallIcon(CallHistoryEntry entry, ThemeData theme) {
    IconData icon;
    Color color;

    switch (entry.status) {
      case CallStatus.answered:
        icon = entry.direction == CallDirection.incoming
            ? Icons.call_received
            : Icons.call_made;
        color = Colors.green;
        break;
      case CallStatus.missed:
        icon = Icons.call_missed;
        color = Colors.red;
        break;
      case CallStatus.rejected:
        icon = Icons.call_missed_outgoing;
        color = Colors.orange;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  IconData _getDirectionIcon(CallDirection direction) {
    return direction == CallDirection.incoming
        ? Icons.arrow_downward
        : Icons.arrow_upward;
  }

  void _showClearConfirmation(BuildContext context, SipService sipService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Call History'),
        content: const Text(
          'Are you sure you want to clear all call history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              sipService.clearCallHistory();
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
