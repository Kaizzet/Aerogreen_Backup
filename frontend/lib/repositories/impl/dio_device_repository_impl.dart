import 'package:dio/dio.dart';

import '../../constants/api_constants.dart';
import '../../models/device.dart';
import '../../models/device_overview.dart';
import '../../models/provisioning_code.dart';
import '../device_repository.dart';
import '../dio_client.dart';

class DioDeviceRepositoryImpl implements DeviceRepository {
  final DioClient client;

  DioDeviceRepositoryImpl({DioClient? dioClient})
      : client = dioClient ?? DioClient();

  Dio get _dio => client.dio;

  @override
  Future<List<DeviceOverview>> getDashboardOverview() async {
    final response = await _dio.get(ApiConstants.dashboardOverview);
    final list = response.data as List<dynamic>;
    return list.map((item) => DeviceOverview.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Device>> getDevices() async {
    final response = await _dio.get(ApiConstants.devices);
    final list = response.data as List<dynamic>;
    return list.map((item) => Device.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Device> getDevice(String id) async {
    final response = await _dio.get(ApiConstants.device(id));
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Device> createDevice(String name) async {
    final response = await _dio.post(
      ApiConstants.devices,
      data: {'name': name},
    );
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Device> updateDevice(String id, String name) async {
    final response = await _dio.put(
      ApiConstants.device(id),
      data: {'name': name},
    );
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteDevice(String id) async {
    await _dio.delete(ApiConstants.device(id));
  }

  @override
  Future<ProvisioningCode> createProvisioningCode(String deviceId) async {
    final response = await _dio.post(ApiConstants.provisioningCodes(deviceId));
    return ProvisioningCode.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ProvisioningCode> getActiveProvisioningCode(String deviceId) async {
    final response = await _dio.get(ApiConstants.activeProvisioningCode(deviceId));
    return ProvisioningCode.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<Device> claimDevice(String code, {String? name}) async {
    final response = await _dio.post(
      ApiConstants.claimDevice,
      data: {
        'code': code,
        'name': ?name,
      },
    );
    return Device.fromJson(response.data as Map<String, dynamic>);
  }
}
