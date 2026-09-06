class EnergyReading {
  final DateTime timestamp;

  final double voltage;
  final double current;
  final double power;
  final double energy;

  EnergyReading({
    required this.timestamp,
    required this.voltage,
    required this.current,
    required this.power,
    required this.energy,
  });

  double get estimatedCost {
    const pricePerKwh = 0.20;

    return energy * pricePerKwh;
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'voltage': voltage,
      'current': current,
      'power': power,
      'energy': energy,
    };
  }

  factory EnergyReading.fromJson(
    Map<String, dynamic> json,
  ) {
    return EnergyReading(
      timestamp: DateTime.parse(json['timestamp']),
      voltage: (json['voltage'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      power: (json['power'] as num).toDouble(),
      energy: (json['energy'] as num).toDouble(),
    );
  }
}
