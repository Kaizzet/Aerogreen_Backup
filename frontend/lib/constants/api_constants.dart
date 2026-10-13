class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Auth endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String profile = '/api/auth/profile';

  // Device endpoints
  static const String devices = '/api/devices';
  static String device(String id) => '/api/devices/$id';
  static String deviceProvisioningCode(String id) =>
      '/api/devices/$id/provisioning-code';
  static String provisioningCodes(String id) => deviceProvisioningCode(id);
  static String activeProvisioningCode(String id) => deviceProvisioningCode(id);
  static const String claimDevice = '/api/device-provisioning/claims';

  // Dashboard endpoints
  static const String dashboardOverview = '/api/dashboard/overview';

  // Sensor endpoints
  static String deviceReadings(String id) => '/api/devices/$id/readings';
  static String aggregatedReadings(String id) =>
      '/api/devices/$id/readings/aggregated';
  static String deviceAggregatedReadings(String id) => aggregatedReadings(id);

  // Pump control endpoints
  static String pumpCommands(String id) => '/api/devices/$id/pump/commands';
  static String pumpCommandHistory(String id) =>
      '/api/devices/$id/pump-commands';
  static String pumpSchedules(String id) => '/api/devices/$id/pump-schedules';
  static String pumpSchedule(String id, String scheduleId) =>
      '/api/devices/$id/pump-schedules/$scheduleId';

  // Alert endpoints
  static String alertSettings(String id) => '/api/devices/$id/alert-settings';
  static String alerts(String id) => '/api/devices/$id/alerts';
  static String resolveAlert(String deviceId, String alertId) =>
      '/api/devices/$deviceId/alerts/$alertId/resolve';

  // Admin endpoints
  static const String adminUsers = '/api/admin/users';
  static String adminUser(String id) => '/api/admin/users/$id';
  static String adminUserRole(String id) => '/api/admin/users/$id/role';
  static String adminUserLock(String id) => '/api/admin/users/$id/lock';
  static const String adminDevices = '/api/admin/devices';
  static String adminDevice(String id) => '/api/admin/devices/$id';
  static String adminDeviceReadings(String id) =>
      '/api/admin/devices/$id/readings';
  static String adminDevicePumpCommands(String id) =>
      '/api/admin/devices/$id/pump-commands';
  static String adminDeviceOwner(String id) => '/api/admin/devices/$id/owner';
  static const String adminAuditLogs = '/api/admin/audit-logs';
  static const String adminOverview = '/api/admin/overview';
  static const String adminReportSummary = '/api/admin/reports/summary';
  static const String adminReportCsv = '/api/admin/reports.csv';
  static const String adminStatus = '/api/admin/status';
  static const String adminAlertDefaults = '/api/admin/settings/alert-defaults';

  static const String tickets = '/api/tickets';
  static const String adminTickets = '/api/admin/tickets';
  static String adminTicket(String id) => '/api/admin/tickets/$id';
  static String adminTicketStatus(String id) => '${adminTicket(id)}/status';
  static String adminTicketPriority(String id) => '${adminTicket(id)}/priority';
  static String adminTicketMessages(String id) => '${adminTicket(id)}/messages';
}
