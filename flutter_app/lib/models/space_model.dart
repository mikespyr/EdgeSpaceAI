class SpaceModel {
  final String id;

  String name;
  String building;
  String description;

  double? temperature;
  double? humidity;
  double? co2;

  double? currentPower;
  double? energyToday;

  int environmentalScore;

  DateTime createdAt;
  DateTime? lastUpdate;

  SpaceModel({
    required this.id,
    required this.name,
    required this.building,
    this.description = '',
    this.temperature,
    this.humidity,
    this.co2,
    this.currentPower,
    this.energyToday,
    this.environmentalScore = 0,
    required this.createdAt,
    this.lastUpdate,
  });

  bool get hasSensorData {
    return temperature != null || humidity != null || co2 != null;
  }

  String get status {
    if (!hasSensorData) {
      return 'Waiting for data';
    }

    if (environmentalScore >= 80) {
      return 'Good';
    }

    if (environmentalScore >= 50) {
      return 'Needs Attention';
    }

    return 'Critical';
  }

  SpaceModel copyWith({
    String? name,
    String? building,
    String? description,
    double? temperature,
    double? humidity,
    double? co2,
    double? currentPower,
    double? energyToday,
    int? environmentalScore,
    DateTime? lastUpdate,
  }) {
    return SpaceModel(
      id: id,
      name: name ?? this.name,
      building: building ?? this.building,
      description: description ?? this.description,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      co2: co2 ?? this.co2,
      currentPower: currentPower ?? this.currentPower,
      energyToday: energyToday ?? this.energyToday,
      environmentalScore: environmentalScore ?? this.environmentalScore,
      createdAt: createdAt,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'building': building,
      'description': description,
      'temperature': temperature,
      'humidity': humidity,
      'co2': co2,
      'currentPower': currentPower,
      'energyToday': energyToday,
      'environmentalScore': environmentalScore,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdate': lastUpdate?.toIso8601String(),
    };
  }

  factory SpaceModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return SpaceModel(
      id: json['id'],
      name: json['name'],
      building: json['building'],
      description: json['description'] ?? '',
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      co2: (json['co2'] as num?)?.toDouble(),
      currentPower: (json['currentPower'] as num?)?.toDouble(),
      energyToday: (json['energyToday'] as num?)?.toDouble(),
      environmentalScore: json['environmentalScore'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdate: json['lastUpdate'] != null
          ? DateTime.parse(json['lastUpdate'])
          : null,
    );
  }
}
