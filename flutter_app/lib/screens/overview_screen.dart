import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import 'alerts_screen.dart';
import 'provision_device_screen.dart';
import 'room_detail_screen.dart';
import 'spaces_screen.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  var period = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = switch (period) {
      0 => RangePreset.hour24,
      1 => RangePreset.day7,
      _ => RangePreset.day30,
    };

    final snapshots = state.rooms
        .where((room) => state.hasTelemetryInRange(room.id, range))
        .map((room) => state.snapshotForRange(room, range))
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    final good = snapshots.where((s) => s.score >= 85).length;
    final attention = snapshots.where((s) => s.score >= 65 && s.score < 85).length;
    final critical = snapshots.where((s) => s.score < 65).length;
    final waiting = state.rooms.length - snapshots.length;
    final rangeAverage = snapshots.isEmpty
        ? 0
        : (snapshots.fold<int>(0, (sum, item) => sum + item.score) /
                snapshots.length)
            .round();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await state.checkBackend();
          if (!state.demoMode) await state.syncHistory();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            Row(children: [
              const BrandMark(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 1),
                  Text(DateFormat('EEEE, d MMMM').format(DateTime.now()), style: const TextStyle(color: EdgeColors.muted, fontSize: 12)),
                ]),
              ),
              IconButton(
                tooltip: 'Add device',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProvisionDeviceScreen())),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'Alerts',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
                icon: Badge(
                  isLabelVisible: state.activeAlerts > 0,
                  label: Text('${state.activeAlerts}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _PeriodSelector(
              value: period,
              onChanged: (value) {
                setState(() => period = value);
                if (!state.demoMode) {
                  final selectedRange = switch (value) {
                    0 => RangePreset.hour24,
                    1 => RangePreset.day7,
                    _ => RangePreset.day30,
                  };
                  state.syncHistory(range: selectedRange);
                }
              },
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                KpiCard(title: 'Buildings', value: '${state.buildings.length}', icon: Icons.apartment_rounded, accent: EdgeColors.blue),
                KpiCard(title: 'Rooms', value: '${state.rooms.length}', icon: Icons.meeting_room_rounded, accent: EdgeColors.green),
                KpiCard(title: 'Online Devices', value: '${state.onlineDevices}', icon: Icons.sensors_rounded, accent: EdgeColors.green, caption: '${state.provisionedDevices.length} total'),
                KpiCard(title: 'Alerts', value: '${state.activeAlerts}', icon: Icons.warning_amber_rounded, accent: EdgeColors.red, caption: 'need review'),
              ],
            ),
            const SizedBox(height: 18),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Environmental Health', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  StatusChip(
                    label: state.demoMode
                        ? 'Demo'
                        : state.backendOnline
                            ? 'Live'
                            : 'Backend Offline',
                    color: state.demoMode
                        ? EdgeColors.amber
                        : state.backendOnline
                            ? EdgeColors.green
                            : EdgeColors.red,
                    icon: Icons.circle,
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  ScoreRing(score: rangeAverage, size: 112),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(children: [
                      _HealthLegend(color: EdgeColors.green, label: 'Good', value: good),
                      const SizedBox(height: 11),
                      _HealthLegend(color: EdgeColors.amber, label: 'Needs Attention', value: attention),
                      const SizedBox(height: 11),
                      _HealthLegend(color: EdgeColors.red, label: 'Critical', value: critical),
                      if (waiting > 0) ...[
                        const SizedBox(height: 11),
                        _HealthLegend(color: EdgeColors.muted, label: 'Waiting for data', value: waiting),
                      ],
                    ]),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 22),
            SectionHeader(
              'Priority Spaces',
              subtitle: 'Rooms with the lowest environmental score',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Spaces')),
                      body: const SpacesScreen(),
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
            ),
            const SizedBox(height: 11),
            if (snapshots.isEmpty)
              const EmptyState(
                icon: Icons.sensors_off_rounded,
                title: 'Waiting for sensor data',
                body: 'No room has measurements in the selected period yet.',
              )
            else
              ...snapshots.take(3).map((snapshot) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PriorityRoomCard(snapshot: snapshot),
                  )),
            const SizedBox(height: 14),
            SectionHeader(
              'Recent Alerts',
              subtitle: 'Latest events from your spaces',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
                child: const Text('All alerts'),
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
              child: Column(
                children: state.alerts
                    .where((alert) => state.roomByIdOrNull(alert.roomId) != null)
                    .take(3)
                    .map((alert) => _AlertRow(alert: alert))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'Week', 'Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: EdgeColors.panel2, borderRadius: BorderRadius.circular(12), border: Border.all(color: EdgeColors.stroke)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = value == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: selected ? const Color(0xFFBFD9FF) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(color: selected ? const Color(0xFF0B2130) : EdgeColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HealthLegend extends StatelessWidget {
  const _HealthLegend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(color: EdgeColors.muted, fontSize: 12))),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w800)),
    ]);
  }
}

class _PriorityRoomCard extends StatelessWidget {
  const _PriorityRoomCard({required this.snapshot});
  final RoomSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final statusColor = snapshot.score >= 85 ? EdgeColors.green : snapshot.score >= 65 ? EdgeColors.amber : EdgeColors.red;
    return GlassCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoomDetailScreen(room: snapshot.room))),
      child: Row(children: [
        ScoreRing(score: snapshot.score, size: 62),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(snapshot.room.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(state.buildingOf(snapshot.room).name, style: const TextStyle(color: EdgeColors.muted, fontSize: 11)),
            const SizedBox(height: 9),
            Wrap(spacing: 8, runSpacing: 5, children: [
              _MiniMetric(icon: Icons.thermostat_rounded, text: '${snapshot.temperature.toStringAsFixed(1)}°C', color: EdgeColors.blue),
              _MiniMetric(icon: Icons.water_drop_rounded, text: '${snapshot.humidity.toStringAsFixed(0)}%', color: EdgeColors.cyan),
              _MiniMetric(icon: Icons.graphic_eq_rounded, text: snapshot.noise.toStringAsFixed(0), color: EdgeColors.red),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusChip(label: snapshot.statusText, color: statusColor),
          const SizedBox(height: 14),
          const Icon(Icons.chevron_right_rounded, color: EdgeColors.muted),
        ]),
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: color), const SizedBox(width: 3), Text(text, style: const TextStyle(fontSize: 10, color: EdgeColors.muted))]);
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final EdgeAlert alert;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final room = state.roomByIdOrNull(alert.roomId);
    final color = switch (alert.severity) { Severity.critical => EdgeColors.red, Severity.warning => EdgeColors.amber, Severity.info => EdgeColors.blue };
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      leading: Container(width: 31, height: 31, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.warning_amber_rounded, size: 17, color: color)),
      title: Text(alert.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(room?.name ?? 'Removed room', style: const TextStyle(fontSize: 10, color: EdgeColors.muted)),
      trailing: Text(DateFormat('HH:mm').format(alert.createdAt), style: const TextStyle(fontSize: 10, color: EdgeColors.muted)),
    );
  }
}
