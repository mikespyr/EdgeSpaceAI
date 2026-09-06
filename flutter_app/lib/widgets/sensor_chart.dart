import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/models.dart';

class SensorChart extends StatelessWidget {
  const SensorChart({super.key, required this.points, required this.type, this.height = 230, this.showDots = false});
  final List<SensorPoint> points;
  final SensorType type;
  final double height;
  final bool showDots;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No data in this range', style: TextStyle(color: EdgeColors.muted))));
    }
    final shown = points.length > 120 ? points.sublist(points.length - 120) : points;
    final spots = List.generate(shown.length, (i) => FlSpot(i.toDouble(), shown[i].value));
    final values = shown.map((e) => e.value).toList();
    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if ((maxY - minY).abs() < .1) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * .18;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: EdgeColors.stroke.withValues(alpha: .6), strokeWidth: .7)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(type == SensorType.temperature ? 0 : 0), style: const TextStyle(fontSize: 10, color: EdgeColors.muted)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: shown.length > 12 ? shown.length / 4 : 3,
                getTitlesWidget: (v, meta) {
                  final i = v.round().clamp(0, shown.length - 1);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(DateFormat('HH:mm').format(shown[i].timestamp), style: const TextStyle(fontSize: 9, color: EdgeColors.muted)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => EdgeColors.bgDeep,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('${s.y.toStringAsFixed(type == SensorType.temperature ? 1 : 0)}${type.unit}', const TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w700)))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: .25,
              barWidth: 2.4,
              color: type.accent,
              dotData: FlDotData(show: showDots),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [type.accent.withValues(alpha: .24), type.accent.withValues(alpha: 0)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomComparisonBarChart extends StatelessWidget {
  const RoomComparisonBarChart({super.key, required this.values, required this.type, this.height = 260});
  final List<MapEntry<String, double>> values;
  final SensorType type;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height, child: const Center(child: Text('No comparison data')));
    final maxValue = values.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.25;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxValue == 0 ? 1 : maxValue,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: EdgeColors.stroke.withValues(alpha: .55), strokeWidth: .7)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 9, color: EdgeColors.muted)))),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (i < 0 || i >= values.length) return const SizedBox.shrink();
                  final label = values[i].key.length > 8 ? '${values[i].key.substring(0, 7)}…' : values[i].key;
                  return Padding(padding: const EdgeInsets.only(top: 8), child: Text(label, style: const TextStyle(fontSize: 9, color: EdgeColors.muted)));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => EdgeColors.bgDeep,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${values[group.x].key}\n${rod.toY.toStringAsFixed(type == SensorType.temperature ? 1 : 0)}${type.unit}',
                const TextStyle(color: EdgeColors.text, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          barGroups: List.generate(values.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i].value, width: 20, borderRadius: BorderRadius.circular(6), color: type.accent)])),
        ),
      ),
    );
  }
}
