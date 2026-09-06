class DeviceModel {
  final String id;

  String name;

  String? spaceId;

  String? bleDeviceId;

  String type;

  bool isOnline;

  DateTime createdAt;

  DateTime? lastSeen;

  DeviceModel({
    required this.id,
    required this.name,
    this.spaceId,
    this.bleDeviceId,
    this.type = 'ESP32-C3',
    this.isOnline = false,
    required this.createdAt,
    this.lastSeen,
  });

  DeviceModel copyWith({
    String? name,
    String? spaceId,
    String? bleDeviceId,
    String? type,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id,
      name: name ?? this.name,
      spaceId: spaceId ?? this.spaceId,
      bleDeviceId: bleDeviceId ?? this.bleDeviceId,
      type: type ?? this.type,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'spaceId': spaceId,
      'bleDeviceId': bleDeviceId,
      'type': type,
      'isOnline': isOnline,
      'createdAt': createdAt.toIso8601String(),
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory DeviceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return DeviceModel(
      id: json['id'],
      name: json['name'],
      spaceId: json['spaceId'],
      bleDeviceId: json['bleDeviceId'],
      type: json['type'] ?? 'ESP32-C3',
      isOnline: json['isOnline'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      lastSeen:
          json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    );
  }
}
