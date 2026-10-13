import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../dio_client.dart';
import '../support_ticket_repository.dart';

class DioSupportTicketRepositoryImpl implements SupportTicketRepository {
  final ApiService _apiService;

  DioSupportTicketRepositoryImpl({
    DioClient? dioClient,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  @override
  Future<List<SupportTicket>> getMyTickets({String? status}) async {
    final list = await _apiService.getMyTickets(status: status);
    return list.map((item) => SupportTicket.fromJson(item)).toList();
  }

  @override
  Future<SupportTicket> getMyTicket(String id) async {
    final data = await _apiService.getMyTicket(id);
    return SupportTicket.fromJson(data);
  }

  @override
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String message,
    String? category,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
  }) async {
    final data = await _apiService.createSupportTicket(
      subject,
      message,
      category: category,
      deviceId: deviceId,
      deviceName: deviceName,
      firmwareVersion: firmwareVersion,
    );
    return SupportTicket.fromJson(data);
  }

  @override
  Future<SupportTicketMessage> replyToTicket(String id, String message) async {
    final data = await _apiService.replyToMyTicket(id, message);
    return SupportTicketMessage.fromJson(data);
  }
}
