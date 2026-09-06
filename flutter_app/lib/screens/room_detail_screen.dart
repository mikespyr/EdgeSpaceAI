import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/sensor_chart.dart';
import 'ai_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({super.key, required this.room});
  final Room room;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  var tab = 0;
  SensorType metric = SensorType.temperature;
  RangePreset range = RangePreset.hour24;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snapshot = state.snapshot(widget.room);
    final device = state.deviceOf(widget.room);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.room.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(state.buildingOf(widget.room).name, style: const TextStyle(fontSize: 10, color: EdgeColors.muted)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: StatusChip(
                label: switch (device.status) {
                  DeviceStatus.online => 'Online',
                  DeviceStatus.warning => 'Warning',
                  DeviceStatus.offline => 'Offline',
                },
                color: switch (device.status) {
                  DeviceStatus.online => EdgeColors.green,
                  DeviceStatus.warning => EdgeColors.amber,
                  DeviceStatus.offline => EdgeColors.red,
                },
                icon: Icons.circle,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
        children: [
          _RoomTabs(value: tab, onChanged: (v) => setState(() => tab = v)),
          const SizedBox(height: 16),
          if (tab == 0) _liveTab(state, snapshot, device),
          if (tab == 1) _analyticsTab(state),
          if (tab == 2) _aiTab(state),
          if (tab == 3) _settingsTab(state, device),
        ],
      ),
    );
  }

  Widget _liveTab(AppState state, RoomSnapshot snapshot, DeviceKit device) {
    final hasData = state.hasTelemetry(widget.room.id);
    final color = !hasData
        ? EdgeColors.muted
        : snapshot.score >= 85
            ? EdgeColors.green
            : snapshot.score >= 65
                ? EdgeColors.amber
                : EdgeColors.red;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          MetricTile(
            type: SensorType.temperature,
            value: state.latestOrNull(widget.room.id, SensorType.temperature),
          ),
          MetricTile(
            type: SensorType.humidity,
            value: state.latestOrNull(widget.room.id, SensorType.humidity),
          ),
          MetricTile(
            type: SensorType.motion,
            value: state.latestOrNull(widget.room.id, SensorType.motion),
          ),
          MetricTile(
            type: SensorType.noise,
            value: state.latestOrNull(widget.room.id, SensorType.noise),
          ),
        ],
      ),
      const SizedBox(height: 16),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Environmental Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: hasData ? snapshot.score / 100 : 0, minHeight: 9, color: color, backgroundColor: EdgeColors.stroke),
              ),
            ),
            const SizedBox(width: 12),
            Text(hasData ? '${snapshot.score}/100' : '--/100', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(13), border: Border.all(color: color.withValues(alpha: .25))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(!hasData ? Icons.sensors_off_rounded : snapshot.score >= 85 ? Icons.location_on_rounded : Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(snapshot.statusText, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 3),
                  Text(!hasData ? 'Waiting for the first sensor packet from this room.' : snapshot.score >= 85 ? 'All monitored parameters are within the preferred profile.' : 'One or more parameters need review. Open AI for prioritized recommendations.', style: const TextStyle(fontSize: 11, color: EdgeColors.muted, height: 1.4)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      const SectionHeader('Latest Activity', subtitle: 'Live device and sensor status'),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Column(children: [
          _InfoRow(icon: Icons.memory_rounded, title: 'Edge Kit', value: device.name, color: EdgeColors.blue),
          _InfoRow(icon: Icons.wifi_rounded, title: 'Signal', value: '${device.rssi} dBm', color: device.rssi > -67 ? EdgeColors.green : EdgeColors.amber),
          _InfoRow(icon: Icons.update_rounded, title: 'Firmware', value: device.firmware, color: EdgeColors.cyan),
          _InfoRow(icon: Icons.schedule_rounded, title: 'Last seen', value: DateFormat('HH:mm:ss').format(device.lastSeen), color: EdgeColors.green),
        ]),
      ),
    ]);
  }

  Widget _analyticsTab(AppState state) {
    final points = state.pointsFor(widget.room.id, metric, range: range);
    final values = points.map((p) => p.value).toList();
    final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final min = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final max = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: RangePreset.values.map((r) => Padding(
          padding: const EdgeInsets.only(right: 7),
          child: ChoiceChip(label: Text(r.label), selected: range == r, onSelected: (_) {
            setState(() => range = r);
            if (!state.demoMode) state.syncHistory(roomId: widget.room.id, range: r);
          }),
        )).toList()),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<SensorType>(
        initialValue: metric,
        decoration: const InputDecoration(labelText: 'Parameter', prefixIcon: Icon(Icons.monitor_heart_outlined)),
        items: SensorType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
        onChanged: (v) => setState(() => metric = v ?? metric),
      ),
      const SizedBox(height: 14),
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${metric.label} (${metric.unit})', style: const TextStyle(fontWeight: FontWeight.w800))),
            StatusChip(label: range.label, color: metric.accent),
          ]),
          const SizedBox(height: 10),
          SensorChart(points: points, type: metric, height: 250),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _MiniStat(title: 'Average', value: avg, type: metric)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(title: 'Minimum', value: min, type: metric)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(title: 'Maximum', value: max, type: metric)),
      ]),
    ]);
  }

  Widget _aiTab(AppState state) {
    final insights = state.insightsFor(widget.room);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: EdgeColors.blue.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_awesome_rounded, color: EdgeColors.blue)),
        const SizedBox(width: 10),
        const Expanded(child: Text('AI Insights', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        Text(DateFormat('HH:mm').format(DateTime.now()), style: const TextStyle(color: EdgeColors.muted, fontSize: 11)),
      ]),
      const SizedBox(height: 13),
      ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightCard(insight: insight),
          )),
      const SizedBox(height: 6),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiScreen(initialRoomId: widget.room.id, standalone: true))),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Ask AI about this room'),
        ),
      ),
    ]);
  }

  Widget _settingsTab(AppState state, DeviceKit device) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Sensor Health', subtitle: 'Hardware channels reporting from this kit'),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        child: Column(
          children: SensorType.values.map((type) {
            final recent = state.pointsFor(widget.room.id, type).isNotEmpty;
            return ListTile(
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: type.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(type.icon, color: type.accent, size: 20)),
              title: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text(recent ? 'Receiving data' : 'No recent data', style: const TextStyle(fontSize: 11)),
              trailing: StatusChip(label: recent ? 'Healthy' : 'Check', color: recent ? EdgeColors.green : EdgeColors.red),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 18),
      SectionHeader('Device', subtitle: device.id),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
        child: Column(children: [
          _InfoRow(
            icon: Icons.online_prediction_rounded,
            title: 'Status',
            value: device.status.name.toUpperCase(),
            color: switch (device.status) {
              DeviceStatus.online => EdgeColors.green,
              DeviceStatus.warning => EdgeColors.amber,
              DeviceStatus.offline => EdgeColors.red,
            },
          ),
          _InfoRow(icon: Icons.wifi_rounded, title: 'RSSI', value: '${device.rssi} dBm', color: EdgeColors.blue),
          _InfoRow(icon: Icons.system_update_rounded, title: 'Firmware', value: device.firmware, color: EdgeColors.cyan),
          _InfoRow(icon: Icons.timelapse_rounded, title: 'Uptime', value: '${device.uptimeHours.toStringAsFixed(1)} h', color: EdgeColors.green),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showFirmwareActionMessage(
            'Restart requires a restart command in the ESP32-C3 firmware. The current BLE protocol does not expose one yet.',
          ),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart Device'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showFirmwareActionMessage(
            'Wi-Fi reconfiguration for an already assigned kit needs a dedicated reprovision flow. For now, delete the kit from Device Manager and provision it again.',
          ),
          icon: const Icon(Icons.wifi_password_rounded),
          label: const Text('Reconfigure Wi-Fi'),
        ),
      ),
    ]);
  }

  void _showFirmwareActionMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RoomTabs extends StatelessWidget {
  const _RoomTabs({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Live', 'Analytics', 'AI', 'Settings'];
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
              child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF0B2130) : EdgeColors.muted)),
            ),
          ),
        );
      })),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.value, required this.color});
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 12, color: EdgeColors.muted)),
      trailing: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.title, required this.value, required this.type});
  final String title;
  final double value;
  final SensorType type;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(children: [
        Text(title, style: const TextStyle(fontSize: 10, color: EdgeColors.muted)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(type == SensorType.temperature ? 1 : 0)}${type.unit}', style: TextStyle(fontWeight: FontWeight.w800, color: type.accent)),
      ]),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.severity) { Severity.critical => EdgeColors.red, Severity.warning => EdgeColors.amber, Severity.info => EdgeColors.green };
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(insight.severity == Severity.info ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: color, size: 20), const SizedBox(width: 8), Expanded(child: Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 9),
        Text(insight.body, style: const TextStyle(fontSize: 12, color: EdgeColors.muted, height: 1.45)),
        if (insight.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Recommendations', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          ...insight.recommendations.map((r) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_rounded, size: 15, color: color), const SizedBox(width: 6), Expanded(child: Text(r, style: const TextStyle(fontSize: 11, color: EdgeColors.muted)))]))),
        ],
      ]),
    );
  }
}
