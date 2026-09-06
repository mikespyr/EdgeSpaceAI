import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/sensor_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  var tab = 1;
  SensorType metric = SensorType.temperature;
  Aggregation aggregation = Aggregation.average;
  RangePreset range = RangePreset.day7;
  String buildingId = 'all';
  String roomId = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final candidateRooms = state.rooms.where((r) => buildingId == 'all' || r.buildingId == buildingId).toList();
    final selectedRooms = candidateRooms
        .where((r) => roomId == 'all' || r.id == roomId)
        .where((r) => state.hasTelemetryInRange(r.id, range))
        .toList();
    final comparison = selectedRooms
        .map((room) => MapEntry(room.name, state.aggregateFor(room, metric, range, aggregation)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Row(children: [
            Expanded(child: Text('Analytics', style: Theme.of(context).textTheme.headlineSmall)),
            IconButton(onPressed: () => _copyAnalyticsSummary(state), icon: const Icon(Icons.ios_share_rounded), tooltip: 'Copy summary'),
          ]),
          const SizedBox(height: 14),
          _AnalyticsTabs(value: tab, onChanged: (v) => setState(() => tab = v)),
          const SizedBox(height: 14),
          if (tab == 0) _overview(state, comparison),
          if (tab == 1) _compare(state, candidateRooms, comparison),
          if (tab == 2) _reports(state),
        ],
      ),
    );
  }

  Widget _overview(AppState state, List<MapEntry<String, double>> comparison) {
    final best = [...state.snapshotsWithData]..sort((a, b) => b.score.compareTo(a.score));
    final worst = [...state.snapshotsWithData]..sort((a, b) => a.score.compareTo(b.score));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          KpiCard(title: 'Average Score', value: '${state.averageScore}', icon: Icons.eco_rounded, accent: EdgeColors.green, caption: 'across all rooms'),
          KpiCard(title: 'Active Alerts', value: '${state.activeAlerts}', icon: Icons.notifications_active_rounded, accent: EdgeColors.red, caption: 'open events'),
          KpiCard(title: 'Best Room', value: best.isEmpty ? '-' : best.first.room.name, icon: Icons.verified_rounded, accent: EdgeColors.blue, caption: best.isEmpty ? '' : '${best.first.score}/100'),
          KpiCard(title: 'Priority Room', value: worst.isEmpty ? '-' : worst.first.room.name, icon: Icons.priority_high_rounded, accent: EdgeColors.amber, caption: worst.isEmpty ? '' : '${worst.first.score}/100'),
        ],
      ),
      const SizedBox(height: 18),
      const SectionHeader('Cross-space snapshot', subtitle: 'Average temperature by room'),
      const SizedBox(height: 10),
      GlassCard(child: RoomComparisonBarChart(values: comparison.take(8).toList(), type: metric)),
      const SizedBox(height: 18),
      const SectionHeader('Insights', subtitle: 'Automatically detected patterns'),
      const SizedBox(height: 10),
      ...state.allInsights.take(5).map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(i.severity == Severity.info ? Icons.insights_rounded : Icons.warning_amber_rounded, color: i.severity == Severity.info ? EdgeColors.green : EdgeColors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 3), Text(i.body, style: const TextStyle(fontSize: 11, color: EdgeColors.muted, height: 1.4))])),
              ]),
            ),
          )),
    ]);
  }

  Widget _compare(AppState state, List<Room> candidateRooms, List<MapEntry<String, double>> comparison) {
    final safeRoomId = candidateRooms.any((r) => r.id == roomId) ? roomId : 'all';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<SensorType>(
            initialValue: metric,
            decoration: const InputDecoration(labelText: 'Parameter', isDense: true),
            items: SensorType.values.where((e) => e != SensorType.motion).map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
            onChanged: (v) => setState(() => metric = v ?? metric),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: DropdownButtonFormField<Aggregation>(
            initialValue: aggregation,
            decoration: const InputDecoration(labelText: 'Aggregation', isDense: true),
            items: Aggregation.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
            onChanged: (v) => setState(() => aggregation = v ?? aggregation),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<RangePreset>(
            initialValue: range,
            decoration: const InputDecoration(labelText: 'Time Range', isDense: true),
            items: RangePreset.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
            onChanged: (v) => setState(() => range = v ?? range),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: buildingId,
            decoration: const InputDecoration(labelText: 'Buildings', isDense: true),
            items: [const DropdownMenuItem(value: 'all', child: Text('All Buildings')), ...state.buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))],
            onChanged: (v) => setState(() {
              buildingId = v ?? 'all';
              roomId = 'all';
            }),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: safeRoomId,
        decoration: const InputDecoration(labelText: 'Room filter', isDense: true, prefixIcon: Icon(Icons.meeting_room_outlined)),
        items: [const DropdownMenuItem(value: 'all', child: Text('All Rooms')), ...candidateRooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))],
        onChanged: (v) => setState(() => roomId = v ?? 'all'),
      ),
      const SizedBox(height: 17),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${aggregation.label} ${metric.label}', style: const TextStyle(fontWeight: FontWeight.w800))),
            StatusChip(label: range.label, color: metric.accent),
          ]),
          const SizedBox(height: 10),
          RoomComparisonBarChart(values: comparison.take(8).toList(), type: metric),
        ]),
      ),
      const SizedBox(height: 18),
      SectionHeader('Room Ranking', subtitle: 'Highest ${metric.label.toLowerCase()} first'),
      const SizedBox(height: 9),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          children: comparison.take(10).toList().asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final item = entry.value;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              leading: CircleAvatar(radius: 15, backgroundColor: metric.accent.withValues(alpha: .13), child: Text('$rank', style: TextStyle(color: metric.accent, fontSize: 11, fontWeight: FontWeight.w800))),
              title: Text(item.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              trailing: Text('${item.value.toStringAsFixed(metric == SensorType.temperature ? 1 : 0)}${metric.unit}', style: TextStyle(fontWeight: FontWeight.w800, color: metric.accent)),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _reports(AppState state) {
    final snapshots = state.snapshotsWithData;
    final avgT = snapshots.isEmpty ? 0.0 : snapshots.map((e) => e.temperature).reduce((a, b) => a + b) / snapshots.length;
    final avgH = snapshots.isEmpty ? 0.0 : snapshots.map((e) => e.humidity).reduce((a, b) => a + b) / snapshots.length;
    final activity = snapshots.where((e) => e.motion).length;
    final worst = [...snapshots]..sort((a, b) => a.score.compareTo(b.score));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: EdgeColors.blue.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.description_rounded, color: EdgeColors.blue)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Weekly Smart-Space Report', style: TextStyle(fontWeight: FontWeight.w800)), Text('${DateFormat('d MMM').format(DateTime.now().subtract(const Duration(days: 7)))} – ${DateFormat('d MMM yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 10, color: EdgeColors.muted))])),
          ]),
          const SizedBox(height: 18),
          _ReportLine(label: 'Overall environmental score', value: '${state.averageScore}/100', color: EdgeColors.green),
          _ReportLine(label: 'Average temperature', value: '${avgT.toStringAsFixed(1)}°C', color: EdgeColors.blue),
          _ReportLine(label: 'Average humidity', value: '${avgH.toStringAsFixed(0)}%', color: EdgeColors.cyan),
          _ReportLine(label: 'Rooms currently active', value: '$activity/${snapshots.length}', color: EdgeColors.amber),
          _ReportLine(label: 'Priority space', value: worst.isEmpty ? '-' : worst.first.room.name, color: EdgeColors.red),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          const Text('Automatic summary', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(
            worst.isEmpty
                ? 'No room data are available for this report.'
                : '${worst.first.room.name} currently has the lowest environmental score. Review temperature, humidity and noise trends before the next operating period. The remaining rooms can be prioritized using the comparison filters.',
            style: const TextStyle(fontSize: 12, color: EdgeColors.muted, height: 1.5),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showPendingExport('PDF report generation'),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Generate Detailed Report'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _copyCsv(state),
          icon: const Icon(Icons.table_view_rounded),
          label: const Text('Copy CSV'),
        ),
      ),
    ]);
  }

  Future<void> _copyAnalyticsSummary(AppState state) async {
    final snapshots = state.snapshotsWithData;
    final lines = <String>[
      'EdgeSpace AI analytics summary',
      'Average score: ${state.averageScore}/100',
      'Active alerts: ${state.activeAlerts}',
      'Rooms with data: ${snapshots.length}/${state.rooms.length}',
      ...snapshots.map(
        (snapshot) =>
            '${snapshot.room.name}: ${snapshot.temperature.toStringAsFixed(1)}°C, ${snapshot.humidity.toStringAsFixed(0)}%, score ${snapshot.score}/100',
      ),
    ];

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics summary copied to clipboard.')),
    );
  }

  Future<void> _copyCsv(AppState state) async {
    final rows = <String>[
      'room,building,temperature_c,humidity_percent,noise,score,status',
      ...state.snapshotsWithData.map((snapshot) {
        final building = state.buildingOf(snapshot.room).name.replaceAll(',', ' ');
        final room = snapshot.room.name.replaceAll(',', ' ');
        return '$room,$building,${snapshot.temperature.toStringAsFixed(2)},${snapshot.humidity.toStringAsFixed(2)},${snapshot.noise.toStringAsFixed(2)},${snapshot.score},${snapshot.statusText}';
      }),
    ];

    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV data copied to clipboard.')),
    );
  }

  void _showPendingExport(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is not wired to a file exporter yet.'),
      ),
    );
  }
}

class _AnalyticsTabs extends StatelessWidget {
  const _AnalyticsTabs({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Overview', 'Compare', 'Reports'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: EdgeColors.panel2, borderRadius: BorderRadius.circular(13), border: Border.all(color: EdgeColors.stroke)),
      child: Row(children: List.generate(labels.length, (i) {
        final selected = value == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(color: selected ? const Color(0xFFBFD9FF) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
              child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF0B2130) : EdgeColors.muted)),
            ),
          ),
        );
      })),
    );
  }
}

class _ReportLine extends StatelessWidget {
  const _ReportLine({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: EdgeColors.muted))), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
    );
  }
}
