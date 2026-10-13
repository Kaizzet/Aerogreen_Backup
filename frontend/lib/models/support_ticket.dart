class SupportTicket {
  final String id;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final String? deviceId;
  final String? deviceName;
  final String? firmwareVersion;
  final String createdAt;
  final String? updatedAt;
  final String? lastMessage;
  final int messagesCount;
  final List<SupportTicketMessage> messages;

  const SupportTicket({
    required this.id,
    required this.subject,
    this.category = 'Kỹ thuật',
    this.status = 'open',
    this.priority = 'medium',
    this.deviceId,
    this.deviceName,
    this.firmwareVersion,
    required this.createdAt,
    this.updatedAt,
    this.lastMessage,
    this.messagesCount = 1,
    this.messages = const [],
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isInProgress => status.toLowerCase() == 'in_progress';
  bool get isResolved =>
      status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed';

  String get statusDisplay {
    if (isOpen) return 'Đang mở';
    if (isInProgress) return 'Đang xử lý';
    return 'Đã giải quyết';
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? const [];
    final messages = rawMessages
        .map((m) => SupportTicketMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return SupportTicket(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Kỹ thuật',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      deviceId: json['deviceId']?.toString(),
      deviceName: json['deviceName']?.toString(),
      firmwareVersion: json['firmwareVersion']?.toString(),
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: json['updatedAt']?.toString(),
      lastMessage: json['lastMessage']?.toString() ??
          (messages.isNotEmpty ? messages.last.body : null),
      messagesCount: (json['messagesCount'] as num?)?.toInt() ?? messages.length,
      messages: messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'category': category,
    'status': status,
    'priority': priority,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'firmwareVersion': firmwareVersion,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'lastMessage': lastMessage,
    'messagesCount': messagesCount,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  SupportTicket copyWith({
    String? id,
    String? subject,
    String? category,
    String? status,
    String? priority,
    String? deviceId,
    String? deviceName,
    String? firmwareVersion,
    String? createdAt,
    String? updatedAt,
    String? lastMessage,
    int? messagesCount,
    List<SupportTicketMessage>? messages,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      messagesCount: messagesCount ?? this.messagesCount,
      messages: messages ?? this.messages,
    );
  }
}

class SupportTicketMessage {
  final String id;
  final String authorUserId;
  final String authorName;
  final bool isStaff;
  final String body;
  final String createdAt;

  const SupportTicketMessage({
    required this.id,
    required this.authorUserId,
    required this.authorName,
    this.isStaff = false,
    required this.body,
    required this.createdAt,
  });

  factory SupportTicketMessage.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessage(
      id: json['id']?.toString() ?? '',
      authorUserId: json['authorUserId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? (json['isStaff'] == true ? 'Hỗ trợ Aerogreen' : 'Bạn'),
      isStaff: json['isStaff'] == true,
      body: json['body']?.toString() ?? json['message']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorUserId': authorUserId,
    'authorName': authorName,
    'isStaff': isStaff,
    'body': body,
    'createdAt': createdAt,
  };
}
