import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

enum SensorType { temperature, humidity, motion, noise }
enum DeviceStatus { online, offline, warning }
enum Severity { info, warning, critical }
enum RangePreset { hour24, day7, day30, custom }
enum Aggregation { average, minimum, maximum, latest }

extension SensorTypeX on SensorType {
  String get label => switch (this) {
        SensorType.temperature => 'Temperature',
        SensorType.humidity => 'Humidity',
        SensorType.motion => 'Motion',
        SensorType.noise => 'Noise Level',
      };

  String get unit => switch (this) {
        SensorType.temperature => '°C',
        SensorType.humidity => '%',
        SensorType.motion => '',
        SensorType.noise => '',
      };

  IconData get icon => switch (this) {
        SensorType.temperature => Icons.thermostat_rounded,
        SensorType.humidity => Icons.water_drop_rounded,
        SensorType.motion => Icons.motion_photos_on_rounded,
        SensorType.noise => Icons.graphic_eq_rounded,
      };

  Color get accent => switch (this) {
        SensorType.temperature => EdgeColors.blue,
        SensorType.humidity => EdgeColors.cyan,
        SensorType.motion => EdgeColors.green,
        SensorType.noise => EdgeColors.red,
      };
}

extension RangePresetX on RangePreset {
  String get label => switch (this) {
        RangePreset.hour24 => '24H',
        RangePreset.day7 => '7D',
        RangePreset.day30 => '30D',
        RangePreset.custom => 'Custom',
      };

  Duration get duration => switch (this) {
        RangePreset.hour24 => const Duration(hours: 24),
        RangePreset.day7 => const Duration(days: 7),
        RangePreset.day30 => const Duration(days: 30),
        RangePreset.custom => const Duration(days: 7),
      };
}

extension AggregationX on Aggregation {
  String get label => switch (this) {
        Aggregation.average => 'Average',
        Aggregation.minimum => 'Minimum',
        Aggregation.maximum => 'Maximum',
        Aggregation.latest => 'Latest',
      };
}

class Building {
  Building({required this.id, required this.name, this.location = '', this.description = ''});
  final String id;
  final String name;
  final String location;
  final String description;
}

class Room {
  Room({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.floor,
    required this.deviceId,
  });
  final String id;
  final String buildingId;
  final String name;
  final String floor;
  String deviceId;
}

class DeviceKit {
  DeviceKit({
    required this.id,
    required this.name,
    required this.roomId,
    required this.status,
    required this.rssi,
    required this.lastSeen,
    this.firmware = '1.0.0',
    this.uptimeHours = 0,
  });
  final String id;
  String name;
  String roomId;
  DeviceStatus status;
  int rssi;
  DateTime lastSeen;
  String firmware;
  double uptimeHours;
}

class SensorPoint {
  SensorPoint({
    required this.roomId,
    required this.type,
    required this.value,
    required this.timestamp,
  });
  final String roomId;
  final SensorType type;
  final double value;
  final DateTime timestamp;
}

class EdgeAlert {
  EdgeAlert({
    required this.id,
    required this.roomId,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.acknowledged = false,
  });
  final String id;
  final String roomId;
  final String title;
  final String message;
  final Severity severity;
  final DateTime createdAt;
  bool acknowledged;
}

class Insight {
  Insight({
    required this.roomId,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    this.recommendations = const [],
  });
  final String roomId;
  final String title;
  final String body;
  final Severity severity;
  final DateTime createdAt;
  final List<String> recommendations;
}

class RoomSnapshot {
  RoomSnapshot({
    required this.room,
    required this.temperature,
    required this.humidity,
    required this.motion,
    required this.noise,
    required this.score,
    required this.statusText,
  });
  final Room room;
  final double temperature;
  final double humidity;
  final bool motion;
  final double noise;
  final int score;
  final String statusText;
}

class ChatMessage {
  ChatMessage({required this.text, required this.fromUser, required this.createdAt});
  final String text;
  final bool fromUser;
  final DateTime createdAt;
}

int calculateRoomScore({
  required double temperature,
  required double humidity,
  required double noise,
}) {
  var score = 100.0;
  if (temperature < 19 || temperature > 28) score -= 18;
  if (temperature < 16 || temperature > 31) score -= 18;
  if (humidity < 30 || humidity > 65) score -= 15;
  if (humidity < 20 || humidity > 75) score -= 12;
  if (noise > 650) score -= 16;
  if (noise > 850) score -= 14;
  return max(0, min(100, score.round()));
}
