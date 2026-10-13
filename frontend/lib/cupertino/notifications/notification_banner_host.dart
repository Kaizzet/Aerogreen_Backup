import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../models/device_alert.dart';
import '../../services/notification_service.dart';

class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({
    super.key,
    required this.child,
    required this.service,
    required this.onOpen,
  });

  final Widget child;
  final NotificationService service;
  final ValueChanged<NotificationMessage> onOpen;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  StreamSubscription<NotificationMessage>? _subscription;
  StreamSubscription<NotificationMessage>? _tapSubscription;
  Timer? _timer;
  NotificationMessage? _message;

  @override
  void initState() {
    super.initState();
    _listen(widget.service);
  }

  @override
  void didUpdateWidget(covariant NotificationBannerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _subscription?.cancel();
      _tapSubscription?.cancel();
      _listen(widget.service);
    }
  }

  void _listen(NotificationService service) {
    _subscription = service.foregroundMessages.listen((message) {
      _timer?.cancel();
      if (mounted) setState(() => _message = message);
      _timer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _message = null);
      });
    });
    _tapSubscription = service.taps.listen(widget.onOpen);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _tapSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_message case final message?)
        Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {
                widget.service.open(message);
                setState(() => _message = null);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        _icon(message.level),
                        color: _color(message.level),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CupertinoColors.secondaryLabel,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 15,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

Color _color(AlertLevel level) => switch (level) {
  AlertLevel.critical => CupertinoColors.systemRed,
  AlertLevel.warning => CupertinoColors.systemOrange,
  AlertLevel.info => CupertinoColors.systemBlue,
};

IconData _icon(AlertLevel level) => switch (level) {
  AlertLevel.critical => CupertinoIcons.exclamationmark_octagon_fill,
  AlertLevel.warning => CupertinoIcons.exclamationmark_triangle_fill,
  AlertLevel.info => CupertinoIcons.info_circle_fill,
};
