import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/models.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EdgeColors.cyan, EdgeColors.blueStrong, EdgeColors.green],
        ),
        boxShadow: [BoxShadow(color: EdgeColors.blue.withValues(alpha: .24), blurRadius: 22, spreadRadius: 2)],
      ),
      padding: EdgeInsets.all(size * .08),
      child: Container(
        decoration: BoxDecoration(
          color: EdgeColors.bgDeep,
          borderRadius: BorderRadius.circular(size * .21),
        ),
        child: Icon(Icons.energy_savings_leaf_rounded, color: EdgeColors.green, size: size * .55),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ]),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EdgeColors.panel2, EdgeColors.panel],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EdgeColors.stroke, width: .8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: content),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.title, required this.value, required this.icon, required this.accent, this.caption});
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accent, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: EdgeColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (caption != null) Text(caption!, style: const TextStyle(color: EdgeColors.muted, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .38)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: color, size: 13), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 92, this.label});
  final int score;
  final double size;
  final String? label;

  Color get _color => score >= 85 ? EdgeColors.green : score >= 65 ? EdgeColors.amber : EdgeColors.red;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: size * .09,
              strokeCap: StrokeCap.round,
              backgroundColor: EdgeColors.stroke.withValues(alpha: .6),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$score', style: TextStyle(fontSize: size * .27, fontWeight: FontWeight.w800)),
            Text(label ?? '/100', style: TextStyle(fontSize: size * .11, color: EdgeColors.muted)),
          ]),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.type,
    required this.value,
    this.subtitle,
    this.compact = false,
  });

  final SensorType type;
  final double? value;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final numeric = value ?? 0;

    final text = !hasValue
        ? '--'
        : switch (type) {
            SensorType.motion => numeric > .5 ? 'Detected' : 'Idle',
            SensorType.temperature => '${numeric.toStringAsFixed(1)}°C',
            SensorType.humidity => '${numeric.toStringAsFixed(0)}%',
            SensorType.noise => numeric.toStringAsFixed(0),
          };

    final detail = subtitle ??
        (!hasValue
            ? 'Waiting for data'
            : switch (type) {
                SensorType.temperature => numeric > 28 ? 'High' : 'Comfortable',
                SensorType.humidity => numeric > 65 ? 'High' : 'Normal',
                SensorType.motion =>
                  numeric > .5 ? 'Activity detected' : 'No activity',
                SensorType.noise => numeric > 650 ? 'Elevated' : 'Moderate',
              });

    final accent = hasValue ? type.accent : EdgeColors.muted;

    return GlassCard(
      padding: EdgeInsets.all(compact ? 12 : 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 32 : 38,
                height: compact ? 32 : 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  type.icon,
                  color: accent,
                  size: compact ? 18 : 21,
                ),
              ),
              const Spacer(),
              if (type != SensorType.motion && hasValue)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            type.label,
            style: const TextStyle(
              color: EdgeColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: hasValue &&
                      type == SensorType.motion &&
                      numeric > .5
                  ? EdgeColors.green
                  : hasValue
                      ? EdgeColors.text
                      : EdgeColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              color: detail.toLowerCase().contains('high') ||
                      detail.toLowerCase().contains('elevated')
                  ? EdgeColors.amber
                  : EdgeColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42),
      child: Column(children: [
        Icon(icon, size: 44, color: EdgeColors.muted),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
