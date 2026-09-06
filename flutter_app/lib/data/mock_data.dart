import 'dart:math';

import '../models/models.dart';

class MockData {
  static final buildings = <Building>[
    Building(id: 'b1', name: 'Main Building', location: 'Arta Campus', description: '8 monitored rooms'),
    Building(id: 'b2', name: 'Research Center', location: 'Arta Campus', description: '3 monitored rooms'),
    Building(id: 'b3', name: 'Administration', location: 'Arta Campus', description: '1 monitored room'),
  ];

  static final rooms = <Room>[
    Room(id: 'r101', buildingId: 'b1', name: 'Room 101', floor: '1', deviceId: 'node-101'),
    Room(id: 'r102', buildingId: 'b1', name: 'Room 102', floor: '1', deviceId: 'node-102'),
    Room(id: 'r103', buildingId: 'b1', name: 'Room 103', floor: '1', deviceId: 'node-103'),
    Room(id: 'r104', buildingId: 'b1', name: 'Room 104', floor: '1', deviceId: 'node-104'),
    Room(id: 'r201', buildingId: 'b1', name: 'Room 201', floor: '2', deviceId: 'node-201'),
    Room(id: 'r202', buildingId: 'b1', name: 'Room 202', floor: '2', deviceId: 'node-202'),
    Room(id: 'r203', buildingId: 'b1', name: 'Room 203', floor: '2', deviceId: 'node-203'),
    Room(id: 'r204', buildingId: 'b1', name: 'Room 204', floor: '2', deviceId: 'node-204'),
    Room(id: 'lab1', buildingId: 'b2', name: 'Lab 1', floor: 'Ground', deviceId: 'node-lab1'),
    Room(id: 'lab2', buildingId: 'b2', name: 'Lab 2', floor: 'Ground', deviceId: 'node-lab2'),
    Room(id: 'vr', buildingId: 'b2', name: 'VR Laboratory', floor: '1', deviceId: 'node-vr'),
    Room(id: 'office', buildingId: 'b3', name: 'Office 3', floor: '1', deviceId: 'node-office'),
  ];

  static List<DeviceKit> devices() {
    return List.generate(rooms.length, (i) {
      final room = rooms[i];
      return DeviceKit(
        id: room.deviceId,
        name: 'Edge Kit ${room.name.replaceAll(' ', '-')}',
        roomId: room.id,
        status: i == 10 ? DeviceStatus.offline : (i == 2 || i == 8 ? DeviceStatus.warning : DeviceStatus.online),
        rssi: i == 10 ? -92 : -44 - (i % 6) * 5,
        lastSeen: i == 10 ? DateTime.now().subtract(const Duration(minutes: 28)) : DateTime.now().subtract(Duration(seconds: 8 + i)),
        firmware: i % 4 == 0 ? '1.0.1' : '1.0.0',
        uptimeHours: 12 + i * 7.5,
      );
    });
  }

  static List<SensorPoint> history() {
    final rng = Random(18);
    final now = DateTime.now();
    final out = <SensorPoint>[];

    for (var ri = 0; ri < rooms.length; ri++) {
      final room = rooms[ri];
      for (var i = 0; i < 192; i++) {
        final ts = now.subtract(Duration(minutes: (191 - i) * 15));
        final hour = ts.hour;
        final occupied = hour >= 9 && hour <= 18 && (i + ri) % 11 != 0;
        final tempBias = switch (room.id) {
          'r102' => 4.4,
          'lab1' => 2.6,
          'vr' => 1.8,
          _ => (ri % 4) * .35,
        };
        final humBias = room.id == 'r102' ? 15.0 : room.id == 'lab1' ? 9.0 : (ri % 3) * 2.0;
        final wave = sin(i / 10) * 1.15;
        final temperature = 22.2 + tempBias + wave + rng.nextDouble() * .6 + (occupied ? .5 : 0);
        final humidity = 45.0 + humBias + sin(i / 13) * 5 + rng.nextDouble() * 2.8;
        final noise = 260.0 + (occupied ? 170 : 0) + ri * 14 + rng.nextDouble() * 90 + (room.id == 'r102' ? 180 : 0);
        out.add(SensorPoint(roomId: room.id, type: SensorType.temperature, value: temperature, timestamp: ts));
        out.add(SensorPoint(roomId: room.id, type: SensorType.humidity, value: humidity, timestamp: ts));
        out.add(SensorPoint(roomId: room.id, type: SensorType.noise, value: noise, timestamp: ts));
        out.add(SensorPoint(roomId: room.id, type: SensorType.motion, value: occupied ? 1 : 0, timestamp: ts));
      }
    }
    return out;
  }

  static List<EdgeAlert> alerts() => [
        EdgeAlert(
          id: 'a1',
          roomId: 'r102',
          title: 'High temperature',
          message: 'Room 102 reached 28.4°C and is above its recent profile.',
          severity: Severity.critical,
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
        EdgeAlert(
          id: 'a2',
          roomId: 'lab2',
          title: 'High noise level',
          message: 'Sustained elevated noise detected in Lab 2.',
          severity: Severity.warning,
          createdAt: DateTime.now().subtract(const Duration(minutes: 44)),
        ),
        EdgeAlert(
          id: 'a3',
          roomId: 'vr',
          title: 'Device offline',
          message: 'The Edge Kit in VR Laboratory stopped reporting data.',
          severity: Severity.warning,
          createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 8)),
        ),
      ];
}
