import '../models/support_ticket.dart';

abstract class SupportTicketRepository {
  Future<List<SupportTicket>> getMyTickets({String? status});
  Future<SupportTicket> getMyTicket(String id);
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String message,
    String? category,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
  });
  Future<SupportTicketMessage> replyToTicket(String id, String message);
}
