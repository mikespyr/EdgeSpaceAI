import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'room_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alerts = state.alerts.where((a) {
      if (filter == 'open') return !a.acknowledged;
      if (filter == 'critical') return a.severity == Severity.critical;
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'open', label: Text('Open')),
              ButtonSegment(value: 'critical', label: Text('Critical')),
            ],
            selected: {filter},
            onSelectionChanged: (v) => setState(() => filter = v.first),
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            const EmptyState(icon: Icons.notifications_off_outlined, title: 'No alerts', body: 'There are no events matching this filter.')
          else
            ...alerts.map((alert) {
              final room = state.roomByIdOrNull(alert.roomId);
              if (room == null) {
                return const SizedBox.shrink();
              }
              final color = switch (alert.severity) { Severity.critical => EdgeColors.red, Severity.warning => EdgeColors.amber, Severity.info => EdgeColors.blue };
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.warning_amber_rounded, color: color)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w800))), StatusChip(label: alert.acknowledged ? 'Acknowledged' : 'Open', color: alert.acknowledged ? EdgeColors.muted : color)]),
                        const SizedBox(height: 4),
                        Text('${state.buildingOf(room).name} / ${room.name}', style: const TextStyle(color: EdgeColors.muted, fontSize: 10)),
                        const SizedBox(height: 7),
                        Text(alert.message, style: const TextStyle(fontSize: 11, color: EdgeColors.muted, height: 1.4)),
                        const SizedBox(height: 9),
                        Row(children: [
                          Text(DateFormat('d MMM · HH:mm').format(alert.createdAt), style: const TextStyle(fontSize: 10, color: EdgeColors.muted)),
                          const Spacer(),
                          if (!alert.acknowledged) TextButton(onPressed: () => state.acknowledgeAlert(alert.id), child: const Text('Acknowledge')),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}
