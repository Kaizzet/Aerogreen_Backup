import '../models/device.dart';
import '../models/device_overview.dart';
import '../models/provisioning_code.dart';

abstract class DeviceRepository {
  Future<List<DeviceOverview>> getDashboardOverview();
  Future<List<Device>> getDevices();
  Future<Device> getDevice(String id);
  Future<Device> createDevice(String name);
  Future<Device> updateDevice(String id, String name);
  Future<void> deleteDevice(String id);
  Future<ProvisioningCode> createProvisioningCode(String deviceId);
  Future<ProvisioningCode> getActiveProvisioningCode(String deviceId);
  Future<Device> claimDevice(String code, {String? name});
}
