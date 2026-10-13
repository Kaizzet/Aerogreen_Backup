class SensorReading {
  final String id;
  final String deviceId;
  final double? temperature;
  final double? solutionTemperature;
  final double? humidity;
  final double? ph;
  final double? tds;
  final double? waterLevel;
  final double? lux;
  final String recordedAt;

  SensorReading({
    required this.id,
    required this.deviceId,
    this.temperature,
    this.solutionTemperature,
    this.humidity,
    this.ph,
    this.tds,
    this.waterLevel,
    this.lux,
    required this.recordedAt,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] ?? '',
      deviceId: json['deviceId'] ?? '',
      temperature: json['temperature']?.toDouble(),
      solutionTemperature: json['solutionTemperature']?.toDouble(),
      humidity: json['humidity']?.toDouble(),
      ph: json['ph']?.toDouble(),
      tds: json['tds']?.toDouble(),
      waterLevel: json['waterLevel']?.toDouble(),
      lux: json['lux']?.toDouble(),
      recordedAt: json['recordedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'temperature': temperature,
      'solutionTemperature': solutionTemperature,
      'humidity': humidity,
      'ph': ph,
      'tds': tds,
      'waterLevel': waterLevel,
      'lux': lux,
      'recordedAt': recordedAt,
    };
  }
}
