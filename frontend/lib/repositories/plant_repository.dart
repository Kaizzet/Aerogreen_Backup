import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../data/models.dart';

final plantRepositoryProvider = Provider<PlantRepository>((ref) {
  return PlantRepository();
});

class PlantRepository {
  final ApiClient _client = ApiClient();

  Future<SensorReading> getLatestSensor() async {
    final resp = await _client.get('/api/sensor/latest');
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch sensor: ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return SensorReading.fromJson(json);
  }

  // Additional methods (login, etc.) can be added later.
}
